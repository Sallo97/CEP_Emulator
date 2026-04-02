//! This file declares the definitions that can be seen externally by modules referencing this.

const std = @import("std");

pub const Register = @import("register.zig").Register;
pub const ParallelAdder = @import("adder.zig").ParallelAdder;
pub const SwitchCircuit = @import("switching_circuit").SwitchCircuit;
