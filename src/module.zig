const Store = @import("store.zig").Store;
const ByteVec = @import("types.zig").ByteVec;

const ExporttypeVec = @import("types.zig").ExporttypeVec;
const ImporttypeVec = @import("types.zig").ImporttypeVec;

pub const Error = error{
  ModuleInit,
};

pub const Module = opaque {
    /// Initializes a new `Module` using the supplied Store and wasm bytecode
    pub fn init(store: *Store, bytes: []const u8) !*Module {
        var byte_vec = ByteVec.initWithCapacity(bytes.len);
        defer byte_vec.deinit();

        var i: usize = 0;
        var ptr = byte_vec.data;
        while (i < bytes.len) : (i += 1) {
            ptr.* = bytes[i];
            ptr += 1;
        }

        return wasm_module_new(store, &byte_vec) orelse return Error.ModuleInit;
    }

    pub fn deinit(self: *Module) void {
        wasm_module_delete(self);
    }

    /// Returns a list of export types in `ExportTypeVec`
    pub fn exports(self: *Module) ExporttypeVec {
        var vec: ExporttypeVec = undefined;
        wasm_module_exports(self, &vec);
        return vec;
    }

    pub fn imports(self: *Module) ImporttypeVec {
        var vec: ImporttypeVec = undefined;
        wasm_module_imports(self, &vec);
        return vec;
    }

    extern "c" fn wasm_module_new(*Store, *const ByteVec) ?*Module;
    extern "c" fn wasm_module_delete(*Module) void;
    extern "c" fn wasm_module_exports(?*const Module, *ExporttypeVec) void;
    extern "c" fn wasm_module_imports(?*const Module, *ImporttypeVec) void;
};