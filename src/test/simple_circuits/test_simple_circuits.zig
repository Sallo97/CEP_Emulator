//! Global test file containing all tests for basic circuits.

const std = @import("std");
pub const test_adder_f = @import("test_adder.zig");
pub const test_register_f = @import("test_register.zig");

test {
    std.testing.refAllDecls(@This());
}
