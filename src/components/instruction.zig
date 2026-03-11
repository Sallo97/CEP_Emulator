//! This file defines the types and functions to work with instructions.
const std = @import("std");

/// A parametric address is a pointer to a parametric cell in main memory.
/// Its structure is the following:
/// | group_bit | relative_addr |
/// |   1-bit   |     5-bits    |
/// |          6-bits           |
const ParametricAddress = struct {
    // Identifies the parametric group referred by `relative_addr`:
    // - if group_bit = 0 -> first parametric group {H_0}
    // - if group_bit = 1 -> second parametric group {H_1}
    group_bit: u1,

    // The relative address (i.e. the index) of the cell in the parametric group.
    // `is_snd` is a boolean flag which determines if the current parametric address refers
    // to the first address of the instruction or the second. By default is set to false.
    relative_addr: u5,

    pub fn format(self: ParametricAddress, writer: *std.io.Writer, is_snd: false) !void {
        if (!is_snd) {
            try writer.print("--------FIRST PARAMETRIC ADDRESS--------\n", .{});
        } else {
            try writer.print("--------SECOND PARAMETRIC ADDRESS--------\n", .{});
        }

        try writer.print("| group_bit | relative_addr |\n", .{});
        try writer.print("| {d}({b:.1})| {d}(b:.5) |\n", .{ self.group_bit, self.relative_addr });
        try writer.print("--------------------------------\n", .{});

        try writer.writeAll();
    }

    /// Returns the ParametricAddress instance retrived from a raw 6-bit binary parametric address.
    pub fn instance_from_raw(raw_param_address: u6) ParametricAddress {
        const group_bit_mask = 0b1_00000;
        const group_bit_val: u1 = (raw_param_address & group_bit_mask) >> 5;

        const relative_addr_mask = 0b0_11111;
        const relative_addr_val: u5 = raw_param_address & relative_addr_mask;

        const instance: ParametricAddress = .{ .group_bit = group_bit_val, .relative_addr = relative_addr_val };
        return instance;
    }

    /// Returns the raw 6-bit binary address from the given instance.
    pub fn raw_from_instance(self: ParametricAddress) u6 {
        const raw_group_bit: u6 = self.group_bit << 5;
        const raw_relative_addr: u6 = self.relative_addr;

        const raw_parametric_addr: u6 = raw_group_bit | raw_relative_addr;
        return raw_parametric_addr;
    }
};

/// An instruction is a 36-bit word sequence, which is broken down into subsequences of
/// bits, each referring to a specific information for the operation requested.
/// The structure is the following:
/// | pseudo_flag | auto_check_flag | opcode | fst_param_addr | snd_param_addr | address |
/// |   1-bit     |     1-bit       | 7-bits |     6-bits     |      6-bits    | 15-bits |
/// |                                 Total: 36-bits                                     |
const Instruction = struct {
    /// Instructions implementations are of two types, depending on how where their commands are "stored" in the machine:
    /// - microprogram = hardwired in the CPU.
    /// - pseudoinstructions = are realized by a subprogram in main memory.
    const InstructionImplT = enum { pseudoinstruction, microprogram };

    /// Instruction behavious can be categorized in two groups, each determining how the parametric cells
    /// are used by the operation:
    /// - normal = use the two parametric addresses for computing the final operand address.
    /// - special = use the first parametric address as a second operand; the second parametric
    ///             address is used for computing the final operand address.
    const InstructionBehaviourT = enum { normal, special };

    // Determines the class of the current instruction:
    // - pseudo_flag = 0 -> is a normal or special instruction, i.e. is implemented by the micro-program of the CPU.
    // - pseudo_flag = 1 -> is a pseudoinstruction, i.e. a subprogram in memory.
    pseudo_flag: u1 = 0,

    // When set to `1` it instrument the CEP to independently call a subroutine
    // which will check the correctness of the executed command.
    check_routine_flag: u1 = 0,

    // The sequence identifying the requested command.
    opcode: u7 = 0,

    // The first parametric address. Depending on the type of the instruction its usage varies:
    // - if its a normal instruction -> it is used for determining the final modified operand.
    // - if its a special instruction -> its parametric cell is used as the second operand of the instruction.
    fst_parametric_addr: ParametricAddress = 0,

    // The second parametric address. It is always used for determining the final modified operand.
    snd_parametric_addr: ParametricAddress = 0,

    // The base address of the operand used by the command.
    // It will be updated by the parametric addresses according to the type of the instruction.
    operand_address: u15 = 0,

    pub fn format(self: Instruction, writer: *std.io.Writer) !void {
        try writer.print("--------INSTRUCTION---------\n", .{});
        try writer.print("| pseudo_flag | check_routine_flag | opcode | operand_address |\n", .{});
        try writer.print("| {d}({b:.1}) | {d}({b:.1}) | {d}({b:.7}) | {d}({b:.15}) |\n", .{ self.pseudo_flag, self.check_routine_flag, self.opcode, self.operand_address });

        self.fst_parametric_addr.format(writer);
        self.snd_parametric_addr.format(writer, true);

        try writer.print("-------RAW INSTRUCTION SEQUENCE--------\n", .{});
        try writer.print("{b:.36}\n", .{self.raw_from_instance()});
        try writer.print("--------------------------------\n", .{});

        try writer.writeAll();
    }

    /// Returns an Instruction object referring to the termination instruction, i.e. the command
    /// specifying the CEP to end the current execution.
    pub fn get_termination_instruction() Instruction {
        const termination_instr: Instruction = .{};
        return termination_instr;
    }

    /// Returns the implementation type of the instruction object.
    pub fn get_instruction_implementation(self: Instruction) InstructionImplT {
        if (self.pseudo_flag) {
            return InstructionImplT.pseudoinstruction;
        } else {
            return InstructionImplT.microprogram;
        }
    }

    /// Constructs an Instruction object from a raw 36-bit sequence.
    pub fn instance_from_raw(raw_sequence: u36) Instruction {
        const pseudo_mask: u36 = 0b1_0_0000000_000000_000000_000000000000000;
        const pseudo_flag_val: u1 = (raw_sequence & pseudo_mask) >> 35;

        const check_routine_mask: u36 = 0b0_1_0000000_000000_000000_000000000000000;
        const check_routine_flag_val: u1 = (raw_sequence & check_routine_mask) >> 35;

        const opcode_mask: u36 = 0b0_0_1111111_000000_000000_000000000000000;
        const opcode_val: u7 = (raw_sequence & opcode_mask) >> 27;

        // const fst_parametric_mask = 0b0_0_0000000_111111_000000_000000000000000;
        const fst_raw_parametric_addr: u6 = raw_sequence >> 21;
        const fst_parametric_val: ParametricAddress = ParametricAddress.instance_from_raw(fst_raw_parametric_addr);

        // const fst_parametric_mask = 0b0_0_0000000_000000_111111_000000000000000;
        const snd_raw_parametric_addr: u6 = raw_sequence >> 15;
        const snd_parametric_val: ParametricAddress = ParametricAddress.instance_from_raw(snd_raw_parametric_addr);

        const operand_val: u15 = raw_sequence;

        const instruction_instance: Instruction = .{ .pseudo_flag = pseudo_flag_val, .check_routine_flag = check_routine_flag_val, .opcode = opcode_val, .fst_parametric_addr = fst_parametric_val, .snd_parametric_addr = snd_parametric_val, .operand_address = operand_val };
        return instruction_instance;
    }

    /// Returns the raw 36-bit sequence of the Instruction object.
    pub fn raw_from_instance(self: Instruction) u36 {
        const raw_pseudo_flag: u36 = self.pseudo_flag << 35;
        const raw_check_routine_flag: u36 = self.check_routine_flag << 34;
        const raw_opcode: u36 = self.opcode << 27;
        const raw_fst_parametric_addr: u36 = ParametricAddress.raw_from_instance(self.fst_parametric_addr) << 21;
        const raw_snd_parametric_addr: u36 = ParametricAddress.raw_from_instance(self.snd_parametric_addr) << 15;
        const raw_operand_address: u36 = self.operand_address;

        const raw_instruction = raw_pseudo_flag | raw_check_routine_flag |
            raw_opcode | raw_fst_parametric_addr |
            raw_snd_parametric_addr | raw_operand_address;
        return raw_instruction;
    }
};
