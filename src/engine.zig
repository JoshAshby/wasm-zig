const std = @import("std");

pub const Error = error{
  ConfigInit,
  EngineInit
};

// [JASHBY] - Done
pub const Config = opaque {
    pub fn init() !*Config {
        const config = wasm_config_new() orelse return Error.ConfigInit;
        return config;
    }

    pub fn deinit(self: *Config) void {
      wasm_config_delete(self);
    }

    extern "c" fn wasm_config_new() ?*Config;
    extern "c" fn wasm_config_delete(?*Config) void;
};

// [JASHBY] - Done
pub const Engine = opaque {
    /// Initializes a new `Engine`
    pub fn init() !*Engine {
        return wasm_engine_new() orelse Error.EngineInit;
    }

    pub fn initWithConfig(config: *Config) !*Engine {
        return wasm_engine_new_with_config(config) orelse Error.EngineInit;
    }

    /// Frees the resources of the `Engine`
    pub fn deinit(self: *Engine) void {
        wasm_engine_delete(self);
    }

    extern "c" fn wasm_engine_new() ?*Engine;
    extern "c" fn wasm_engine_new_with_config(*Config) ?*Engine;
    extern "c" fn wasm_engine_delete(*Engine) void;
};