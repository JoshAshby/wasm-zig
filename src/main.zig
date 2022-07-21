const std = @import("std");
const testing = std.testing;
const log = std.log.scoped(.wasm_zig);

// Done
pub const Config = @import("engine.zig").Config;
pub const Engine = @import("engine.zig").Engine;

pub const Extern = @import("externals.zig").Extern;
pub const ExternVec = @import("externals.zig").ExternVec;
pub const Func = @import("externals.zig").Func;
pub const Global = @import("externals.zig").Global;
pub const Memory = @import("externals.zig").Memory;
pub const Table = @import("externals.zig").Table;

pub const Instance = @import("Instance.zig").Instance;

pub const Module = @import("module.zig").Module;

pub const Store = @import("store.zig").Store;

pub const Trap = @import("trap.zig").Trap;

pub const ByteVec = @import("types.zig").ByteVec;
pub const Exporttype = @import("types.zig").Exporttype;
pub const ExporttypeVec = @import("types.zig").ExporttypeVec;
pub const Externtype = @import("types.zig").Externtype;
pub const Frame = @import("types.zig").Frame;
pub const FrameVec = @import("types.zig").FrameVec;
pub const Functype = @import("types.zig").Functype;
pub const FunctypeVec = @import("types.zig").FunctypeVec;
pub const Globaltype = @import("types.zig").Globaltype;
pub const Importtype = @import("types.zig").Importtype;
pub const ImporttypeVec = @import("types.zig").ImporttypeVec;
pub const Limits = @import("types.zig").Limits;
pub const Memorytype = @import("types.zig").Memorytype;
pub const Ref = @import("types.zig").Ref;
pub const Tabletype = @import("types.zig").Tabletype;
pub const Valtype = @import("types.zig").Valtype;

// Done
pub const ValKind = @import("value.zig").ValKind;
pub const Val = @import("value.zig").Val;
pub const ValVec = @import("value.zig").ValVec;

test "" {
    testing.refAllDecls(@This());
}
