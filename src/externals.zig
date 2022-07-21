const std = @import("std");
const meta = std.meta;
const trait = std.meta.trait;
const log = std.log.scoped(.wasm_zig);

const Store = @import("store.zig").Store;
const Module = @import("module.zig").Module;
const Trap = @import("trap.zig").Trap;

const Memorytype = @import("types.zig").Memorytype;
const Globaltype = @import("types.zig").Globaltype;
const ValtypeVec = @import("types.zig").ValtypeVec;
const ExternKind = @import("types.zig").ExternKind;
const Externtype = @import("types.zig").Externtype;
const Valtype = @import("types.zig").Valtype;
const Functype = @import("types.zig").Functype;
const Ref = @import("value.zig").Ref;

const ValVec = @import("value.zig").ValVec;
const Valkind = @import("value.zig").Valkind;
const Val = @import("value.zig").Val;

pub const Error = error{
    FuncInit,
};

pub const Callback = fn (*const ValVec, *ValVec) callconv(.C) ?*Trap;
pub const CallbackWithEnv = fn (*anyopaque, *const ValVec, *ValVec) callconv(.C) ?*Trap;

pub const EnvFinalizer = fn (?*anyopaque) callconv(.C) void;

// [JASHBY] - Done
pub const Extern = opaque {
    /// Returns the `Extern` as a function
    /// returns `null` when the given `Extern` is not a function
    ///
    /// Asserts `Extern` is of type `Func`
    pub fn asFunc(self: *Extern) *Func {
        return wasm_extern_as_func(self).?;
    }

    /// Returns the `Extern` as a `Global`
    /// returns `null` when the given `Extern` is not a global
    ///
    /// Asserts `Extern` is of type `Global`
    pub fn asGlobal(self: *Extern) *Global {
        return wasm_extern_as_global(self).?;
    }

    /// Returns the `Extern` as a `Memory` object
    /// returns `null` when the given `Extern` is not a memory object
    ///
    /// Asserts `Extern` is of type `Memory`
    pub fn asMemory(self: *Extern) *Memory {
        return wasm_extern_as_memory(self).?;
    }

    /// Returns the `Extern` as a `Table`
    /// returns `null` when the given `Extern` is not a table
    ///
    /// Asserts `Extern` is of type `Table`
    pub fn asTable(self: *Extern) *Table {
        return wasm_extern_as_table(self).?;
    }

    /// Frees the memory of the `Extern`
    pub fn deinit(self: *Extern) void {
        wasm_extern_delete(self);
    }

    /// Creates a copy of the `Extern` and returns it
    /// Memory of the copied version must be freed manually by calling `deinit`
    ///
    /// Asserts the copy succeeds
    pub fn copy(self: *Extern) *Extern {
        return wasm_extern_copy(self).?;
    }

    extern "c" fn wasm_extern_as_func(*Extern) ?*Func;
    extern "c" fn wasm_extern_as_global(*Extern) ?*Global;
    extern "c" fn wasm_extern_as_memory(*Extern) ?*Memory;
    extern "c" fn wasm_extern_as_table(*Extern) ?*Table;
    extern "c" fn wasm_extern_delete(*Extern) void;
    extern "c" fn wasm_extern_copy(*Extern) ?*Extern;

    // TODO: Are these three eql, toType and kind part of the spec?
    /// Checks if the given externs are equal and returns true if so
    pub fn eql(self: *const Extern, other: *const Extern) bool {
        return wasm_extern_same(self, other);
    }

    /// Returns the type of an `Extern` as `Externtype`
    pub fn toType(self: *const Extern) *Externtype {
        return wasm_extern_type(self).?;
    }

    /// Returns the kind of an `Extern`
    pub fn kind(self: *const Extern) ExternKind {
        return wasm_extern_kind(self);
    }

    extern "c" fn wasm_extern_same(*const Extern, *const Extern) bool;
    extern "c" fn wasm_extern_type(?*const Extern) ?*Externtype;
    extern "c" fn wasm_extern_kind(?*const Extern) ExternKind;
};

// [JASHBY] - Done
pub const ExternVec = extern struct {
    size: usize,
    data: [*]?*Extern,

    pub fn init(data: []*Extern) ExternVec {
        var externs: ExternVec = undefined;
        wasm_extern_vec_new(&externs, data.len, data.ptr);
        return externs;
    }

    pub fn initEmpty() ExternVec {
        var externs: ExternVec = undefined;
        wasm_extern_vec_new_empty(&externs);
        return externs;
    }

    pub fn initWithCapacity(size: usize) ExternVec {
        var externs: ExternVec = undefined;
        wasm_extern_vec_new_uninitialized(&externs, size);
        return externs;
    }

    pub fn deinit(self: *ExternVec) void {
        wasm_extern_vec_delete(self);
    }

    pub fn copy(self: *ExternVec, to: *ExternVec) void {
        wasm_extern_vec_copy(to, self);
    }

    extern "c" fn wasm_extern_vec_new(*ExternVec, usize, [*]?*Extern) void;
    extern "c" fn wasm_extern_vec_new_empty(*ExternVec) void;
    extern "c" fn wasm_extern_vec_new_uninitialized(*ExternVec, usize) void;
    extern "c" fn wasm_extern_vec_delete(*ExternVec) void;
    extern "c" fn wasm_extern_vec_copy(* ExternVec, *const ExternVec) ?*Memory;
};

pub const Func = opaque {
    pub const CallError = error{
        /// Failed to call the function
        /// and resulted into an error
        InnerError,
        /// When the user provided a different ResultType to `Func.call`
        /// than what is defined by the wasm binary
        InvalidResultType,
        /// The given argument count to `Func.call` mismatches that
        /// of the func argument count of the wasm binary
        InvalidParamCount,
        /// The wasm function number of results mismatch that of the given
        /// ResultType to `Func.Call`. Note that `void` equals to 0 result types.
        InvalidResultCount,
        /// Function call resulted in an unexpected trap.
        Trap,
    };

    pub fn init(store: *Store, comptime callback: anytype) !*Func {
        var args: ValtypeVec = undefined;
        var results: ValtypeVec = undefined;

        const cb_meta = @typeInfo(@TypeOf(callback));

        switch (cb_meta) {
            .Fn => {
                const args_len = cb_meta.Fn.args.len;

                if (args_len == 0) {
                    args = ValtypeVec.empty();
                } else {
                    comptime var arg_types: [args_len]Valkind = undefined;
                    inline for (arg_types) |*arg, i| {
                        arg.* = switch (cb_meta.Fn.args[i].arg_type.?) {
                            i32, u32 => .i32,
                            i64, u64 => .i64,
                            f32 => .f32,
                            f64 => .f64,
                            *Func => .funcref,
                            *Extern => .anyref,
                            else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) ++ "'"),
                        };
                    }

                    args = ValtypeVec.initWithCapacity(args_len);
                    var i: usize = 0;
                    var ptr = args.data;
                    while (i < args_len) : (i += 1) {
                        ptr.* = Valtype.init(arg_types[i]);
                        ptr += 1;
                    }
                }

                if (cb_meta.Fn.return_type.? == void) {
                    results = ValtypeVec.empty();
                } else {
                    comptime var result_types: [1]Valkind = undefined;
                    result_types[0] = switch (cb_meta.Fn.return_type.?) {
                        i32, u32 => .i32,
                        i64, u64 => .i64,
                        f32 => .f32,
                        f64 => .f64,
                        *Func => .funcref,
                        *Extern => .anyref,
                        else => |ty| @compileError("Unsupported return type '" ++ @typeName(ty) ++ "'"),
                    };

                    results = ValtypeVec.initWithCapacity(1);
                    var i: usize = 0;
                    var ptr = results.data;
                    while (i < 1) : (i += 1) {
                        ptr.* = Valtype.init(result_types[i]);
                        ptr += 1;
                    }
                }

                const functype = wasm_functype_new(&args, &results) orelse return Error.FuncInit;
                defer wasm_functype_delete(functype);

                const lambda: Callback = struct {
                    fn l(params: ?*const ValVec, ress: ?*ValVec) callconv(.C) ?*Trap {
                        comptime var type_arr: []const type = &[0]type{};

                        inline for (cb_meta.Fn.args) |arg| {
                            if (arg.is_generic) unreachable;
                            type_arr = type_arr ++ @as([]const type, &[1]type{arg.arg_type.?});
                        }

                        var cb_args: std.meta.Tuple(type_arr) = undefined;
                        inline for (cb_meta.Fn.args) |arg, i| {
                            if (arg.is_generic) unreachable;

                            switch (arg.arg_type.?) {
                                i32, u32 => cb_args[i] = params.?.data[i].of.i32,
                                i64, u64 => cb_args[i] = params.?.data[i].of.i64,
                                f32 => cb_args[i] = params.?.data[i].of.f32,
                                f64 => cb_args[i] = params.?.data[i].of.f64,
                                *Func => cb_args[i] = @ptrCast(?*Func, params.?.data[i].of.ref).?,
                                *Extern => cb_args[i] = @ptrCast(?*Extern, params.?.data[i].of.ref).?,
                                else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) ++ "'"),
                            }
                        }

                        const result = @call(.{}, callback, cb_args);

                        if (cb_meta.Fn.return_type) |re_type| {
                            switch (re_type) {
                                void => {},
                                i32, u32 => ress.?.data[0] = .{ .kind = .i32, .of = .{ .i32 = @bitCast(i32, result) } },
                                i64, u64 => ress.?.data[0] = .{ .kind = .i64, .of = .{ .i64 = @bitCast(i64, result) } },
                                f32 => ress.?.data[0] = .{ .kind = .f32, .of = .{ .f32 = result } },
                                f64 => ress.?.data[0] = .{ .kind = .f64, .of = .{ .f64 = result } },
                                *Func => ress.?.data[0] = .{ .kind = .funcref, .of = .{ .ref = result } },
                                *Extern => ress.?.data[0] = .{ .kind = .anyref, .of = .{ .ref = result } },
                                else => |ty| @compileError("Unsupported return type '" ++ @typeName(ty) ++ "'"),
                            }
                        }

                        return null;
                    }
                }.l;

                return wasm_func_new(store, functype, lambda) orelse Error.FuncInit;
            },
            else => @compileError("only functions can be used as callbacks into Wasm"),
        }
    }

    // TODO
    pub fn initWithEnv(store: *Store, comptime callback: anytype, env: *anyopaque, env_finalizer: anytype) !*Func {
        var args: ValtypeVec = undefined;
        var results: ValtypeVec = undefined;

        const cb_meta = @typeInfo(@TypeOf(callback));

        switch (cb_meta) {
            .Fn => {
                const args_len = cb_meta.Fn.args.len;

                if (args_len == 0) {
                    args = ValtypeVec.empty();
                } else {
                    comptime var arg_types: [args_len]Valkind = undefined;
                    inline for (arg_types) |*arg, i| {
                        arg.* = switch (cb_meta.Fn.args[i].arg_type.?) {
                            i32, u32 => .i32,
                            i64, u64 => .i64,
                            f32 => .f32,
                            f64 => .f64,
                            *Func => .funcref,
                            *Extern => .anyref,
                            else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) ++ "'"),
                        };
                    }

                    args = ValtypeVec.initWithCapacity(args_len);
                    var i: usize = 0;
                    var ptr = args.data;
                    while (i < args_len) : (i += 1) {
                        ptr.* = Valtype.init(arg_types[i]);
                        ptr += 1;
                    }
                }

                if (cb_meta.Fn.return_type.? == void) {
                    results = ValtypeVec.empty();
                } else {
                    comptime var result_types: [1]Valkind = undefined;
                    result_types[0] = switch (cb_meta.Fn.return_type.?) {
                        i32, u32 => .i32,
                        i64, u64 => .i64,
                        f32 => .f32,
                        f64 => .f64,
                        *Func => .funcref,
                        *Extern => .anyref,
                        else => |ty| @compileError("Unsupported return type '" ++ @typeName(ty) ++ "'"),
                    };

                    results = ValtypeVec.initWithCapacity(1);
                    var i: usize = 0;
                    var ptr = results.data;
                    while (i < 1) : (i += 1) {
                        ptr.* = Valtype.init(result_types[i]);
                        ptr += 1;
                    }
                }

                const functype = wasm_functype_new(&args, &results) orelse return Error.FuncInit;
                defer wasm_functype_delete(functype);

                const lambda: Callback = struct {
                    fn l(params: ?*const ValVec, ress: ?*ValVec) callconv(.C) ?*Trap {
                        comptime var type_arr: []const type = &[0]type{};

                        inline for (cb_meta.Fn.args) |arg| {
                            if (arg.is_generic) unreachable;
                            type_arr = type_arr ++ @as([]const type, &[1]type{arg.arg_type.?});
                        }

                        var cb_args: std.meta.Tuple(type_arr) = undefined;
                        inline for (cb_meta.Fn.args) |arg, i| {
                            if (arg.is_generic) unreachable;

                            switch (arg.arg_type.?) {
                                i32, u32 => cb_args[i] = params.?.data[i].of.i32,
                                i64, u64 => cb_args[i] = params.?.data[i].of.i64,
                                f32 => cb_args[i] = params.?.data[i].of.f32,
                                f64 => cb_args[i] = params.?.data[i].of.f64,
                                *Func => cb_args[i] = @ptrCast(?*Func, params.?.data[i].of.ref).?,
                                *Extern => cb_args[i] = @ptrCast(?*Extern, params.?.data[i].of.ref).?,
                                else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) ++ "'"),
                            }
                        }

                        const result = @call(.{}, callback, cb_args);

                        if (cb_meta.Fn.return_type) |re_type| {
                            switch (re_type) {
                                void => {},
                                i32, u32 => ress.?.data[0] = .{ .kind = .i32, .of = .{ .i32 = @bitCast(i32, result) } },
                                i64, u64 => ress.?.data[0] = .{ .kind = .i64, .of = .{ .i64 = @bitCast(i64, result) } },
                                f32 => ress.?.data[0] = .{ .kind = .f32, .of = .{ .f32 = result } },
                                f64 => ress.?.data[0] = .{ .kind = .f64, .of = .{ .f64 = result } },
                                *Func => ress.?.data[0] = .{ .kind = .funcref, .of = .{ .ref = result } },
                                *Extern => ress.?.data[0] = .{ .kind = .anyref, .of = .{ .ref = result } },
                                else => |ty| @compileError("Unsupported return type '" ++ @typeName(ty) ++ "'"),
                            }
                        }

                        return null;
                    }
                }.l;

                return wasm_func_new_with_env(store, functype, lambda, env, env_finalizer) orelse Error.FuncInit;
            },
            else => @compileError("only functions can be used as callbacks into Wasm"),
        }
    }

    /// Returns the `Func` as an `Extern`
    ///
    /// Owned by `self` and shouldn't be deinitialized
    pub fn asExtern(self: *Func) *Extern {
        return wasm_func_as_extern(self).?;
    }

    /// Returns the `Func` from an `Extern`
    /// return null if extern's type isn't a functype
    ///
    /// Owned by `extern_func` and shouldn't be deinitialized
    pub fn fromExtern(extern_func: *Extern) ?*Func {
        return extern_func.asFunc();
    }

    /// Creates a copy of the current `Func`
    /// returned copy is owned by the caller and must be freed
    /// by the owner
    pub fn copy(self: *Func) *Func {
        return wasm_func_copy(self).?;
    }

    /// Tries to call the wasm function
    /// expects `args` to be tuple of arguments
    pub fn call(self: *Func, comptime ResultType: type, args: anytype) CallError!ResultType {
        if (!comptime trait.isTuple(@TypeOf(args)))
            @compileError("Expected 'args' to be a tuple, but found type '" ++ @typeName(@TypeOf(args)) ++ "'");

        const args_len = args.len;
        comptime var wasm_args: [args_len]Val = undefined;
        inline for (wasm_args) |*arg, i| {
            arg.* = switch (@TypeOf(args[i])) {
                i32, u32 => .{ .kind = .i32, .of = .{ .i32 = @bitCast(i32, args[i]) } },
                i64, u64 => .{ .kind = .i64, .of = .{ .i64 = @bitCast(i64, args[i]) } },
                f32 => .{ .kind = .f32, .of = .{ .f32 = args[i] } },
                f64 => .{ .kind = .f64, .of = .{ .f64 = args[i] } },
                *Func => .{ .kind = .funcref, .of = .{ .ref = args[i] } },
                *Extern => .{ .kind = .anyref, .of = .{ .ref = args[i] } },
                else => |ty| @compileError("Unsupported argument type '" ++ @typeName(ty) + "'"),
            };
        }

        // TODO multiple return values
        const result_len: usize = if (ResultType == void) 0 else 1;
        if (result_len != wasm_func_result_arity(self)) return CallError.InvalidResultCount;
        if (args_len != wasm_func_param_arity(self)) return CallError.InvalidParamCount;

        const final_args = ValVec{
            .size = args_len,
            .data = if (args_len == 0) undefined else @ptrCast([*]Val, &wasm_args),
        };

        var result_list = ValVec.initWithCapacity(result_len);
        defer result_list.deinit();

        const trap = wasm_func_call(self, &final_args, &result_list);

        if (trap) |t| {
            t.deinit();

            // TODO: This is causing a fun segfault when running a WASI start function ¯\_(ツ)_/¯ 
            const msg = t.message();
            defer msg.deinit();

            log.err("code unexpectedly trapped - {s}", .{msg.toSlice()});

            return CallError.Trap;
        }

        if (ResultType == void) return;

        // TODO: Handle multiple returns
        const result_ty = result_list.data[0];
        if (!matchesKind(ResultType, result_ty.kind)) return CallError.InvalidResultType;

        return switch (ResultType) {
            i32, u32 => @intCast(ResultType, result_ty.of.i32),
            i64, u64 => @intCast(ResultType, result_ty.of.i64),
            f32 => result_ty.of.f32,
            f64 => result_ty.of.f64,
            *Func => @ptrCast(?*Func, result_ty.of.ref).?,
            *Extern => @ptrCast(?*Extern, result_ty.of.ref).?,
            else => |ty| @compileError("Unsupported result type '" ++ @typeName(ty) ++ "'"),
        };
    }

    pub fn deinit(self: *Func) void {
        wasm_func_delete(self);
    }

    /// Returns tue if the given `kind` of `Valkind` can coerce to type `T`
    fn matchesKind(comptime T: type, kind: Valkind) bool {
        return switch (T) {
            i32, u32 => kind == .i32,
            i64, u64 => kind == .i64,
            f32 => kind == .f32,
            f64 => kind == .f64,
            *Func => kind == .funcref,
            *Extern => kind == .ref,
            else => false,
        };
    }

    pub fn paramArity(self: *Func) usize {
        return wasm_func_param_arity(self);
    }

    pub fn resultArity(self: *Func) usize {
        return wasm_func_result_arity(self);
    }

    // TODO
    // pub fn funcType(self: *Func) *Functype {}

    // TODO: Move these into types.zig
    extern "c" fn wasm_functype_new(args: *ValtypeVec, results: *ValtypeVec) ?*anyopaque;
    extern "c" fn wasm_functype_delete(functype: *anyopaque) void;

    extern "c" fn wasm_func_new(*Store, ?*anyopaque, Callback) ?*Func;
    extern "c" fn wasm_func_delete(*Func) void;
    extern "c" fn wasm_func_as_extern(*Func) ?*Extern;
    extern "c" fn wasm_func_copy(*const Func) ?*Func;

    extern "c" fn wasm_func_result_arity(*Func) usize;
    extern "c" fn wasm_func_param_arity(*Func) usize;

    extern "c" fn wasm_func_call(*Func, *const ValVec, *ValVec) ?*Trap;
    extern "c" fn wasm_func_new_with_env(?*anyopaque, ?*Func, *const ValVec, *ValVec)  ?*Trap;

    extern "c" fn wasm_func_type(?*Func) ?*Functype;
};

pub const Global = opaque {
    pub extern "c" fn wasm_global_delete(?*Global) void;
    pub extern "c" fn wasm_global_copy(?*const Global) ?*Global;
    pub extern "c" fn wasm_global_same(?*const Global, ?*const Global) bool;
    pub extern "c" fn wasm_global_get_host_info(?*const Global) ?*anyopaque;
    pub extern "c" fn wasm_global_set_host_info(?*Global, ?*anyopaque) void;
    pub extern "c" fn wasm_global_set_host_info_with_finalizer(?*Global, ?*anyopaque, ?EnvFinalizer) void;
    pub extern "c" fn wasm_global_as_ref(?*Global) ?*Ref;
    pub extern "c" fn wasm_global_as_ref_const(?*const Global) ?*const Ref;
    pub extern "c" fn wasm_global_new(?*Store, ?*const Globaltype, [*c]const Val) ?*Global;
    pub extern "c" fn wasm_global_type(?*const Global) ?*Globaltype;
    pub extern "c" fn wasm_global_get(?*const Global, out: [*c]Val) void;
    pub extern "c" fn wasm_global_set(?*Global, [*c]const Val) void;

    // TDOO
    pub extern "c" fn wasm_ref_as_global(?*Ref) ?*Global;
    pub extern "c" fn wasm_ref_as_global_const(?*const Ref) ?*const Global;
};


pub const Memory = opaque {
    /// Creates a new `Memory` object for the given `Store` and `Memorytype`
    pub fn init(store: *Store, mem_type: *const Memorytype) !*Memory {
        return wasm_memory_new(store, mem_type) orelse error.MemoryInit;
    }

    /// Returns the `Memorytype` of a given `Memory` object
    pub fn getType(self: *const Memory) *Memorytype {
        return wasm_memory_type(self).?;
    }

    /// Frees the memory of the `Memory` object
    pub fn deinit(self: *Memory) void {
        wasm_memory_delete(self);
    }

    /// Creates a copy of the given `Memory` object
    /// Returned copy must be freed manually.
    pub fn copy(self: *const Memory) ?*Memory {
        return wasm_memory_copy(self);
    }

    /// Returns true when the given `Memory` objects are equal
    pub fn eql(self: *const Memory, other: *const Memory) bool {
        return wasm_memory_same(self, other);
    }

    /// Returns a pointer-to-many bytes
    ///
    /// Tip: Use toSlice() to get a slice for better ergonomics
    pub fn data(self: *Memory) [*]u8 {
        return wasm_memory_data(self);
    }

    /// Returns the data size of the `Memory` object.
    pub fn size(self: *const Memory) usize {
        return wasm_memory_data_size(self);
    }

    /// Returns the amount of pages the `Memory` object consists of
    /// where each page is 65536 bytes
    pub fn pages(self: *const Memory) u32 {
        return wasm_memory_size(self);
    }

    /// Convenient helper function to represent the memory
    /// as a slice of bytes. Memory is however still owned by wasm
    /// and must be freed by calling `deinit` on the original `Memory` object
    pub fn toSlice(self: *Memory) []const u8 {
        var slice: []const u8 = undefined;
        slice.ptr = self.data();
        slice.len = self.size();
        return slice;
    }

    /// Increases the amount of memory pages by the given count.
    pub fn grow(self: *Memory, page_count: u32) error{OutOfMemory}!void {
        if (!wasm_memory_grow(self, page_count)) return error.OutOfMemory;
    }

    extern "c" fn wasm_memory_delete(*Memory) void;
    extern "c" fn wasm_memory_copy(*const Memory) ?*Memory;
    extern "c" fn wasm_memory_same(*const Memory, *const Memory) bool;
    extern "c" fn wasm_memory_new(*Store, *const Memorytype) ?*Memory;
    extern "c" fn wasm_memory_type(*const Memory) *Memorytype;
    extern "c" fn wasm_memory_data(*Memory) [*]u8;
    extern "c" fn wasm_memory_data_size(*const Memory) usize;
    extern "c" fn wasm_memory_grow(*Memory, delta: u32) bool;
    extern "c" fn wasm_memory_size(*const Memory) u32;

    // TODO
    extern "c" fn wasm_memory_as_extern(?*Memory) ?*Extern;
};


// TODO: implement table and global types
pub const Table = opaque {
    // extern "c" fn wasm_table_as_extern
    // extern "c" fn wasm_table_copy
    // extern "c" fn wasm_table_delete
    // extern "c" fn wasm_table_grow
    // extern "c" fn wasm_table_new
    // extern "c" fn wasm_table_same
    // extern "c" fn wasm_table_size
};