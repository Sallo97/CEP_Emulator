//! The root file for the module holding all the basic circuits components.
//! It calls also all the tests.

const std = @import("std");
pub const adderF = @import("adder.zig");
pub const registerF = @import("register.zig");
pub const switching_circuitF = @import("switching_circuit.zig");
pub const src_handlerF = @import("src_handler.zig");

test {
    std.testing.refAllDecls(@This());
}
