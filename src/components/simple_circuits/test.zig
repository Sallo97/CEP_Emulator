//! Calls the tests for the module

const std = @import("std");

// They must be public to test them through `std.testing.refAllDecls(@This());`
// but should be not touched outside this file.
pub const _adderF = @import("adder.zig");
pub const _registerF = @import("register.zig");

test {
    std.testing.refAllDecls(@This());
}
