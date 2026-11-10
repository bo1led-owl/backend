const Type = @This();

const std = @import("std");
const support = @import("support");

kind: Kind,
data: union {
    primitive: void,
    function: Function,
    @"struct": Struct,
    array: Array,
},

pub const Kind = enum(u4) {
    unit,
    ptr,
    bit,
    int8,
    int16,
    int32,
    int64,
    @"struct",
    array,
    function,
};

pub const Function = struct {
    rettype: Type.Handle,
    params: Storage.ExtraRange,
};
pub const Struct = struct {
    fields: Storage.ExtraRange,
};
pub const Array = struct {
    size: u64,
    element_type: Handle,
};

pub const Handle = packed struct(u32) {
    kind: Kind,
    aggregate_index: AggregateIndex = 0,
    pub const AggregateIndex = u28;
    pub fn primitive(kind: Kind) Handle {
        return .{ .kind = kind };
    }
};

pub const Storage = struct {
    functions: std.array_hash_map.Custom(Function, void, FunctionContext, true),
    structs: std.array_hash_map.Custom(Struct, void, StructContext, true),
    arrays: std.array_hash_map.Auto(Type.Array, void),
    extras: std.ArrayList(Type.Handle),

    pub const empty: Storage = .{
        .functions = .empty,
        .structs = .empty,
        .arrays = .empty,
        .extras = .empty,
    };

    pub const ExtraIndex = support.index(Type.Handle, u32);
    pub const ExtraRange = struct { begin: ExtraIndex, len: u32 };

    pub fn deinit(self: *Storage, gpa: std.mem.Allocator) void {
        defer self.* = undefined;
        self.functions.deinit(gpa);
        self.structs.deinit(gpa);
        self.arrays.deinit(gpa);
        self.extras.deinit(gpa);
    }

    pub fn getFullType(self: Storage, ty: Type.Handle) Type {
        return .{ .kind = ty.kind, .data = switch (ty.kind) {
            .function => .{ .function = self.functions.keys()[ty.aggregate_index] },
            .@"struct" => .{ .@"struct" = self.structs.keys()[ty.aggregate_index] },
            .array => .{ .array = self.arrays.keys()[ty.aggregate_index] },
            else => .{ .primitive = {} },
        } };
    }

    pub fn getFullFunctionType(self: Storage, index: u32) Function {
        return self.functions.keys()[index];
    }
    pub fn getFullStructType(self: Storage, index: u32) Struct {
        return self.structs.keys()[index];
    }
    pub fn getFullArrayType(self: Storage, index: u32) Array {
        return self.arrays.keys()[index];
    }

    pub fn getExtras(self: Storage, range: ExtraRange) []Type.Handle {
        return self.extras.items[range.begin.toInt()..][0..range.len];
    }

    pub fn createFunctionType(
        self: *Storage,
        gpa: std.mem.Allocator,
        rettype: Type.Handle,
        params: []const Type.Handle,
    ) !Type.Handle {
        if (self.findExistingFunctionType(rettype, params)) |res| return res;

        const params_begin: ExtraIndex =
            if (std.mem.indexOf(Type.Handle, self.extras.items, params)) |start|
                @fromBackingInt(@intCast(start))
            else store: {
                const prev_len = self.extras.items.len;
                try self.extras.appendSlice(gpa, params);
                break :store @fromBackingInt(@intCast(prev_len));
            };

        const index: Type.Handle.AggregateIndex = @intCast(self.functions.entries.len);
        try self.putFunctionType(
            gpa,
            rettype,
            .{ .begin = params_begin, .len = @intCast(params.len) },
        );
        return .{ .kind = .function, .aggregate_index = index };
    }

    pub fn createStructType(
        self: *Storage,
        gpa: std.mem.Allocator,
        fields: []const Type.Handle,
    ) !Type.Handle {
        if (self.findExistingStructType(fields)) |res| return res;

        const fields_begin: ExtraIndex =
            if (std.mem.indexOf(Type.Handle, self.extras.items, fields)) |start|
                @fromBackingInt(@intCast(start))
            else store: {
                const prev_len = self.extras.items.len;
                try self.extras.appendSlice(gpa, fields);
                break :store @fromBackingInt(@intCast(prev_len));
            };

        const index: Type.Handle.AggregateIndex = @intCast(self.structs.entries.len);
        try self.putStructType(
            gpa,
            .{ .begin = fields_begin, .len = @intCast(fields.len) },
        );
        return .{ .kind = .@"struct", .aggregate_index = index };
    }

    pub fn createArrayType(
        self: *Storage,
        gpa: std.mem.Allocator,
        size: u64,
        element_type: Type.Handle,
    ) !Type.Handle {
        const gop_res = try self.arrays.getOrPut(gpa, .{ .size = size, .element_type = element_type });
        return .{ .kind = .array, .aggregate_index = @intCast(gop_res.index) };
    }

    fn findExistingFunctionType(self: Storage, rettype: Type.Handle, params: []const Type.Handle) ?Type.Handle {
        const idx_opt = self.functions.getIndexAdapted(
            FunctionKey{ .rettype = rettype, .params = params },
            FunctionAdaptor{ .extras = self.extras.items },
        );
        const idx = idx_opt orelse return null;
        return .{ .kind = .function, .aggregate_index = @intCast(idx) };
    }

    fn putFunctionType(self: *Storage, gpa: std.mem.Allocator, rettype: Type.Handle, params: ExtraRange) !void {
        try self.functions.putNoClobberContext(
            gpa,
            .{ .rettype = rettype, .params = params },
            {},
            .{ .adaptor = .{ .extras = self.extras.items } },
        );
    }

    fn findExistingStructType(self: Storage, fields: []const Type.Handle) ?Type.Handle {
        const idx_opt = self.structs.getIndexAdapted(
            StructKey{ .fields = fields },
            StructAdaptor{ .extras = self.extras.items },
        );
        const idx = idx_opt orelse return null;
        return .{ .kind = .@"struct", .aggregate_index = @intCast(idx) };
    }

    fn putStructType(self: *Storage, gpa: std.mem.Allocator, fields: ExtraRange) !void {
        try self.structs.putNoClobberContext(
            gpa,
            .{ .fields = fields },
            {},
            .{ .adaptor = .{ .extras = self.extras.items } },
        );
    }

    const FunctionKey = struct { rettype: Type.Handle, params: []const Type.Handle };

    const FunctionAdaptor = struct {
        extras: []const Type.Handle,

        pub fn hash(self: @This(), k: FunctionKey) u32 {
            _ = self;
            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, k.rettype);
            std.hash.autoHashStrat(&hasher, k.params, .DeepRecursive);
            return @truncate(hasher.final());
        }

        pub fn eql(self: @This(), new: FunctionKey, existing: Function, _: usize) bool {
            const existing_params = self.extras[existing.params.begin.toInt()..][0..existing.params.len];
            return new.rettype == existing.rettype and std.mem.eql(Type.Handle, new.params, existing_params);
        }
    };

    const FunctionContext = struct {
        adaptor: FunctionAdaptor,
        pub fn hash(self: @This(), k: Function) u32 {
            const params = self.adaptor.extras[k.params.begin.toInt()..][0..k.params.len];
            return self.adaptor.hash(.{ .params = params, .rettype = k.rettype });
        }
        pub fn eql(self: @This(), a: Function, b: Function, i: usize) bool {
            const params = self.adaptor.extras[a.params.begin.toInt()..][0..a.params.len];
            return self.adaptor.eql(.{ .params = params, .rettype = a.rettype }, b, i);
        }
    };

    const StructKey = struct { fields: []const Type.Handle };

    const StructAdaptor = struct {
        extras: []const Type.Handle,

        pub fn hash(_: @This(), k: StructKey) u32 {
            return @truncate(std.hash.Wyhash.hash(0, std.mem.asBytes(k.fields)));
        }

        pub fn eql(self: @This(), new: StructKey, existing: Struct, _: usize) bool {
            const existing_fields = self.extras[existing.fields.begin.toInt()..][0..existing.fields.len];
            return std.mem.eql(Type.Handle, new.fields, existing_fields);
        }
    };

    const StructContext = struct {
        adaptor: StructAdaptor,
        pub fn hash(self: @This(), k: Struct) u32 {
            const fields = self.adaptor.extras[k.fields.begin.toInt()..][0..k.fields.len];
            return self.adaptor.hash(.{ .fields = fields });
        }
        pub fn eql(self: @This(), a: Struct, b: Struct, i: usize) bool {
            const fields = self.adaptor.extras[a.fields.begin.toInt()..][0..a.fields.len];
            return self.adaptor.eql(.{ .fields = fields }, b, i);
        }
    };
};
