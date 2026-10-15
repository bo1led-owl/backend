const Self = @This();

const std = @import("std");
const Value = @import("Value.zig");

const Index = Value.Index;
const IndexOpt = Value.IndexOpt;

first: IndexOpt,
last: IndexOpt,

pub const empty: Self = .{ .first = .none, .last = .none };

pub fn prepend(self: *Self, nodes: std.MultiArrayList(Value).Slice, node_index: Index) void {
    nodes.items(.next)[@backingInt(node_index)] = self.first;
    if (self.first.toIndex()) |first| {
        nodes.items(.prev)[@backingInt(first)] = node_index.toIndexOpt();
    }

    self.first = node_index.toIndexOpt();
    if (self.last == .none) {
        self.last = self.first;
    }
}

pub fn append(self: *Self, nodes: std.MultiArrayList(Value).Slice, node_index: Index) void {
    nodes.items(.prev)[node_index.toU32()] = self.last;
    if (self.last.toU32()) |last| {
        nodes.items(.next)[last] = node_index.toIndexOpt();
    }

    self.last = node_index.toIndexOpt();
    if (self.first == .none) {
        self.first = self.last;
    }
}

pub fn insertBefore(self: *Self, nodes: std.MultiArrayList(Value).Slice, existing_node: Index, new_node: Index) void {
    if (existing_node == self.first.toIndex().?) {
        self.prepend(nodes, new_node);
    } else {
        const existing_prev: *IndexOpt = &nodes.items(.prev)[existing_node.toU32()];
        nodes.items(.next)[existing_prev.toU32().?] = new_node;

        nodes.items(.prev)[new_node.toU32()] = existing_prev.*;
        nodes.items(.next)[new_node.toU32()] = existing_node;

        existing_prev.* = new_node.toIndexOpt();
    }
}

pub fn insertAfter(self: *Self, nodes: std.MultiArrayList(Value).Slice, existing_node: Index, new_node: Index) void {
    if (existing_node == self.last.toIndex().?) {
        self.append(nodes, new_node);
    } else {
        const existing_next: *IndexOpt = &nodes.items(.next)[existing_node.toU32()];
        nodes.items(.prev)[existing_next.toU32().?] = new_node.toIndexOpt();

        nodes.items(.next)[new_node.toU32()] = existing_next.*;
        nodes.items(.prev)[new_node.toU32()] = existing_node.toIndexOpt();

        existing_next.* = new_node.toIndexOpt();
    }
}

pub fn popFirst(self: *Self, nodes: std.MultiArrayList(Value).Slice) Index {
    const next = nodes.items(.next)[self.first.toU32().?];
    nodes.items(.prev)[next] = .none;
    nodes.items(.next)[self.first] = .none;
    defer self.first = next;
    return self.first;
}

pub fn popLast(self: *Self, nodes: std.MultiArrayList(Value).Slice) Index {
    const prev = nodes.items(.prev)[self.last.toU32().?];
    nodes.items(.next)[prev] = .none;
    nodes.items(.prev)[self.last] = .none;
    defer self.last = prev;
    return self.last;
}

pub fn remove(self: *Self, nodes: std.MultiArrayList(Value).Slice, node: Index) void {
    if (node == self.first) {
        _ = self.popFirst(nodes);
    } else if (node == self.last) {
        _ = self.popLast(nodes);
    } else {
        const prev = nodes.items(.prev)[node.toU32()];
        const next = nodes.items(.next)[node.toU32()];
        nodes.items(.next)[prev] = next;
        nodes.items(.prev)[next] = prev;

        nodes.items(.prev)[node] = .none;
        nodes.items(.next)[node] = .none;
    }
}
