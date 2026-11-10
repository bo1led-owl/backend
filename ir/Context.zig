const Context = @This();

const std = @import("std");
const support = @import("support");
const Type = @import("Type.zig");
const Value = @import("Value.zig");
const BasicBlock = @import("BasicBlock.zig");
const Function = @import("Function.zig");

gpa: std.mem.Allocator,
name_arena: std.heap.ArenaAllocator,

/// safe to read directly
values: std.MultiArrayList(Value),

/// safe to read directly
blocks: std.MultiArrayList(BasicBlock),

/// safe to read and append
extras: std.ArrayList(u32),

/// safe to read directly, modifications should be made using methods of context
functions: std.StringArrayHashMapUnmanaged(Function),

/// not intended to be used directly,
/// context provides forwarders with its allocator supplied where needed
type_storage: Type.Storage,

pub const ExtraIndex = support.index(u32, u32);
pub const ExtraRange = struct { begin: ExtraIndex, len: u32 };

pub fn init(gpa: std.mem.Allocator) Context {
    return .{
        .gpa = gpa,
        .name_arena = .init(gpa),
        .values = .empty,
        .blocks = .empty,
        .extras = .empty,
        .functions = .empty,
        .type_storage = .empty,
    };
}

pub fn deinit(self: *Context) void {
    defer self.* = undefined;

    self.name_arena.deinit();
    self.values.deinit(self.gpa);
    self.blocks.deinit(self.gpa);
    self.extras.deinit(self.gpa);
    self.functions.deinit(self.gpa);
    self.type_storage.deinit(self.gpa);
}

pub fn getExtras(self: Context, range: ExtraRange) []u32 {
    return self.extras.items[range.begin.toInt()..][0..range.len];
}

pub fn getTypeExtras(self: Context, range: Type.Storage.ExtraRange) []Type.Handle {
    return self.type_storage.getExtras(range);
}

pub fn storeName(self: *Context, name: []const u8) ![]const u8 {
    return self.name_arena.allocator().dupe(u8, name);
}

pub fn createValue(self: *Context, value: Value) !Value.Index {
    const res = self.values.len;
    try self.values.append(self.gpa, value);
    return @fromBackingInt(@intCast(res));
}

pub fn reserveExtras(self: *Context, new_items: usize) !void {
    try self.extras.ensureTotalCapacity(self.gpa, self.extras.items.len + new_items);
}

pub fn createBasicBlock(self: *Context, block: BasicBlock) !BasicBlock.Index {
    const res = self.blocks.len;
    try self.blocks.append(self.gpa, block);
    return @fromBackingInt(@intCast(res));
}

/// Create an empty function with given name and type.
/// If a function with that name already exists, return value is invalid.
pub fn createFunction(self: *Context, name: []const u8, ty: Type.Handle) !struct {
    func_index: Function.Index,
    ref_index: Value.Index,
} {
    std.debug.assert(!self.functions.contains(name));

    const res: Function.Index = @fromBackingInt(@intCast(self.functions.entries.len));

    const stored_name = try self.storeName(name);
    try self.functions.put(self.gpa, stored_name, .{ .ty = ty, .blocks = .empty });

    return .{
        .func_index = res,
        .ref_index = try self.createValue(.{ .kind = .function_ref, .ty = ty, .data = .{ .function = res } }),
    };
}

pub fn getFullType(self: Context, ty: Type.Handle) Type {
    return self.type_storage.getFullType(ty);
}

pub fn getFullFunctionType(self: Context, index: u32) Type.Function {
    return self.type_storage.getFullFunctionType(index);
}

pub fn getFullStructType(self: Context, index: u32) Type.Struct {
    return self.type_storage.getFullStructType(index);
}

pub fn getFullArrayType(self: Context, index: u32) Type.Array {
    return self.type_storage.getFullArrayType(index);
}

pub fn createFunctionType(
    self: *Context,
    rettype: Type.Handle,
    params: []const Type.Handle,
) !Type.Handle {
    return self.type_storage.createFunctionType(self.gpa, rettype, params);
}

pub fn createStructType(self: *Context, fields: []const Type.Handle) !Type.Handle {
    return self.type_storage.createStructType(self.gpa, fields);
}

pub fn createArrayType(self: *Context, size: u64, element_type: Type.Handle) !Type.Handle {
    return self.type_storage.createArrayType(self.gpa, size, element_type);
}
