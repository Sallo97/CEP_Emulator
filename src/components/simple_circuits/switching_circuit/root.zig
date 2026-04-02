//! The root file for the module holding all the files helping define a switching circuit.
//! It calls also all the tests.

const std = @import("std");
// pub const selectionLineF = @import("selection_line.zig");
pub const switchCircuitF = @import("switch_circuit.zig");
// pub const switchingCircuitF = @import("switching_circuit.zig");

test {
    std.testing.refAllDecls(@This());
}
