//! This file defines the Address Unit, i.e. the component responsible for
//! manage data transfers between the various memories in the computer.

const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const Register = @import("simple_circuits/register.zig").Register;
const ParallelAdder = @import("simple_circuits/adder.zig").ParallelAdder;
const MainMemory = @import("main_memory.zig").MainMemory;
const ArithmeticUnit = @import("arithmetic_unit.zig").ArithmeticUnit;

/// Depending on the type of the instruction, its operand address will be computed differently:
/// - NormalT:  the modification is computed by applying two modifications
///             depending on both the first parametric cells `P` and
///             second parametric cell `Q`.
///             The final address of the operation is `c = s + q + p`.
/// - SpecialT: the modification only uses the second parametric cell `Q`.
///             The final address of the operation is `c = s + q`.
///             The parametric cell `P` is used in different ways depending on the instruction.
const InstructionT = enum {
    NormalT,
    SpecialT,
};

/// Specifies the parametric cell we are referring to
const ParametricCellT = enum { P, Q };

/// A circuit specialized in managing transfers of data between the various memories
/// of the computer.
/// It both understands the component referred by an address (e.g. register, main memory,
/// auxiliary memory, etc...) and to transfer content from/to it.
///
/// Its main components are:
/// - Register `H0`: stores the base address of the fist parametric group.
/// - Register `H1`: stores the base address of the second parametric group.
/// - Register `R`: stores the relative address of the two parametric cells in reserved memory.
/// - Register `N`: works as the program counter, i.e. it stores the address of the current instruction.
/// - Adder `AJ`.
const AddressUnit = struct {
    const name = "Address Unit";

    h0_reg: Register = Register.init(@constCast("H0"), Register.RegisterT.address_t),
    h1_reg: Register = Register.init(@constCast("H1"), Register.RegisterT.address_t),
    r_reg: Register = Register.init(@constCast("R"), Register.RegisterT.address_t),
    n_reg: Register = Register.init(@constCast("N"), Register.RegisterT.address_t),

    aj_add: ParallelAdder = ParallelAdder.init("AJ"),

    /// Calculates the operand address of the current instruction, depending on
    /// the instruction type and the state of the registers.
    /// Note that `R` should be updated by the Control Unit before calling
    /// this function.
    /// - `instr_t`: a value indicating if the instruction is normal or special.
    /// - `start_addr`: the address retrieved directly from the instruction.
    pub fn computeOperandAddr(self: *@This(), instr_t: InstructionT, main_mem: *MainMemory, raw_addr: u15) u15 {
        // The process changes depending on the instruction type:
        // `normal instruction` -> the operand address is obtained by summing the
        //                         raw address in the instruction with the
        //                         content in the parametric cells `P` and `Q`.
        // `special instruction` -> the operand address is calculated by summing
        //                          the raw address with only parametric cell
        //                          `Q`.
        // Note that, as the CEP's manual states: the order of the sum doesn't matter.
        // For this reason we always start by doing the common part, i.e. raw_addr + Q.
        const q_content: u36 = q_block: {
            const q_addr = self.computeAbsParamAddr(ParametricCellT.Q);
            main_mem.readMemory(q_addr) catch unreachable;
            break :q_block main_mem.reg_z_ref.convertAndGetData();
        };
        self.aj_add.setOperands(raw_addr, q_content);
        const tmp_add_result = self.aj_add.performSum();

        const operand_addr = switch (instr_t) {
            .SpecialT => special_blk: {
                break :special_blk tmp_add_result.summed_number;
            },

            .NormalT => normal_blk: {
                const p_content: u36 = p_block: {
                    const p_addr = self.computeAbsParamAddr(ParametricCellT.P);
                    main_mem.readMemory(p_addr) catch unreachable;
                    break :p_block main_mem.reg_z_ref.convertAndGetData();
                };
                self.aj_add.setOperands(tmp_add_result.summed_number, p_content);
                const final_add_result = self.aj_add.performSum();
                break :normal_blk final_add_result.summed_number;
            },
        };
        return @truncate(operand_addr);
    }

    /// Retrieves the absolute address of the requested parametric cell.
    /// - `param_cell`: specifies if we want the address of either the
    ///                 first parametric cell (`P`) or the second (`Q`).
    fn computeAbsParamAddr(self: *@This(), param_cell: ParametricCellT) u15 {
        // The relative address of both `P` and `Q` are stored
        // in the `R` register.
        // The structure of `R` is the following:
        // | 0 0 0  | P relative address | Q relative address |
        // | 3-bits | 6-bits             | 6-bits             |
        const r_content: u15 = @truncate(self.r_reg.convertAndGetData());
        const relative_addr = switch (param_cell) {
            ParametricCellT.P => p_block: {
                const p_mask: u15 = 0b000_111111_000000;
                const p_relative_addr: u6 = @truncate((p_mask & r_content) >> 6);
                break :p_block p_relative_addr;
            },
            ParametricCellT.Q => q_block: {
                const q_mask: u15 = 0b000_000000_111111;
                const q_relative_addr: u6 = @truncate(q_mask & r_content);
                break :q_block q_relative_addr;
            },
        };

        // Gets the absolute address by adding it to the base address of the
        // associated parametric group. Recall that the most significant bit
        // msb of a relative parametric address determines the parametric group:
        // - if msb = 0 -> the first parametric group H0
        // - if msb = 1 -> the second parametric group H1
        const group_bit: u1 = @truncate(relative_addr >> 5);
        const relative_index: u5 = @truncate(relative_addr);
        const abs_addr: u36 = switch (group_bit) {
            0 => h0_block: {
                const h0_base_addr = self.h0_reg.convertAndGetData();
                self.aj_add.setOperands(h0_base_addr, @as(u36, relative_index));
                const h0_abs_addr = self.aj_add.performSum();
                break :h0_block h0_abs_addr.summed_number;
            },
            1 => h1_block: {
                const h1_base_addr = self.h1_reg.convertAndGetData();
                self.aj_add.setOperands(h1_base_addr, @as(u36, relative_index));
                const h1_abs_addr = self.aj_add.performSum();
                break :h1_block h1_abs_addr.summed_number;
            },
        };
        return @truncate(abs_addr);
    }

    /// Sets all registers of the instance to zero.
    pub fn clearAllRegisters(self: *@This()) void {
        try self.h0_reg.clearData();
        try self.h1_reg.clearData();
        try self.n_reg.clearData();
        try self.r_reg.clearData();

        self.aj_add.clearAdder();
    }

    pub fn format(self: @This(), writer: *std.io.Writer) !void {
        const component_prefix = "\n-";
        try writer.print("[{s}]", .{AddressUnit.name});
        try writer.print("{s}", .{component_prefix});
        try writer.print("{s}", .{component_prefix});
        try self.h0_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.h1_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.r_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.n_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.aj_add.format(writer);
    }
};

//----------------------------------------------------- TESTS ------------------------------------------------------

test "computeAbsParamAddr" {
    // Initialize the Address Unit setting the registers as follows:
    // - H0 = 000_000_111_000_000
    // - H1 = 000_111_000_000_000
    // - R = | 000 | 0_00010 | 1_00100 |
    //       |dummy| p_idx   | q_idx   |
    var dummy_address_unit = AddressUnit{};
    dummy_address_unit.h0_reg.checkAndSetData(0b000_000_111_000_000) catch unreachable;
    dummy_address_unit.h1_reg.checkAndSetData(0b000_111_000_000_000) catch unreachable;
    dummy_address_unit.r_reg.checkAndSetData(0b000_0_00010_1_00100) catch unreachable;

    const p_addr = dummy_address_unit.computeAbsParamAddr(ParametricCellT.P);
    try expectEqual(0b000_000_111_000_000 + 0b00010, p_addr);

    const q_addr = dummy_address_unit.computeAbsParamAddr(ParametricCellT.Q);
    try expectEqual(0b000_111_000_000_000 + 0b00100, q_addr);
}

test "computeOperandAddr" {

    // Initialize the Address Unit setting the registers as follows:
    // - H0 = 000_000_111_000_000
    // - H1 = 000_111_000_000_000
    // - R = | 000 | 0_00010 | 1_00100 |
    //       |dummy| p_idx   | q_idx   |
    var dummy_address_unit = AddressUnit{};
    dummy_address_unit.h0_reg.checkAndSetData(0b000_000_111_000_000) catch unreachable;
    dummy_address_unit.h1_reg.checkAndSetData(0b000_111_000_000_000) catch unreachable;
    dummy_address_unit.r_reg.checkAndSetData(0b000_0_00010_1_00100) catch unreachable;

    const p_addr = dummy_address_unit.computeAbsParamAddr(ParametricCellT.P);
    const q_addr = dummy_address_unit.computeAbsParamAddr(ParametricCellT.Q);

    // Store in entries `P` and `Q` 2 and 4 respectively.
    var dummy_z_reg = Register.init(@constCast("Z"), Register.RegisterT.word_t);
    var dummy_main_mem: MainMemory = try MainMemory.init(std.testing.allocator, &dummy_z_reg);
    defer dummy_main_mem.free(std.testing.allocator) catch unreachable;

    dummy_z_reg.checkAndSetData(2) catch unreachable;
    dummy_main_mem.writeData(p_addr) catch unreachable;

    dummy_z_reg.checkAndSetData(4) catch unreachable;
    dummy_main_mem.writeData(q_addr) catch unreachable;

    dummy_z_reg.clearData() catch unreachable;

    // Compute the operand address in the normal case, i.e.
    // result = raw_addr + q + p.
    const raw_addr = 0b000_000_000_000_000;
    const normal_addr = dummy_address_unit.computeOperandAddr(InstructionT.NormalT, &dummy_main_mem, raw_addr);
    try expectEqual(raw_addr + 2 + 4, normal_addr);

    // Compute the operand address in the special case, i.e.
    // result = raw_addr + q.
    const special_addr = dummy_address_unit.computeOperandAddr(InstructionT.SpecialT, &dummy_main_mem, raw_addr);
    try expectEqual(raw_addr + 4, special_addr);
}
