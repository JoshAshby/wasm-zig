const Ref = @import("types.zig").Ref;

// [JASHBY] - Done
pub const Valkind = enum(u8) {
    i32 = 0,
    i64 = 1,
    f32 = 2,
    f64 = 3,
    anyref = 128,
    funcref = 129,
};

// [JASHBY] - Done
pub const Val = extern struct {
    kind: Valkind,
    of: extern union {
        i32: i32,
        i64: i64,
        f32: f32,
        f64: f64,
        ref: ?*Ref,
    },

    pub fn deinit(self: *Val) void {
        wasm_val_delete(self);
    }

    pub fn copy(self: *Val, to: *Val) void {
        wasm_val_copy(to, self);
    }

    extern "c" fn wasm_val_delete(*Val) void;
    extern "c" fn wasm_val_copy(*Val, *const Val) void;
};

// [JASHBY] - Done
pub const ValVec = extern struct {
    size: usize,
    data: [*]Val,

    pub fn init(values: []Val) ValVec {
        var vec: ValVec = undefined;
        wasm_val_vec_new(&vec, values.len, values.ptr);
        return vec;
    }

    pub fn initWithCapacity(size: usize) ValVec {
        var vec: ValVec = undefined;
        wasm_val_vec_new_uninitialized(&vec, size);
        return vec;
    }

    pub fn initEmpty() ValVec {
        var vec: ValVec = undefined;
        wasm_val_vec_new_empty(&vec);
        return vec;
    }

    pub fn deinit(self: *ValVec) void {
        self.wasm_val_vec_delete();
    }

    pub fn copy(self: *ValVec, to: *ValVec) void {
        wasm_val_vec_copy(to, self);
    }

    extern "c" fn wasm_val_vec_new(*ValVec, usize) void;
    extern "c" fn wasm_val_vec_new_empty(*ValVec, usize) void;
    extern "c" fn wasm_val_vec_new_uninitialized(*ValVec, usize) void;
    extern "c" fn wasm_val_vec_delete(*ValVec) void;
    extern "c" fn wasm_val_vec_copy(*ValVec, *const ValVec) void;
};