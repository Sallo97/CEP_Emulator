//! This file declares all possible types of registers.
//! Registers are distinguished mainly by their size (i.e. number of bits).
//! Usually, different sizes means different usages.

const std = @import("std");

// ---------------------------------- REGISTER TYPES DEFINITIONS ----------------------------------------------------

/// Defines the usage of the register.
/// This is tied also to the size.
pub const register_t = enum {
    /// Address registers are 15-bits registers, large enough to hold a memory address.
    /// These registers are used to keep useful memory location used during the current execution
    /// of the program.
    address,

    /// Word registers are 36-bits registers, large enough to keep an entire memory word.
    /// These registers are used for applying arithmetic operations or keeping data
    word,

    /// Flag registers are 1-bit registers, used for checking useful properties
    /// after an operation (e.g. the overflow after an arithmetic operation).
    flag,

    /// Parametric registers are 6-bit registers used for keeping the relative addresses of the
    /// current instruction.
    parametric,

    /// The O micro-operation register is a 8-bit register used to keep the address of the
    /// operation-code of the current micro-instruction being executed.
    micro_operation,

    // ---------------------------------- REGISTER SIZES CONSTANTS -----------------------------------
    const address_reg_size = u15;

    const word_reg_size = u36;

    const flag_reg_size = u1;

    const param_reg_size = u6;

    const micro_op_reg_size = u8;

    // ----------------------------------- METHODS -----------------------------------------------------

    /// Returns the type of the content of the register type.
    pub fn size_from_type(self: register_t) address_reg_size!word_reg_size!flag_reg_size!param_reg_size!micro_op_reg_size {
        const result: address_reg_size!word_reg_size!flag_reg_size!param_reg_size!micro_op_reg_size =
            switch (self) {
                register_t.address => address_reg_size,
                register_t.word => word_reg_size,
                register_t.flag => flag_reg_size,
                register_t.parametric => param_reg_size,
                register_t.micro_operation => micro_op_reg_size,
            };

        return result;
    }

    /// Returns a description of the type, specifying its usage and size.
    pub fn string_from_type(self: register_t) []u8 {
        const result: []u8 = switch (self) {
            register_t.address => "Address Register (15-bits)",
            register_t.word => "World Register (8-bits)",
            register_t.flag => "Flag Register (1-bit)",
            register_t.parametric => "Parametric Register (6-bits)",
            register_t.micro_operation => "Micro-Operation Register (8-bits)",
        };
        return result;
    }
};
// ---------------------------------------------------------------------------------------------------------------------

/// A register is a low-level component able to hold static data during execution.
/// The size of the data which is able to store depends on the type of the register.
/// Registers are distinguished by their name, which is typically a single UTF-8 letter.
pub const Register = struct {
    content: union(register_t) {
        address: register_t.address_reg_size,
        word: register_t.word_reg_size,
        flag: register_t.flag_reg_size,
        param: register_t.param_reg_size,
        micro_op: register_t.micro_op_reg_size,
    } = 0,
    type: register_t = undefined,
    name: u8 = undefined,

    // ------------------------ METHODS ------------------------------------------------------
    /// Prints to `writer` all informations about the register.
    pub fn format(self: Register, writer: *std.io.Writer) !void {
        const reg_description: []u8 = register_t.string_from_type(self.type);
        try writer.print("|{s}|({s}) = {d}\t{b}", .{ self.name, reg_description, self.content, self.content });
    }

    /// Zeros the register content
    pub fn zero_register(self: Register) void {
        self.content = 0;
    }
}; // --------------------------------------------------------------------------------------------------------------------
