const std = @import("std");
const support = @import("support");

pub const TypeHandle = packed struct(u32) {
    kind: Kind,
    aggregate_index: AggregateIndex = 0,

    pub const AggregateIndex = u28;

    pub fn primitive(kind: Kind) TypeHandle {
        std.debug.assert(kind != .@"struct");
        std.debug.assert(kind != .array);
        std.debug.assert(kind != .function);
        return .{ .kind = kind };
    }

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
};

pub const Type = union(enum) {
    primitive: TypeHandle.Kind,
    function: Function,
    @"struct": Struct,
    array: Array,
};

pub const Function = struct {
    rettype: TypeHandle,
    params: []const TypeHandle,
};

pub const Struct = struct {
    fields: []const TypeHandle,
};

pub const Array = struct {
    size: u64,
    element_type: TypeHandle,
};

const ExtraIndex = support.index(TypeHandle, u32);
const ExtraRange = struct { begin: ExtraIndex, len: u32 };

pub const TypeStorage = struct {
    functions: FunctionTypeStorage,
    structs: StructTypeStorage,
    arrays: std.array_hash_map.Auto(Array, void),
    extras: std.ArrayList(TypeHandle),

    pub const empty: TypeStorage = .{
        .arrays = .empty,
        .functions = .empty,
        .structs = .empty,
        .extras = .empty,
    };

    pub fn deinit(self: *TypeStorage, gpa: std.mem.Allocator) void {
        defer self.* = undefined;

        self.functions.deinit(gpa);
        self.structs.deinit(gpa);
        self.arrays.deinit(gpa);
        self.extras.deinit(gpa);
    }

    pub fn getFullType(self: TypeStorage, ty: TypeHandle) Type {
        return switch (ty.kind) {
            .function => .{ .function = self.functions.getFull(self.extras.items, ty.aggregate_index) },
            .@"struct" => .{ .@"struct" = self.structs.getFull(self.extras.items, ty.aggregate_index) },
            .array => .{ .array = self.arrays.keys()[ty.aggregate_index] },
            else => |kind| .{ .primitive = kind },
        };
    }

    pub fn lookupFunctionType(self: TypeStorage, rettype: TypeHandle, params: []const TypeHandle) ?TypeHandle {
        return self.functions.get(self.extras.items, rettype, params);
    }

    pub fn createFunctionType(
        self: *TypeStorage,
        gpa: std.mem.Allocator,
        rettype: TypeHandle,
        params: []const TypeHandle,
    ) !TypeHandle {
        if (self.lookupFunctionType(rettype, params)) |res| {
            return res;
        }

        const params_begin: ExtraIndex =
            if (std.mem.find(TypeHandle, self.extras.items, params)) |start|
                @fromBackingInt(@intCast(start))
            else store: {
                const prev_len = self.extras.items.len;
                try self.extras.appendSlice(gpa, params);
                break :store @fromBackingInt(@intCast(prev_len));
            };

        const index: TypeHandle.AggregateIndex = @intCast(self.functions.len());
        try self.functions.putNoClobber(
            gpa,
            self.extras.items,
            rettype,
            .{ .begin = params_begin, .len = @intCast(params.len) },
        );

        return .{ .kind = .function, .aggregate_index = index };
    }

    pub fn lookupStructType(self: TypeStorage, fields: []const TypeHandle) ?TypeHandle {
        return self.structs.get(self.extras.items, fields);
    }

    pub fn createStructType(
        self: *TypeStorage,
        gpa: std.mem.Allocator,
        fields: []const TypeHandle,
    ) !TypeHandle {
        if (self.lookupStructType(fields)) |res| {
            return res;
        }

        const fields_begin: ExtraIndex =
            if (std.mem.find(TypeHandle, self.extras.items, fields)) |start|
                @fromBackingInt(@intCast(start))
            else store: {
                const prev_len = self.extras.items.len;
                try self.extras.appendSlice(gpa, fields);
                break :store @fromBackingInt(@intCast(prev_len));
            };

        const index: TypeHandle.AggregateIndex = @intCast(self.structs.len());
        try self.structs.putNoClobber(
            gpa,
            self.extras.items,
            .{ .fields = .{ .begin = fields_begin, .len = @intCast(fields.len) } },
        );
        return .{ .kind = .@"struct", .data = .{ .aggregate_index = index } };
    }

    pub fn lookupArrayType(self: TypeStorage, size: u64, element_type: TypeHandle) ?TypeHandle {
        const idx = self.arrays.getIndex(.{ .element_type = element_type, .size = size }) orelse
            return null;
        return .{ .kind = .array, .aggregate_index = @intCast(idx) };
    }

    pub fn createArrayType(
        self: *TypeStorage,
        gpa: std.mem.Allocator,
        size: u64,
        element_type: TypeHandle,
    ) !TypeHandle {
        const gop_res = try self.arrays.getOrPut(gpa, .{ .size = size, .element_type = element_type });
        return .{ .kind = .array, .data = .{ .aggregate_index = @intCast(gop_res.index) } };
    }
};

const FunctionTypeStorage = struct {
    functions: std.array_hash_map.Custom(FunctionInternal, void, Context, true),

    pub const empty: FunctionTypeStorage = .{ .functions = .empty };

    pub fn deinit(self: *FunctionTypeStorage, gpa: std.mem.Allocator) void {
        self.functions.deinit(gpa);
    }

    pub fn getFull(self: FunctionTypeStorage, extras: []const TypeHandle, index: u32) Function {
        const func = self.functions.keys()[index];
        const params = extras[func.params.begin.toInt()..][0..func.params.len];
        return .{ .rettype = func.rettype, .params = params };
    }

    pub fn len(self: FunctionTypeStorage) usize {
        return self.functions.entries.len;
    }

    pub fn get(
        self: FunctionTypeStorage,
        extras: []const TypeHandle,
        rettype: TypeHandle,
        params: []const TypeHandle,
    ) ?TypeHandle {
        const idx_opt = self.functions.getIndexAdapted(
            Key{ .rettype = rettype, .params = params },
            Adaptor{ .extras = extras },
        );

        const idx = idx_opt orelse return null;
        return .{ .kind = .function, .aggregate_index = @intCast(idx) };
    }

    pub fn putNoClobber(
        self: *FunctionTypeStorage,
        gpa: std.mem.Allocator,
        extras: []const TypeHandle,
        rettype: TypeHandle,
        params: ExtraRange,
    ) !void {
        try self.functions.putNoClobberContext(
            gpa,
            .{ .rettype = rettype, .params = params },
            {},
            .{ .adaptor = .{ .extras = extras } },
        );
    }

    const FunctionInternal = struct {
        rettype: TypeHandle,
        params: ExtraRange,
    };

    const Key = struct { rettype: TypeHandle, params: []const TypeHandle };

    const Adaptor = struct {
        extras: []const TypeHandle,

        pub fn hash(self: @This(), k: Key) u32 {
            _ = self;

            var hasher = std.hash.Wyhash.init(0);
            std.hash.autoHash(&hasher, k.rettype);
            std.hash.autoHashStrat(&hasher, k.params, .DeepRecursive);
            return @truncate(hasher.final());
        }

        pub fn eql(self: @This(), new: Key, existing: FunctionInternal, i: usize) bool {
            _ = i;

            const existing_params = self.extras[existing.params.begin.toInt()..][0..existing.params.len];

            const same_rettype = new.rettype == existing.rettype;
            const same_params = std.mem.eql(TypeHandle, new.params, existing_params);

            return same_rettype and same_params;
        }
    };

    const Context = struct {
        adaptor: Adaptor,

        pub fn hash(self: @This(), k: FunctionInternal) u32 {
            const params = self.adaptor.extras[k.params.begin.toInt()..][0..k.params.len];
            return self.adaptor.hash(.{ .params = params, .rettype = k.rettype });
        }

        pub fn eql(self: @This(), a: FunctionInternal, b: FunctionInternal, i: usize) bool {
            const params = self.adaptor.extras[a.params.begin.toInt()..][0..a.params.len];
            return self.adaptor.eql(.{ .params = params, .rettype = a.rettype }, b, i);
        }
    };
};

const StructTypeStorage = struct {
    structs: std.array_hash_map.Custom(StructInternal, void, Context, true),

    pub const empty: StructTypeStorage = .{ .structs = .empty };

    pub fn deinit(self: *StructTypeStorage, gpa: std.mem.Allocator) void {
        self.structs.deinit(gpa);
    }

    pub fn getFull(self: StructTypeStorage, extras: []const TypeHandle, index: u32) Struct {
        const s = self.structs.keys()[index];
        const fields = extras[s.fields.begin.toInt()..][0..s.fields.len];
        return .{ .fields = fields };
    }

    pub fn len(self: StructTypeStorage) usize {
        return self.structs.entries.len;
    }

    pub fn get(self: StructTypeStorage, extras: []const TypeHandle, fields: []const TypeHandle) ?TypeHandle {
        const idx_opt = self.structs.getIndexAdapted(
            Key{ .fields = fields },
            Context{ .extras = extras },
        );
        const idx = idx_opt orelse return null;
        return .{ .kind = .@"struct", .aggregate_index = @intCast(idx) };
    }

    pub fn putNoClobber(
        self: *FunctionTypeStorage,
        gpa: std.mem.Allocator,
        extras: []const TypeHandle,
        fields: ExtraRange,
    ) !void {
        try self.structs.putNoClobberContext(
            gpa,
            .{ .fields = fields },
            {},
            .{ .adaptor = .{ .extras = extras } },
        );
    }

    const StructInternal = struct {
        fields: ExtraRange,
    };

    const Key = struct { fields: []const TypeHandle };

    const Adaptor = struct {
        extras: []const TypeHandle,

        pub fn hash(self: @This(), k: Key) u64 {
            _ = self;
            return @truncate(std.hash.Wyhash.hash(0, std.mem.asBytes(k.params)));
        }

        pub fn eql(self: @This(), new: Key, existing: StructInternal, i: usize) bool {
            _ = i;

            const existing_fields = self.extras[existing.fields.begin.toInt()..][0..existing.fields.len];
            return std.mem.eql(TypeHandle, new.fields, existing_fields);
        }
    };

    const Context = struct {
        adaptor: Adaptor,

        pub fn hash(self: @This(), k: StructInternal) u32 {
            const fields = self.adaptor.extras[k.fields.begin.toInt()..][0..k.fields.len];
            return self.adaptor.hash(.{ .fields = fields });
        }

        pub fn eql(self: @This(), a: StructInternal, b: StructInternal, i: usize) bool {
            const fields = self.extras[a.fields.begin.toInt()..][0..a.fields.len];
            return self.adaptor.eql(.{ .fields = fields }, b, i);
        }
    };
};
