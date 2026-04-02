//! Contains all the tests of the module

const std = @import("std");

// They must be public to test them through `std.testing.refAllDecls(@This());`
// but should be not touched outside this file.
pub const _constantsF = @import("constants.zig");
pub const _maskUtilsF = @import("mask_utils.zig");
pub const _deviceF = @import("device.zig");

test {
    std.testing.refAllDecls(@This());
}
