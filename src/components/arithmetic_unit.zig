//! This file defines the Arithmetic Unit, i.e. the component in the CEP responsible
//! for executing all arithmetic computations.
//! It supports both fixed point and floating point arithmetics.
//! Its main components are:
//! - Registers $A$ and $B$, which work as **accumulators**.
//! - Register $C$, which could stores the **memory address of the current operand**, or generic **auxiliary data**.
//! - The **adder** $AD$.
//! - Switching circuits $KU, KA, KB, KC, KV$.
//!
//! ⚠︎⚠︎ Although they are not part of the arithmetic unit logic, physically are also placed:
//! - Register $Z$, used for **retrieving data from memory**
//! - The associated switching circuit $KZ$.

const std = @import("std");
const Register = @import("basic/register.zig").Register;
const register_t = @import("basic/register.zig").register_t;
const Adder = @import("basic/adder.zig").Adder;
const SwitchingCircuit = @import("basic/switching_circuit.zig").SwitchingCircuit;

/// The Arithmetic Unit has the following components:
/// - Registers `A` and `B`, which work as accumulators.
/// - Register `C`, which is used both for storing the memory address of the current operand, or to keep generic auxiliary data.
/// - The Adder `AD`
/// - The Switching Circuits `KU`, `KA, `KB`, `KC,` `KV`.
///
/// Additionally, altough they are not part of the Arithmetic Unic logically, physically are also present in it:
/// - Register `Z`, used for retrieving data from memory.
/// - The associated Switching Circuit `KZ`.
/// To remain consistent with the original architecture, these are kept here.
const ArithmeticUnit = struct {
    // ---------- REGISTERS -------------
    A: Register = .{
        .type = register_t.word,
        .name = 'A',
        .content = .{ .word = 0 },
    },
    B: Register = .{
        .type = register_t.word,
        .name = 'B',
        .content = .{ .word = 0 },
    },
    C: Register = .{
        .type = register_t.address,
        .name = 'C',
        .content = .{ .address = 0 },
    },

    // --------- ADDERS -----------------
    AD: Adder,

    // ---------- SWITCHING CIRCUITS -----------
    KU: SwitchingCircuit,
    KA: SwitchingCircuit,
    KB: SwitchingCircuit,
    KC: SwitchingCircuit,
    KV: SwitchingCircuit,

    // ---------- EXTERNAL COMPONENTS -------------
    Z: Register = .{
        .type = register_t.word,
        .name = 'Z',
        .content = .{ .word = 0 },
    },
    KZ: SwitchingCircuit,

    const name = "Arithmetic Unit";

    // ---------- METHODS -------------------------
    pub fn format(self: ArithmeticUnit, writer: *std.io.Writer) !void {
        try writer.print("----------{s}---------\n", .{self.name});
        self.A.format(writer);
        try writer.print("\t", .{});
        self.B.format(writer);
        try writer.print("\n", .{});
        self.C.format(writer);

        try writer.print("\n", .{});
        self.Z.format(writer);
    }
};
