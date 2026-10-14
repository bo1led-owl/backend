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
    if (self.first != .none) {
        nodes.items(.prev)[@backingInt(self.first)] = node_index;
    }
    self.first = node_index;
}

pub fn append(self: *Self, nodes: std.MultiArrayList(Value).Slice, node_index: Index) void {
    nodes.items(.prev)[@backingInt(node_index)] = self.last;
    if (self.last != .none) {
        nodes.items(.next)[@backingInt(self.last)] = node_index;
    }
    self.last = node_index;
}

pub fn insertBefore(self: *Self, nodes: std.MultiArrayList(Value).Slice, existing_node: Index, new_node: Index) void {
    if (existing_node == self.first) {
        self.prepend(nodes, new_node);
    } else {
        const existing_prev: *IndexOpt = &nodes.items(.prev)[@backingInt(existing_node)];
        nodes.items(.next)[@backingInt(existing_prev.*)] = new_node;

        nodes.items(.prev)[@backingInt(new_node)] = existing_prev.*;
        nodes.items(.next)[@backingInt(new_node)] = existing_node;

        existing_prev.* = new_node;
    }
}

pub fn insertAfter(self: *Self, nodes: std.MultiArrayList(Value).Slice, existing_node: Index, new_node: Index) void {
    if (existing_node == self.last) {
        self.append(nodes, new_node);
    } else {
        const existing_next: *IndexOpt = &nodes.items(.next)[@backingInt(existing_node)];
        nodes.items(.prev)[@backingInt(existing_next.*)] = new_node;

        nodes.items(.next)[@backingInt(new_node)] = existing_next.*;
        nodes.items(.prev)[@backingInt(new_node)] = existing_node;

        existing_next.* = new_node;
    }
}

pub fn popFirst(self: *Self, nodes: std.MultiArrayList(Value).Slice) Index {
    const next = nodes.items(.next)[@backingInt(self.first)];
    nodes.items(.prev)[next] = .none;
    nodes.items(.next)[self.first] = .none;
    defer self.first = next;
    return self.first;
}

pub fn popLast(self: *Self, nodes: std.MultiArrayList(Value).Slice) Index {
    const prev = nodes.items(.prev)[@backingInt(self.last)];
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
        const prev = nodes.items(.prev)[@backingInt(node)];
        const next = nodes.items(.next)[@backingInt(node)];
        nodes.items(.next)[prev] = next;
        nodes.items(.prev)[next] = prev;

        nodes.items(.prev)[node] = .none;
        nodes.items(.next)[node] = .none;
    }
}
