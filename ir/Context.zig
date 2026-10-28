const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");
const BasicBlock = @import("BasicBlock.zig");
const Function = @import("Function.zig");

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
values: std.MultiArrayList(Value),
blocks: std.ArrayList(BasicBlock),
extras: std.ArrayList(u32),
functions: std.StringArrayHashMapUnmanaged(Function),

pub const ExtraIndex = enum(u32) {
    _,

    pub fn toU32(self: ExtraIndex) u32 {
        return @backingInt(self);
    }
};
pub const ExtraRange = struct { begin: ExtraIndex, len: u32 };

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .gpa = gpa,
        .arena = .init(gpa),
        .values = .empty,
        .blocks = .empty,
        .extras = .empty,
        .functions = .empty,
    };
}

pub fn deinit(self: *Self) void {
    defer self.* = undefined;

    self.arena.deinit();
    self.values.deinit(self.gpa);
    self.blocks.deinit(self.gpa);
    self.extras.deinit(self.gpa);
    self.functions.deinit(self.gpa);
}

pub fn getExtras(self: Self, range: ExtraRange) []u32 {
    return self.extras.items[range.begin.toU32()..][0..range.len];
}

pub fn storeName(self: *Self, name: []const u8) ![]const u8 {
    const res = try self.arena.allocator().alloc(u8, name.len);
    @memcpy(res, name);
    return res;
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
    const res = self.values.len;
    try self.blocks.append(self.gpa, block);
    return @fromBackingInt(@intCast(res));
}

pub const CreateFunctionError = std.mem.Allocator.Error || error{AlreadyExists};
pub fn createFunctionWithOneBlock(self: *Self, name: []const u8) CreateFunctionError!Function.Index {
    if (self.functions.contains(name)) {
        return CreateFunctionError.AlreadyExists;
    }

    const res = self.functions.values().len;

    const stored_name = try self.storeName(name);
    const entry = try self.createBasicBlock(.empty);
    try self.functions.put(self.gpa, stored_name, .{ .entry_block = entry });

    return @fromBackingInt(@intCast(res));
}
