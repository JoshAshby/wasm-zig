const std = @import("std");
const log = std.log.scoped(.wasm_zig);

const Store = @import("store.zig").Store;
const Module = @import("module.zig").Module;
const Extern = @import("externals.zig").Extern;
const ExternVec = @import("externals.zig").ExternVec;
const Func = @import("externals.zig").Func;
const Memory = @import("externals.zig").Memory;
const Trap = @import("trap.zig").Trap;

pub const Error = error{
  InstanceInit,
};

pub const Instance = opaque {
    /// Initializes a new `Instance` using the given `store` and `module`.
    /// The given ExternVec `imports` must match the order of the imports in
    /// the module and should be initialized using the same `Store` as given.
    pub fn init(store: *Store, module: *Module, imports: *ExternVec) !*Instance {
        var trap: ?*Trap = null;

        const instance = wasm_instance_new(store, module, imports, &trap);

        if (trap) |t| {
            defer t.deinit();
            const msg = t.message();
            defer msg.deinit();
            
            // TODO handle trap message
            log.err("code unexpectedly trapped - {s}", .{msg.toSlice()});
            return Error.InstanceInit;
        }

        return instance orelse Error.InstanceInit;
    }

    /// Frees the `Instance`'s resources
    pub fn deinit(self: *Instance) void {
        wasm_instance_delete(self);
    }

    /// Returns an export func by its name if found
    /// Asserts the export is of type `Func`
    /// The returned `Func` is a copy and must be freed by the caller
    pub fn getExportFunc(self: *Instance, module: *Module, name: []const u8) ?*Func {
        return if (self.getExport(module, name)) |exp| {
            defer exp.deinit(); // free the copy
            return exp.asFunc().copy();
        } else null;
    }

    pub fn exports(self: *Instance) ExternVec {
        var externs: ExternVec = undefined;
        wasm_instance_exports(self, &externs);
        return externs;
    }

    /// Returns an export by its name and `null` when not found
    /// The `Extern` is copied and must be freed manually
    ///
    /// a `Module` must be provided to find an extern by its name, rather than index.
    /// use getExportByIndex for quick access to an extern by index.
    pub fn getExport(self: *Instance, module: *Module, name: []const u8) ?*Extern {
        var externs = self.exports();
        defer externs.deinit();

        var mod_exports = module.exports();
        defer mod_exports.deinit();

        return for (mod_exports.toSlice()) |export_type, index| {
            const ty = export_type orelse continue;
            const type_name = ty.name();
            defer type_name.deinit();

            if (std.mem.eql(u8, name, type_name.toSlice())) {
                if (externs.data[index]) |ext| {
                    break ext.copy();
                }
            }
        } else null;
    }

    /// Returns an export by a given index. Returns null when the index
    /// is out of bounds. The extern is non-owned, meaning it's illegal
    /// behaviour to free its memory.
    pub fn getExportByIndex(self: *Instance, index: u32) ?*Extern {
        var externs: ExternVec = undefined;
        wasm_instance_exports(self, &externs);
        defer externs.deinit();

        if (index > externs.size) return null;
        return externs.data[index].?;
    }

    /// Returns an exported `Memory` when found and `null` when not.
    /// The result is copied and must be freed manually by calling `deinit()` on the result.
    pub fn getExportMem(self: *Instance, module: *Module, name: []const u8) ?*Memory {
        return if (self.getExport(module, name)) |exp| {
            defer exp.deinit(); // free the copy
            return exp.asMemory().copy();
        } else null;
    }

    extern "c" fn wasm_instance_new(*Store, *const Module, *const ExternVec, *?*Trap) ?*Instance;
    extern "c" fn wasm_instance_delete(*Instance) void;
    extern "c" fn wasm_instance_exports(*Instance, *ExternVec) void;
};