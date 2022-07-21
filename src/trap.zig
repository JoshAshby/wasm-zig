const ByteVec = @import("types.zig").ByteVec;

pub const Trap = opaque {
    pub fn deinit(self: *Trap) void {
        wasm_trap_delete(self);
    }

    /// Returns the trap message.
    /// Memory of the returned `ByteVec` must be freed using `deinit`
    pub fn message(self: *Trap) *ByteVec {
        var bytes: ?*ByteVec = null;
        wasm_trap_message(self, &bytes);
        return bytes.?;
    }

    extern "c" fn wasm_trap_delete(*Trap) void;
    extern "c" fn wasm_trap_message(*const Trap, out: *?*ByteVec) void;
};