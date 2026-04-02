//! This file declares the definitions that can be seen externally by modules referencing this.

const std = @import("std");

pub const SwitchCircuit = @import("switch_circuit.zig").SwitchCircuit;

test {
    std.testing.refAllDecls(@This());
}
