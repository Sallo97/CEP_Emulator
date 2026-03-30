//! Defines various types of circuits capable of performing
//! additon between numbers.
//! Each class of adders distinguish itself by the fixed-length of
//! number supported and their capability of detecting an overflow after the execution
//! of a sum.

const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqual = std.testing.expectEqual;
const CepSizesT = @import("constants.zig").CepSizesT;

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
/// - `name`: its 2-letter string identifier.
/// - `sum`: the result of the last addition performed, kept as a `SizeT`.
/// - `carry_out`: the carry_out of the last addition performed.
pub fn ParallelAdder(comptime SizeT: type) type {
    return struct {
        const length = @typeInfo(SizeT).int.bits;

        addr_array: [length]FullAdder = undefined,
        name: [2]u8 = undefined,
        sum: SizeT = undefined,
        carry_out: u1 = undefined,

        /// Returns an initialized Parallel Adder circuit, whose two 36-bit numbers
        /// (distributed among its full adder members) are set to zero.
        /// It is adviced to call this function when one wants to construct a ParallelAdder instance.
        /// - `name` : the two letter identifier of the generated circuit.
        pub fn init(name: []u8) !@This() {
            if (name.len != 2) {
                return AdderError.InvalidName;
            }
            const conv_name = [2]u8{ name[0], name[1] };

            var adder = @This(){
                .name = conv_name,
                .sum = 0,
                .carry_out = 0,
            };
            for (0..length) |idx| {
                adder.addr_array[idx] = .{};
            }

            return adder;
        }

        /// Updates the instance by setting the two new number operands, handling
        /// their distribution among the full adder members.
        /// - `fst_number`: the new value of the first operand.
        /// - `snd_number`: the new value of the second operand.
        pub fn setOperands(self: *@This(), fst_num: SizeT, snd_num: SizeT) void {
            for (0..length) |idx| {
                self.addr_array[idx].fst_bit = @truncate(fst_num >> @truncate(idx));
                self.addr_array[idx].snd_bit = @truncate(snd_num >> @truncate(idx));
            }
        }

        /// Updates the instance by setting the first number operand, handling its distribution
        /// among the full adder members.
        /// - `new_val`: the new value of the first operand.
        pub fn setFstOperand(self: *@This(), new_value: SizeT) void {
            for (0..length) |idx| {
                self.addr_array[idx].fst_bit = @truncate(new_value >> @truncate(idx));
            }
        }

        /// Updates the instance by seting the second number operand, handling its distribution
        /// among the full adder members.
        /// - `new_val`: the new value of the second operand.
        pub fn setSndOperand(self: *@This(), new_value: SizeT) void {
            for (0..length) |idx| {
                self.addr_array[idx].snd_bit = @truncate(new_value >> @truncate(idx));
            }
        }

        /// Returns the outcome of the sum between the 36-bits integers currently hold by the circuit.
        pub fn performSum(self: *@This()) void {
            var summed_number: SizeT = 0;
            var final_carry: u1 = undefined;

            // Sums each digits from less significant to most significant.
            // The resulting bit is stored in the correct i-th position of
            // `summed_number`; while the outputted `carry_out` is given as
            // input to the full adder to the left (i.e. the i+1-th).
            // The generated `carry_out` of the final full adder is
            // copied into `final_carry`.
            for (0..length) |idx| {
                const addr: FullAdder = self.addr_array[idx];
                const res = addr.performSum();

                summed_number = summed_number | (@as(SizeT, res.sum_bit) << @truncate(idx));
                if (idx != length - 1) {
                    self.addr_array[idx + 1].carry_in = res.carry_out;
                } else {
                    final_carry = res.carry_out;
                }
            }

            self.sum = summed_number;
            self.carry_out = final_carry;
        }

        /// Debug function used by `format`. It reconstruct the two operands
        /// whose digits are distributed among the full adder array.
        /// The retrieved numbers are returned in a ordered tuple.
        fn getOperands(self: @This()) (struct { SizeT, SizeT }) {
            var fst_number: SizeT = 0;
            var snd_number: SizeT = 0;

            // Scans each full adder from less significant to most significant.
            // In each of them it retrieves the i-th digits of the two operands,
            // placing them in `fst_number` at the correct position.
            for (0..length) |idx| {
                fst_number = fst_number | (@as(SizeT, self.addr_array[idx].fst_bit) << @truncate(idx));
                snd_number = snd_number | (@as(SizeT, self.addr_array[idx].snd_bit) << @truncate(idx));
            }

            const result = .{ fst_number, snd_number };
            return result;
        }

        /// Clears the operands of the parallel adder
        pub fn clearAdder(self: *@This()) void {
            self.setOperands(0, 0);
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) !void {
            const pair = self.getOperands();
            const fst_number = pair.@"0";
            const snd_number = pair.@"1";

            try writer.print("[{s}] = fst_number = {b}\tsnd_number = {b}", .{ self.name, fst_number, snd_number });
        }

        /// Returns if a parallel adder applies the requested addition correctly, i.e.
        /// it returns `expected_sum` and `expected_carry_out` after setting its first number to
        /// `fst_number` and its second number to `snd_number`.
        /// This function is used to construct simple equality checks for a parallel adder.
        /// It construct a dummy parallel adder, setting its value according to the passed
        /// arguments. Finally, it applies the sum and returns the booled obtained by checking
        /// if the results match the expected ones.
        /// - `fst_number`: the 36-bit value of the first operand.
        /// - `snd_number`: the 36-bit value of the second operand.
        /// - `exp_sum`: the expected resulting 36-bit sum.
        /// - `exp_carry_out`: the expected 1-bit output overflow value.
        fn checkParallelAdderSum(fst_operand: SizeT, snd_operand: SizeT, exp_sum: SizeT, exp_carry_out: u1) bool {
            var dummy_addr = ParallelAdder(SizeT).init(@constCast("??")) catch unreachable;

            dummy_addr.setOperands(fst_operand, snd_operand);
            dummy_addr.performSum();

            const sum_eql: bool = dummy_addr.sum == exp_sum;
            const carry_eql: bool = dummy_addr.carry_out == exp_carry_out;
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

    // Try the create a correct parallel adder, checking that the operands are initialized to 0.
    const dummy_addr = ParallelAdder(CepSizesT.AddressT).init(@constCast("AD")) catch unreachable;
    try expectEqual(.{ 0, 0 }, dummy_addr.getOperands());
}

test "parallel_adder_sum" {
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
