//! The root file for the module holding all the basic circuits components.
//! It calls also all the tests.

const std = @import("std");
pub const adder_f = @import("adder.zig");
pub const register_f = @import("register.zig");

test {
    std.testing.refAllDecls(@This());
}
