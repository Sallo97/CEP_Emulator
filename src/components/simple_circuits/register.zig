const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const CepSizesT = @import("constants.zig").CepSizesT;

const RegisterError = error{InvalidName};

/// Defines a type of sequential circuit capable of keeping data of a certain size consistently.
/// - `Size`: the type used for the data. Usually is a unsigned numerical type.
///
/// Each entry has the following fields:
/// - `name`: the string identifying the instance. Usually it is a one caps letter, except for
///           the address registers `H0` and `H1`.
///
/// - `data`: the actual content of the instance.
pub fn Register(comptime SizeT: type) type {
    return struct {
        name: [2]u8 = undefined,
        data: SizeT = 0,

        /// Returns an entry with the content set to zero.
        /// - `name` : the string identifying the instance. It must be two character long,
        ///            otherwise an error is raised
        pub fn init(name: []u8) !@This() {
            if (name.len > 2) {
                return RegisterError.InvalidName;
            }
            const conv_name =
                if (name.len == 1) [2]u8{ name[0], ' ' } else [2]u8{ name[0], name[1] };

            return .{ .name = conv_name };
        }

        /// Zeroes the content of the entry.
        pub fn clear(self: *@This()) void {
            self.data = 0;
        }

        pub fn format(self: @This(), writer: *std.io.Writer) !void {
            try writer.print("[{s}]-", .{self.name});
            try writer.flush();

            try writer.print(": {b}", .{self.data});
            try writer.flush();
        }
    };
}

test "register_initialization" {
    // Try to create a one-letter named register
    const word_reg = try Register(CepSizesT.WorldT).init(@constCast("A"));
    try expectEqual(0, word_reg.data);
    try expectEqual([2]u8{ 'A', ' ' }, word_reg.name);

    // Try to create a two-letter named register
    const addr_reg = try Register(CepSizesT.AddressT).init(@constCast("H0"));
    try expectEqual(0, addr_reg.data);
    try expectEqual([2]u8{ 'H', '0' }, addr_reg.name);

    // Try to create a register whose name is greater than two
    try expectError(RegisterError.InvalidName, Register(CepSizesT.FlagT).init(@constCast("ERROR!")));
}

test "register_set_data" {
    // Try to set to a register of one bit value "1" (i.e. within its range).
    var dummy_reg = try Register(CepSizesT.FlagT).init(@constCast("F"));
    dummy_reg.data = 1;
    try expectEqual(1, dummy_reg.data);
}

test "register_clear" {
    // Try to clear a register and check that the value became zero.
    var dummy_reg = try Register(CepSizesT.MicroOpT).init(@constCast("O"));
    dummy_reg.data = 23;
    dummy_reg.clear();
    try expectEqual(0, dummy_reg.data);
}
