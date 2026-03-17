//! Defines various types of sequential circuits, i.e. components capable of holding data over time.
//! Each class of registers distinguish themself by the size they can store, which
//! usually maps to different usanges within the computer's architecture.

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

/// A sequential circuit capable of keeping data of a certain size consistently.
/// - `name`: the character identifying the instance.
/// - `data`: the actual content of the instance. Its sizes depends on the usage of the instance.
/// It is adviced to construct an instance through the `init` method.
pub const Register = struct {
    /// Defines the possible errors that can happen when using a Register instance.
    /// - OutOfRange: occurs when it is requested to store a value in an istance, whose size exceeds its width.
    pub const RegisterError = error{
        OutOfRange,
    };

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
                .address_t => "Address Register",
                .word_t => "World Register",
                .flag_t => "Flag Register",
                .parametric_t => "Parametric Register",
                .micro_operation_t => "Micro-Operation Register",
            };
            try writer.print("{s}[{d}-bit(s)]", .{ name_type, @intFromEnum(self) });
            try writer.flush();
        }
    };

    // The data in managed internally as a tagged union to
    // better show the connection between register type and
    // its size.
    const DataT = union(RegisterT) {
        flag_t: u1,
        parametric_t: u6,
        micro_operation_t: u8,
        address_t: u15,
        word_t: u36,

        /// Returns the register type associated to the active field.
        pub fn get_type(self: @This()) RegisterT {
            const data_type: RegisterT = switch (self) {
                RegisterT.flag_t => comptime RegisterT.flag_t,
                RegisterT.parametric_t => comptime RegisterT.parametric_t,
                RegisterT.micro_operation_t => comptime RegisterT.micro_operation_t,
                RegisterT.address_t => comptime RegisterT.address_t,
                RegisterT.word_t => comptime RegisterT.word_t,
            };
            return data_type;
        }
    };
    name: u8,
    data: DataT,

    /// Returns an initialized Register circuit, whose data
    /// (which integer type is determined by the register type) is set to zero.
    /// It is adviced to call this function when one wants to construct an instance.
    /// - `name`: the character identifying the instance.
    /// -`type`: it describes the use-case of the instance.
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
            .data = data,
        };
        return register;
    }

    /// Returns the content of the register as a 36-bit unsigned integer.
    /// It is adviced to use this function instead of retrieving the field directly.
    /// Users are adviced to retrieve data from an instance using this method instead of manually.
    pub fn convertAndGetData(self: @This()) u36 {
        const data: u36 = switch (self.data) {
            RegisterT.flag_t => |raw_value| raw_value,
            RegisterT.parametric_t => |raw_value| raw_value,
            RegisterT.micro_operation_t => |raw_value| raw_value,
            RegisterT.address_t => |raw_value| raw_value,
            RegisterT.word_t => |raw_value| raw_value,
        };
        return data;
    }

    /// Returns the minimum number of bits necessary for representing the passed unsigned integer.
    /// - `num`: the unsigned integer.
    fn minBitRequired(num: usize) usize {
        if (num == 0 or num == 1) return 1;

        var bit_digits_found: usize = 0;
        var num_left = num;
        while (num_left > 0) {
            bit_digits_found += 1;
            num_left = num_left >> 1;
        }
        return bit_digits_found;
    }

    /// Puts the new value in the register, if the minimum number of bit digits required for representing it
    /// is within the instance's data size. If not the function doesn't update the instance, instead launching
    /// the excepction `RegisterError`.
    /// Users are adviced to set data for an instance using this method instead of manually.
    /// - `new_val`: the new candidate content for the update.
    pub fn checkAndSetData(self: *@This(), new_val: u36) RegisterError!void {
        // Check if it is possible to store the requested value into the instance's limits.
        const min_val_size = Register.minBitRequired(new_val);
        const max_register_size = @intFromEnum(self.data);

        if (min_val_size > max_register_size) {
            return RegisterError.OutOfRange;
        }

        switch (self.data) {
            RegisterT.flag_t => |*raw_data| raw_data.* = @intCast(new_val),
            RegisterT.parametric_t => |*raw_data| raw_data.* = @intCast(new_val),
            RegisterT.micro_operation_t => |*raw_data| raw_data.* = @intCast(new_val),
            RegisterT.address_t => |*raw_data| raw_data.* = @intCast(new_val),
            RegisterT.word_t => |*raw_data| raw_data.* = @intCast(new_val),
        }
    }

    /// Zeroes the instance's content.
    pub fn clearData(self: *@This()) !void {
        self.checkAndSetData(0) catch undefined;
    }

    pub fn format(self: @This(), writer: *std.io.Writer) !void {
        const data_type: RegisterT = self.data.get_type();
        try writer.print("[{c}]-", .{self.name});
        try writer.flush();

        try data_type.format(writer);

        const data_value = self.convertAndGetData();
        try writer.print(": {b}", .{data_value});
        try writer.flush();
    }
};

//---------------------------------------------- TESTS --------------------------------------------------------------------

// Defines a writer to the standard error, which is used for testing the `format` function.
var stderr_buffer: [1024]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
const stderr = &stderr_writer.interface;

test "register_initialization" {
    var dummy_register: Register = Register.init('F', Register.RegisterT.flag_t);
    // try dummy_register.format(stderr);
    // try stderr.print("\n", .{});
    // try stderr.flush();

    try expectEqual(0, dummy_register.convertAndGetData());
}

test "register_set_value" {
    var dummy_register: Register = Register.init('F', Register.RegisterT.flag_t);
    try dummy_register.checkAndSetData(1);
    // try dummy_register.format(stderr);
    // try stderr.print("\n", .{});
    // try stderr.flush();

    try expectEqual(1, dummy_register.convertAndGetData());

    // Trying to store a value greater than the register's size.
    try std.testing.expectError(Register.RegisterError.OutOfRange, dummy_register.checkAndSetData(36));
    //try std.testing.expectError(RegisterError.OutOfRange, error_got);

    // Re-declaring the register with a diffent type.
    dummy_register = Register.init('A', Register.RegisterT.address_t);
    // try dummy_register.format(stderr);
    // try stderr.print("\n", .{});
    // try stderr.flush();

    // Setting the previous value we tried, as now we have enough space for it.
    try dummy_register.checkAndSetData(36);
    // try dummy_register.format(stderr);
    // try stderr.print("\n", .{});
    // try stderr.flush();

    try expectEqual(36, dummy_register.convertAndGetData());
}

test "register_clearing" {
    var dummy_register: Register = Register.init('F', Register.RegisterT.flag_t);

    try dummy_register.clearData();
    // try dummy_register.format(stderr);
    // try stderr.print("\n", .{});
    // try stderr.flush();

    try expectEqual(0, dummy_register.convertAndGetData());
}

test "min_bit_size" {
    try expectEqual(1, Register.minBitRequired(0));
    try expectEqual(1, Register.minBitRequired(1));
    try expectEqual(6, Register.minBitRequired(32));
    try expectEqual(9, Register.minBitRequired(257));
}
