const std = @import("std");

const Extern = @import("externals.zig").Extern;
const Valkind = @import("value.zig").Valkind;

pub const ByteVec = extern struct {
    size: usize,
    data: [*]u8,

    /// Initializes a new wasm byte vector
    pub fn initWithCapacity(size: usize) ByteVec {
        var bytes: ByteVec = undefined;
        wasm_byte_vec_new_uninitialized(&bytes, size);
        return bytes;
    }

    /// Initializes and copies contents of the input slice
    pub fn fromSlice(slice: []const u8) ByteVec {
        var bytes: ByteVec = undefined;
        wasm_byte_vec_new(&bytes, slice.len, slice.ptr);
        return bytes;
    }

    /// Returns a slice to the byte vector
    pub fn toSlice(self: ByteVec) []const u8 {
        return self.data[0..self.size];
    }

    /// Frees the memory allocated by initWithCapacity
    pub fn deinit(self: *ByteVec) void {
        wasm_byte_vec_delete(self);
    }

    extern "c" fn wasm_byte_vec_new(*ByteVec, usize, [*]const u8) void;
    extern "c" fn wasm_byte_vec_new_uninitialized(*ByteVec, usize) void;
    extern "c" fn wasm_byte_vec_delete(*ByteVec) void;
};

pub const Exporttype = opaque {
    /// Returns the name of the given `Exporttype`
    pub fn name(self: *Exporttype) *ByteVec {
        return self.wasm_exporttype_name().?;
    }

    extern "c" fn wasm_exporttype_name(*Exporttype) ?*ByteVec;
};

pub const ExporttypeVec = extern struct {
    size: usize,
    data: [*]?*Exporttype,

    /// Returns a slice of an `ExporttypeVec`.
    /// Memory is still owned by the runtime and can only be freed using
    /// `deinit()` on the original `ExporttypeVec`
    pub fn toSlice(self: *const ExporttypeVec) []const ?*Exporttype {
        return self.data[0..self.size];
    }

    pub fn deinit(self: *ExporttypeVec) void {
        self.wasm_exporttype_vec_delete();
    }

    extern "c" fn wasm_exporttype_vec_delete(*ExporttypeVec) void;
};

pub const ExternKind = std.wasm.ExternalKind;

pub const Externtype = opaque {
    /// Creates an `Externtype` from an existing `Extern`
    pub fn fromExtern(extern_object: *const Extern) *Externtype {
        return Extern.wasm_extern_type(extern_object).?;
    }

    /// Frees the memory of given `Externtype`
    pub fn deinit(self: *Externtype) void {
        wasm_externtype_delete(self);
    }

    /// Copies the given export type. Returned copy's memory must be
    /// freed manually by calling `deinit()` on the object.
    pub fn copy(self: *Externtype) *Externtype {
        return wasm_externtype_copy(self).?;
    }

    /// Returns the `ExternKind` from a given export type.
    pub fn kind(self: *const Externtype) ExternKind {
        return wasm_externtype_kind(self);
    }

    extern "c" fn wasm_externtype_delete(?*Externtype) void;
    extern "c" fn wasm_externtype_copy(?*Externtype) ?*Externtype;
    extern "c" fn wasm_externtype_kind(?*const Externtype) ExternKind;
};

pub const Limits = extern struct {
    min: u32,
    max: u32,
};

pub const Memorytype = opaque {
    pub fn init(limits: Limits) !*Memorytype {
        return wasm_memorytype_new(&limits) orelse return error.InitMemoryType;
    }

    pub fn deinit(self: *Memorytype) void {
        wasm_memorytype_delete(self);
    }

    extern "c" fn wasm_memorytype_new(*const Limits) ?*Memorytype;
    extern "c" fn wasm_memorytype_delete(*Memorytype) void;
};

pub const Importtype = extern struct {
    module: ByteVec,
    name: ByteVec,
    extern_type: *Externtype
};

pub const ImporttypeVec = extern struct {
    size: usize,
    data: [*]?*Importtype,

    pub fn deinit(_: *ImporttypeVec) void {}
};

pub const Valtype = opaque {
    /// Initializes a new `Valtype` based on the given `Valkind`
    pub fn init(valKind: Valkind) *Valtype {
        return wasm_valtype_new(@enumToInt(valKind));
    }

    pub fn deinit(self: *Valtype) void {
        wasm_valtype_delete(self);
    }

    /// Returns the `Valkind` of the given `Valtype`
    pub fn kind(self: *Valtype) Valkind {
        return @intToEnum(Valkind, wasm_valtype_kind(self));
    }

    extern "c" fn wasm_valtype_new(kind: u8) *Valtype;
    extern "c" fn wasm_valtype_delete(*Valkind) void;
    extern "c" fn wasm_valtype_kind(*Valkind) u8;
};

pub const ValtypeVec = extern struct {
    size: usize,
    data: [*]?*Valtype,

    pub fn initWithTypes(valtypes: [*]?*Valtype, len: usize) ValtypeVec {
        var vec: ValtypeVec = undefined;
        wasm_valtype_vec_new(&vec, len, &valtypes);
        return vec;
    }

    pub fn initWithCapacity(len: usize) ValtypeVec {
        var vec: ValtypeVec = undefined;
        wasm_valtype_vec_new_uninitialized(&vec, len);
        return vec;
    }

    pub fn deinit(self: *ValtypeVec) void {
        wasm_valtype_vec_delete(self);
    }

    pub fn empty() ValtypeVec {
        var vec: ValtypeVec = undefined;
        wasm_valtype_vec_new_empty(&vec);
        return vec;
    }

    extern "c" fn wasm_valtype_vec_new(*ValtypeVec, usize, *const [*]?*Valtype) void;
    extern "c" fn wasm_valtype_vec_new_empty(*ValtypeVec) void;
    extern "c" fn wasm_valtype_vec_new_uninitialized(*ValtypeVec, usize) void;

    extern "c" fn wasm_valtype_vec_delete(*ValtypeVec) void;
    extern "c" fn wasm_valtype_vec_copy(*ValtypeVec, *const *ValtypeVec) void;
};

pub const Functype = opaque {};
pub const Ref = opaque {};