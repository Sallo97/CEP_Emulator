//! Defines various types of sequential circuits, i.e. components capable of holding data over time.
//! Each class of registers distinguish themself by the size they can store, which
//! usually maps to different usanges within the computer's architecture.

const std = @import("std");

/// Defines the possible types of registers available.
/// Each class is associated to a specific usage (described shortly after)
/// and a specific data size (in bits).
///
/// The available members are:
/// - Address registers:  15-bit registers used to hold a memory address.
/// - World registers: 36-bit registers used to hold a memory word. These registers are mainly used for arithmetic operations and keeping data.
/// - Flag registers: 1-bit registers used to keep track of useful properties detectable after an operation occurred (e.g. the overflow in an arithmetic operation).
/// - Parametric registers: 6-bit registers used for keeping a relative address to a parametric cell (i.e. its index and parametric group).
/// - Micro-operation register: a 8-bit register used to keep micro-operation code currently executed.
/// Note that each entry has associated as its value the width of the data they can store.
pub const RegisterT = enum(u8) {
    flag_t = 1,
    parametric_t = 6,
    micro_operation_t = 8,
    address_t = 15,
    word_t = 36,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        const name_type = switch (self) {
            RegisterT.address_t => "Address Register",
            RegisterT.word_t => "World Register",
            RegisterT.flag_t => "Flag Register",
            RegisterT.parametric_t => "Parametric Register",
            RegisterT.micro_operation_t => "Micro-Operation Register",
        };
        writer.print("{s}[{d}-bit(s)]", .{ name_type, @intFromEnum(self) });
    }
};

/// A sequential circuit capable of keeping data of a certain size consistently.
/// - `name`: the character identifying the instance.
/// - `type`: it determines the purpose of the register within the computer architecture.
/// - `data`: the actual content, represented as an integer number whose size is determined by the type of register instantieted.
pub const Register = struct {
    // The data in managed internally as a tagged union to
    // better show the connection between register type and
    // its size.
    const DataT = union(RegisterT) {
        flag_t: u1,
        parametric_t: u6,
        micro_operation_t: u8,
        address_t: u15,
        word_t: u36,
    };
    name: u8 = undefined,
    type: RegisterT = undefined,
    data: DataT,

    /// Returns an initialized Register circuit, whose data
    /// (which integer type is determined by the register type) is set to zero.
    /// It is adviced to call this function when one wants to construct an instance.
    /// - `name`: the character identifying the instance.
    /// - `type`: it describes the use-case of the instance.
    pub fn init(name: u8, reg_type: RegisterT) @This() {
        const data: DataT = switch (reg_type) {
            RegisterT.flag_t => DataT{ .flag_t = 0 },
            RegisterT.parametric_t => DataT{ .parametric_t = 0 },
            RegisterT.micro_operation_t => DataT{ .micro_operation_t = 0 },
            RegisterT.address_t => DataT{ .address_t = 0 },
            RegisterT.word_t => DataT{ .word_t = 0 },
        };

        const register: Register = Register{
            .name = name,
            .type = reg_type,
            .data = data,
        };
        return register;
    }

    /// Put the passed value as the new content, only if its size is within the instance type.
    /// - `new_val`: the new number being copied into.
    pub fn set_data(self: *@This(), new_val: u36) !void {

        // The switch on the tagged union forces to check that the new value
        // can be converted into the data's size limits without any loss of information.
        switch (self.type) {
            RegisterT.flag_t => |*value| value.* = @truncate(new_val),
            RegisterT.parametric_t => |*value| value.* = @truncate(new_val),
            RegisterT.micro_operation_t => |*value| value.* = @truncate(new_val),
            RegisterT.address_t => |*value| value.* = @truncate(new_val),
            RegisterT.word_t => |*value| value.* = @truncate(new_val),
        }
    }

    pub fn format(self: Register, writer: *std.io.Writer) !void {
        const reg_description: []u8 = RegisterT.string_from_type(self.type);
        try writer.print("|{s}|({s}) = {d}\t{b}", .{ self.name, reg_description, self.data, self.data });
    }

    /// Updates the instance by setting its content to zero.
    pub fn clear_data(self: Register) void {
        self.data = 0;
    }
};
