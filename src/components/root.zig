//! The root file for the module holding all the medium-level components.
//! It calls also all the tests.

const std = @import("std");
// pub const arithmetic_unit_f = @import("arithmetic_unit.zig");
// pub const address_unit_f = @import("address_unit.zig");
// pub const main_mem_f = @import("main_memory.zig");

test {
    std.testing.refAllDecls(@This());
}
