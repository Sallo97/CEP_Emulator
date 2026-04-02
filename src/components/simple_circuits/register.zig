const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const CepSizesT = @import("utils").CepSizesT;
const Device = @import("utils").Device;

const RegisterError = error{ InvalidName, InputAlreadyAttached };

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
        input: Device(SizeT) = undefined,

        // Private fields
        _name: [2]u8 = undefined,
        _data: SizeT = 0,

        /// Returns an entry with the content set to zero and no input attached.
        /// - `name` : the string identifying the instance. It must be two character long,
        ///            otherwise an error is raised
        pub fn init(name: []u8) !@This() {
            if (name.len > 2) {
                return RegisterError.InvalidName;
            }
            const conv_name =
                if (name.len == 1) [2]u8{ name[0], ' ' } else [2]u8{ name[0], name[1] };

            return .{ ._name = conv_name };
        }

        /// Sets the register data to the value incoming
        /// from the input source.
        pub fn update(self: *@This()) void {
            self._data = self.input.getData();
        }

        /// Converts the instance as a generic device.
        /// It is used when the instance is passed as
        /// input or output to another device.
        pub fn asDevice(self: *@This()) Device(SizeT) {
            return Device(SizeT){
                ._name = &self._name,
                ._data = &self._data,
            };
        }

        pub fn format(self: @This(), writer: *std.io.Writer) !void {
            defer writer.flush();
            try writer.print("[{s}]-", .{self._name});
            try writer.print(": data = {b}\tinput_device = ", .{self._data});
            self.input.format(writer);
        }
    };
}

test "init" {
    // Try to create a one-letter named register
    const word_reg = try Register(CepSizesT.WorldT).init(@constCast("A"));
    try expectEqual(0, word_reg._data);
    try expectEqual([2]u8{ 'A', ' ' }, word_reg._name);

    // Try to create a two-letter named register
    const addr_reg = try Register(CepSizesT.AddressT).init(@constCast("H0"));
    try expectEqual(0, addr_reg._data);
    try expectEqual([2]u8{ 'H', '0' }, addr_reg._name);

    // Try to create a register whose name is greater than two
    try expectError(RegisterError.InvalidName, Register(CepSizesT.FlagT).init(@constCast("ERROR!")));
}

test "update" {
    // Create a Register instance, having as starting state:
    // dummy_reg = ("A", 0b0000)
    var dummy_reg = Register(u4).init(@constCast("A")) catch unreachable;
    expectEqual(0b0000, dummy_reg._data) catch unreachable;

    // attach it to a dummy device having the following state:
    // dummy_dev = ("FS", 0b0010)
    const dummy_dev = Device(u4).init(
        @constCast(&[2]u8{ 'F', 'S' }),
        @constCast(&@as(u4, 0b0010)),
    );
    dummy_reg.input = dummy_dev;

    // Update the content of the register, the new state should be:
    // dummy_reg = ("A", 0b0010)
    dummy_reg.update();
    expectEqual(0b0010, dummy_reg._data) catch unreachable;
}

test "asDevice" {
    var reg = Register(u4).init(@constCast("P")) catch unreachable;
    const device = reg.asDevice();
    expectEqual(0, device.getData()) catch unreachable;

    reg._data = 2;
    expectEqual(2, device.getData()) catch unreachable;
}
