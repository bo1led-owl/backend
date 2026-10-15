const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");
const Function = @import("Function.zig");

gpa: std.mem.Allocator,
arena: std.heap.ArenaAllocator,
values: std.MultiArrayList(Value),
extras: std.ArrayList(u32),
functions: std.StringHashMapUnmanaged(Function),

pub const ExtraIndex = enum(u32) { _ };
pub const ExtraRange = struct { begin: ExtraIndex, len: u32 };

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .gpa = gpa,
        .arena = .init(gpa),
        .values = .empty,
        .extras = .empty,
        .functions = .empty,
    };
}

pub fn deinit(self: *Self) void {
    self.values.deinit(self.gpa);
    self.arena.deinit();
    self.extras.deinit(self.gpa);
    self.* = undefined;
}

pub fn getExtras(self: Self, range: ExtraRange) []u32 {
    return self.extras.items[@backingInt(range.begin)..][0..range.len];
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

pub fn reserveExtras(self: *Self, new_items: usize) !void {
    try self.extras.ensureTotalCapacity(self.gpa, self.extras.items.len + new_items);
}
