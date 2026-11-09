const Self = @This();

const std = @import("std");
const support = @import("support");
const types = @import("types.zig");
const Value = @import("Value.zig");
const BasicBlock = @import("BasicBlock.zig");
const Function = @import("Function.zig");

gpa: std.mem.Allocator,
name_arena: std.heap.ArenaAllocator,
values: std.MultiArrayList(Value),
blocks: std.MultiArrayList(BasicBlock),
extras: std.ArrayList(u32),

functions: std.StringArrayHashMapUnmanaged(Function),

type_storage: types.TypeStorage,

pub const ExtraIndex = support.index(u32, u32);
pub const ExtraRange = struct { begin: ExtraIndex, len: u32 };

pub fn init(gpa: std.mem.Allocator) Self {
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

pub fn deinit(self: *Self) void {
    defer self.* = undefined;

    self.name_arena.deinit();
    self.values.deinit(self.gpa);
    self.blocks.deinit(self.gpa);
    self.extras.deinit(self.gpa);
    self.functions.deinit(self.gpa);
    self.type_storage.deinit(self.gpa);
}

pub fn getExtras(self: Self, range: ExtraRange) []u32 {
    return self.extras.items[range.begin.toInt()..][0..range.len];
}

pub fn storeName(self: *Self, name: []const u8) ![]const u8 {
    return self.name_arena.allocator().dupe(u8, name);
}

pub fn createValue(self: *Self, value: Value) !Value.Index {
    const res = self.values.len;
    try self.values.append(self.gpa, value);
    return @fromBackingInt(@intCast(res));
}

// TODO: return slice?
pub fn reserveExtras(self: *Self, new_items: usize) !void {
    try self.extras.ensureTotalCapacity(self.gpa, self.extras.items.len + new_items);
}

pub fn createBasicBlock(self: *Self, block: BasicBlock) !BasicBlock.Index {
    const res = self.blocks.len;
    try self.blocks.append(self.gpa, block);
    return @fromBackingInt(@intCast(res));
}

/// Create an empty function with given name and type.
/// If a function with that name already exists, return value is invalid.
pub fn createFunction(self: *Self, name: []const u8, ty: types.TypeHandle) !struct {
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

pub fn extractFullType(self: Self, ty: types.TypeHandle) types.Type {
    return self.type_storage.getFullType(ty);
}

pub fn lookupFunctionType(self: Self, rettype: types.TypeHandle, params: []const types.TypeHandle) ?types.TypeHandle {
    return self.type_storage.lookupFunctionType(rettype, params);
}

pub fn createFunctionType(
    self: *Self,
    rettype: types.TypeHandle,
    params: []const types.TypeHandle,
) !types.TypeHandle {
    return self.type_storage.createFunctionType(self.gpa, rettype, params);
}

pub fn lookupStructType(self: Self, fields: []const types.TypeHandle) ?types.TypeHandle {
    return self.type_storage.lookupStructType(fields);
}

pub fn createStructType(self: *Self, fields: []const types.TypeHandle) !types.TypeHandle {
    return self.type_storage.createStructType(self.gpa, fields);
}

pub fn lookupArrayType(self: Self, size: u64, element_type: types.TypeHandle) ?types.TypeHandle {
    return self.type_storage.lookupArrayType(size, element_type);
}

pub fn createArrayType(self: *Self, size: u64, element_type: types.TypeHandle) !types.TypeHandle {
    return self.type_storage.createArrayType(self.gpa, size, element_type);
}
