const std = @import("std");

pub fn List(comptime T: type, comptime Index: type, comptime IndexOpt: type) type {
    return struct {
        const Self = @This();

        first: IndexOpt,
        last: IndexOpt,

        pub const empty: Self = .{ .first = .none, .last = .none };

        pub const Iterator = struct {
            nodes: std.MultiArrayList(T).Slice,
            cur: IndexOpt,

            pub fn next(self: *Iterator) ?Index {
                const res = self.cur.toIndex() orelse return null;
                self.cur = self.nodes.items(.next)[res.toInt()];
                return res;
            }
        };

        pub fn iterator(self: Self, nodes: std.MultiArrayList(T).Slice) Iterator {
            return .{ .nodes = nodes, .cur = self.first };
        }

        pub fn isEmpty(self: Self) bool {
            return self.first == .none;
        }

        pub fn contains(self: Self, nodes: std.MultiArrayList(T).Slice, value: Index) bool {
            var iter = self.iterator(nodes);
            while (iter.next()) |v| {
                if (v == value) {
                    return true;
                }
            }
            return false;
        }

        pub fn len(self: Self, nodes: std.MultiArrayList(T).Slice) u32 {
            var iter = self.iterator(nodes);
            var res: u32 = 0;
            while (iter.next() != null) {
                res += 1;
            }
            return res;
        }

        pub fn prepend(self: *Self, nodes: std.MultiArrayList(T).Slice, node_index: Index) void {
            nodes.items(.next)[node_index.toInt()] = self.first;
            if (self.first.toIndex()) |first| {
                nodes.items(.prev)[first.toInt()] = node_index.toIndexOpt();
            }

            self.first = node_index.toIndexOpt();
            if (self.last == .none) {
                self.last = self.first;
            }
        }

        pub fn append(self: *Self, nodes: std.MultiArrayList(T).Slice, node_index: Index) void {
            nodes.items(.prev)[node_index.toInt()] = self.last;
            if (self.last.toInt()) |last| {
                nodes.items(.next)[last] = node_index.toIndexOpt();
            }

            self.last = node_index.toIndexOpt();
            if (self.first == .none) {
                self.first = self.last;
            }
        }

        pub fn insertBefore(self: *Self, nodes: std.MultiArrayList(T).Slice, existing_node: Index, new_node: Index) void {
            if (existing_node == self.first.toIndex().?) {
                self.prepend(nodes, new_node);
            } else {
                const existing_prev: *IndexOpt = &nodes.items(.prev)[existing_node.toInt()];
                nodes.items(.next)[existing_prev.toInt().?] = new_node;

                nodes.items(.prev)[new_node.toInt()] = existing_prev.*;
                nodes.items(.next)[new_node.toInt()] = existing_node;

                existing_prev.* = new_node.toIndexOpt();
            }
        }

        pub fn insertAfter(self: *Self, nodes: std.MultiArrayList(T).Slice, existing_node: Index, new_node: Index) void {
            if (existing_node == self.last.toIndex().?) {
                self.append(nodes, new_node);
            } else {
                const existing_next: *IndexOpt = &nodes.items(.next)[existing_node.toInt()];
                nodes.items(.prev)[existing_next.toInt().?] = new_node.toIndexOpt();

                nodes.items(.next)[new_node.toInt()] = existing_next.*;
                nodes.items(.prev)[new_node.toInt()] = existing_node.toIndexOpt();

                existing_next.* = new_node.toIndexOpt();
            }
        }

        pub fn popFirst(self: *Self, nodes: std.MultiArrayList(T).Slice) Index {
            const next = nodes.items(.next)[self.first.toInt().?];
            nodes.items(.prev)[next] = .none;
            nodes.items(.next)[self.first] = .none;
            defer self.first = next;
            return self.first;
        }

        pub fn popLast(self: *Self, nodes: std.MultiArrayList(T).Slice) Index {
            const prev = nodes.items(.prev)[self.last.toInt().?];
            nodes.items(.next)[prev] = .none;
            nodes.items(.prev)[self.last] = .none;
            defer self.last = prev;
            return self.last;
        }

        pub fn remove(self: *Self, nodes: std.MultiArrayList(T).Slice, node: Index) void {
            if (node == self.first) {
                _ = self.popFirst(nodes);
            } else if (node == self.last) {
                _ = self.popLast(nodes);
            } else {
                const prev = nodes.items(.prev)[node.toInt()];
                const next = nodes.items(.next)[node.toInt()];
                nodes.items(.next)[prev] = next;
                nodes.items(.prev)[next] = prev;

                nodes.items(.prev)[node] = .none;
                nodes.items(.next)[node] = .none;
            }
        }
    };
}
