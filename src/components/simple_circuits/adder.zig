//! Defines various types of circuits capable of performing
//! additon between numbers.
//! Each class of adders distinguish itself by the fixed-length of
//! number supported and their capability of detecting an overflow after the execution
//! of a sum.

const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;

const CepSizesT = @import("utils").CepSizesT;
const Device = @import("utils").Device;

const AdderError = error{InvalidName};

/// A circuit supporting the addition between two bits, handling the possible overflow.
/// - `fst_bit`: the first operand, representing a 1-bit unsigned number.
/// - `snd_bit`: the second operand, representing a 1-bit unsigned number.
/// - `carry_in`: an additional bit considered during the operation.
///               This extra bit comes from an external source, e.g. the previous member of a parallel adder.
/// By default all the values are set to zero.
pub const FullAdder = struct {
    fst_bit: u1 = 0,
    snd_bit: u1 = 0,
    carry_in: u1 = 0,

    /// Contains the outcome of an addition done by a FullAdder.
    /// - `sum_bit`: the sum's result represented as a 1-bit unsigned integer.
    /// - `carry_out`: the overflow bit produced by the operation, being set to one when the result exceeds the 1-bit length.
    const FullAdderResult = struct {
        sum_bit: u1,
        carry_out: u1,

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) !void {
            try writer.print("sum_bit = {b}\tcarry_output = {b}", .{ self.sum_bit, self.carry_out });
        }
    };

    /// Returns the outcome of the sum between the bits currently hold by the circuit.
    pub fn performSum(self: @This()) FullAdderResult {
        const sum: u2 = @as(u2, self.fst_bit) + @as(u2, self.snd_bit) + @as(u2, self.carry_in);
        const adder_res: FullAdderResult = .{
            .sum_bit = @truncate(sum),
            .carry_out = @truncate(sum >> 1),
        };
        return adder_res;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("fst_bit = {b}\tsnd_bit = {b}\tcarry_in = {b}", .{ self.fst_bit, self.snd_bit, self.carry_in });
    }

    /// This function is used to construct simple equality checks for a full adder.
    /// It construct a dummy full adder, setting its value according to the passed
    /// arguments. Finally, it applies the sum and returns the boolean obtained by
    /// checking if the results match the expected ones.
    /// - `fst_operand`: the 1-bit value of the first operand.
    /// - `snd_operand`: the 1-bit value of the second operand.
    /// - `carry_in`: the 1-bit value of the input overflow value.
    /// - `exp_sum`: the expected resulting 1-bit sum.
    /// - `exp_carry_out`: the expected 1-bit output overflow value.
    fn checkFullAdderSum(fst_operand: u1, snd_operand: u1, carry_in: u1, exp_sum: u1, exp_carry_out: u1) bool {
        const dummy_full_adder: FullAdder = .{
            .fst_bit = fst_operand,
            .snd_bit = snd_operand,
            .carry_in = carry_in,
        };
        const result = dummy_full_adder.performSum();
        const sum_eql: bool = result.sum_bit == exp_sum;
        const carry_out_eql: bool = result.carry_out == exp_carry_out;
        return sum_eql and carry_out_eql;
    }
};

/// A circuit supporting the addition between two numbers whose `size` is greater than one bit.
/// It handles possible overflows during the operation.
/// - `addr_array`: the set of contiguous full adders used to implement the operation.
///                        Each i-th full adder contains the i-th digits of the two 36-bit numbers.
///                        Each full adder is "attached" to its adjacent neighbors, to which it sends or receive carry information.
/// - `name`: its 2-letter string identifier. Usually a paraller adder
///           has the first letter always a 'A' and the second letter whatever.
/// - `sum`: the result of the last addition performed, kept as a `SizeT`.
/// - `carry_out`: the carry_out of the last addition performed.
pub fn ParallelAdder(comptime SizeT: type) type {
    return struct {
        const length = @typeInfo(SizeT).int.bits;

        inputs: [2]Device(SizeT) = undefined,

        // Private fields
        _addr_array: [length]FullAdder = undefined,
        _name: [2]u8 = undefined,
        _sum: SizeT = undefined,
        _carry_out: u1 = undefined,

        /// Returns an initialized Parallel Adder circuit with no input device attached.
        /// - `name` : the two letter identifier of the generated circuit. Usually a paraller adder
        ///            has the first letter always a 'A' and the second letter whatever.
        pub fn init(name: []u8) !@This() {
            // Check that the name is made up of two letters
            if (name.len != 2) {
                return AdderError.InvalidName;
            }
            const conv_name = [2]u8{ name[0], name[1] };

            var adder = @This(){
                ._name = conv_name,
                ._sum = 0,
                ._carry_out = 0,
            };
            for (0..length) |idx| {
                adder._addr_array[idx] = .{};
            }

            return adder;
        }

        /// Returns the outcome of the sum between the numbers coming from the attached inputs.
        pub fn performSum(self: *@This()) void {
            // Retrieves the content from the input devices and distributes them among
            // the parallel adders.
            const fst_op = self.inputs[0].getData();
            const snd_op = self.inputs[1].getData();
            for (0..length) |idx| {
                self._addr_array[idx].fst_bit = @truncate(fst_op >> @truncate(idx));
                self._addr_array[idx].snd_bit = @truncate(snd_op >> @truncate(idx));
            }

            var summed_number: SizeT = 0;
            var final_carry: u1 = undefined;

            // Sums each digits from less significant to most significant.
            // The resulting bit is stored in the correct i-th position of
            // `summed_number`; while the outputted `carry_out` is given as
            // input to the full adder to the left (i.e. the i+1-th).
            // The generated `carry_out` of the final full adder is
            // copied into `final_carry`.
            for (0..length) |idx| {
                const addr: FullAdder = self._addr_array[idx];
                const res = addr.performSum();

                summed_number = summed_number | (@as(SizeT, res.sum_bit) << @truncate(idx));
                if (idx != length - 1) {
                    self._addr_array[idx + 1].carry_in = res.carry_out;
                } else {
                    final_carry = res.carry_out;
                }
            }

            self._sum = summed_number;
            self._carry_out = final_carry;
        }

        /// Returns the adder abstracted as a generic device.
        pub fn asDevice(self: *@This()) Device(SizeT) {
            return Device(SizeT){
                ._data = &self._sum,
                ._name = &self._name,
            };
        }

        /// Returns if a parallel adder applies the requested addition correctly, i.e.
        /// it returns `expected_sum` and `expected_carry_out` after setting its first number to
        /// `fst_number` and its second number to `snd_number`.
        /// This function is used to construct simple equality checks for a parallel adder.
        /// It construct a dummy parallel adder, setting its value according to the passed
        /// arguments. Finally, it applies the sum and returns the booled obtained by checking
        /// if the results match the expected ones.
        /// - `fst_number`: the `SizeT` value of the first operand.
        /// - `snd_number`: the `SizeT` value of the second operand.
        /// - `exp_sum`: the expected resulting `SizeT` sum.
        /// - `exp_carry_out`: the expected 1-bit output overflow value.
        fn checkParallelAdderSum(fst_operand: SizeT, snd_operand: SizeT, exp_sum: SizeT, exp_carry_out: u1) bool {
            var dummy_addr = ParallelAdder(SizeT).init(@constCast("??")) catch unreachable;

            dummy_addr.inputs[0] = Device(SizeT).init(
                @constCast(&[2]u8{ 'F', 'S' }),
                @constCast(&fst_operand),
            );
            dummy_addr.inputs[1] = Device(SizeT).init(
                @constCast(&[2]u8{ 'S', 'N' }),
                @constCast(&snd_operand),
            );
            dummy_addr.performSum();

            const sum_eql: bool = dummy_addr._sum == exp_sum;
            const carry_eql: bool = dummy_addr._carry_out == exp_carry_out;
            return sum_eql and carry_eql;
        }
    };
}

test "full_adder_sum" {
    // Checks if the FullAdder construct returns the correct result
    // for all possible inputs.
    // N | First Bit | Second Bit | Carry-input | Sum | Carry-output |
    // 1 | 0         | 0          | 0           | 0   | 0            |
    // 2 | 0         | 0          | 1           | 1   | 0            |
    // 3 | 1         | 0          | 0           | 1   | 0            |
    // 4 | 1         | 0          | 1           | 0   | 1            |
    // 5 | 0         | 1          | 0           | 1   | 0            |
    // 6 | 0         | 1          | 1           | 0   | 1            |
    // 7 | 1         | 1          | 0           | 0   | 1            |
    // 8 | 1         | 1          | 1           | 1   | 1            |

    const checkFullAdderSum = FullAdder.checkFullAdderSum;
    try expect(checkFullAdderSum(0, 0, 0, 0, 0));
    try expect(checkFullAdderSum(0, 0, 1, 1, 0));
    try expect(checkFullAdderSum(1, 0, 0, 1, 0));
    try expect(checkFullAdderSum(1, 0, 1, 0, 1));
    try expect(checkFullAdderSum(0, 1, 0, 1, 0));
    try expect(checkFullAdderSum(0, 1, 1, 0, 1));
    try expect(checkFullAdderSum(1, 1, 0, 0, 1));
    try expect(checkFullAdderSum(1, 1, 1, 1, 1));
}

test "parallel_adder_init" {
    // Try to create a parallel adder with a 1-letter name and a >2 letter name
    try expectError(AdderError.InvalidName, ParallelAdder(CepSizesT.WorldT).init(@constCast("A")));
    try expectError(AdderError.InvalidName, ParallelAdder(CepSizesT.FlagT).init(@constCast("ERROR!")));
}

test "performSum" {
    // Check if the ParallelAdder constructs returns the correct result for
    // some edge cases.
    // N | First Num. | Second Num. | Sum | Carry-output |
    // 1 | 0          | 0           | 0   | 0            |
    // 2 | 25         | 36          | 61  | 0            |
    // 3 | 111111...1 | 1           | 0   | 1            |
    const AdderT = ParallelAdder(u36);
    try expect(AdderT.checkParallelAdderSum(0, 0, 0, 0));
    try expect(AdderT.checkParallelAdderSum(25, 36, 61, 0));
    try expect(AdderT.checkParallelAdderSum(0b111111111111111111111111111111111111, 0b1, 0, 1));
}

test "asDevice" {
    // Initialize a Parallel Adder handling 4-bits numbers (u4)
    // Having attached as input two dummy devices setted as:
    // input_0 = ("FS", 0b0010)
    // input_1 = ("SN", 0b0001)
    //
    // As of now our Parallel Adder has applied no sum operation yet,
    // so its status is:
    // - name = "AD"
    // - sum = 0b0000
    var dummy_addr = ParallelAdder(u4).init(@constCast("AD")) catch unreachable;
    var fst_operand: u4 = 0b0010;
    var snd_operand: u4 = 0b0001;
    dummy_addr.inputs[0] = Device(u4).init(
        @constCast(&[2]u8{ 'F', 'S' }),
        @constCast(&fst_operand),
    );
    dummy_addr.inputs[1] = Device(u4).init(
        @constCast(&[2]u8{ 'S', 'N' }),
        @constCast(&snd_operand),
    );

    // Convert the Parallel Adder into a generic device and check that
    // its name and sum parameter match.
    const addr_device = dummy_addr.asDevice();
    expectEqual([2]u8{ 'A', 'D' }, addr_device.getName()) catch unreachable;
    expectEqual(0, addr_device.getData()) catch unreachable;

    // Apply the sum operation in the Parallel Adder, which will be done
    // between the values of the two input devices.
    // The new status of the Parallel Adder will be:
    // - sum = 0b0010 + 0b0001 = 0b0011
    dummy_addr.performSum();
    expectEqual(0b0011, addr_device.getData()) catch unreachable;
}
