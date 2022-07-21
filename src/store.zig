const Engine = @import("engine.zig").Engine;

pub const Error = error{
  StoreInit,
};

pub const Store = opaque {
    /// Initializes a new `Store` based on the given `Engine`
    pub fn init(engine: *Engine) !*Store {
        return wasm_store_new(engine) orelse Error.StoreInit;
    }

    /// Frees the resource of the `Store` itself
    pub fn deinit(self: *Store) void {
        wasm_store_delete(self);
    }

    extern "c" fn wasm_store_new(*Engine) ?*Store;
    extern "c" fn wasm_store_delete(*Store) void;
};