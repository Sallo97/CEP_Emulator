//! Contains the tests

const std = @import("std");

pub const selectionLineF = @import("selection_line.zig");
pub const switchCircuitF = @import("switch_circuit.zig");

test {
    std.testing.refAllDecls(@This());
}
