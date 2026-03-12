//! Defines various types of circuits capable of performing
//! additon between numbers.
//! Each class of adders distinguish itself by the fixed-length of
//! number supported and their capability of detecting an overflow after the execution
//! of a sum.

const std = @import("std");
const expect = std.testing.expect;

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

    /// Returns the outcome of the sum between the bits currently hold by the circuit.
    pub fn perform_sum(self: @This()) FullAdderResult {
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
};

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

/// A circuit supporting the addition between two 36-bit numbers, handling possible overflows during the operation.
/// - `full_adders_array`: the set of contiguous full adders used to implement the operation.
///                        Each i-th full adder contains the i-th digits of the two 36-bit numbers.
///                        Each full adder is "attached" to its adjacent neighbors, to which it sends or receive carry information.
/// - `name`: its 2-letter string identifier.
pub const ParallelAdder = struct {
    full_adders_array: [36]FullAdder,
    name: *const [2:0]u8,

    /// Returns an initialized Parallel Adder circuit, whose two 36-bit numbers
    /// (distributed among its full adder members) are set to zero.
    /// It is adviced to call this function when one wants to construct a ParallelAdder instance.
    /// - `name` : the two letter identifier of the generated circuit.
    pub fn init(name: *const [2:0]u8) @This() {
        var adder: ParallelAdder = .{
            .full_adders_array = undefined,
            .name = name,
        };
        for (0..36) |idx| {
            adder.full_adders_array[idx] = .{};
        }

        return adder;
    }

    /// This function updates the instance by setting the two new number operands, handling
    /// their distribution among the full adder members.
    /// - `fst_number`: the new value of the first operand.
    /// - `snd_number`: the new value of the second operand.
    pub fn set_operands(self: *@This(), fst_num: u36, snd_num: u36) void {
        for (0..36) |idx| {
            self.full_adders_array[idx].fst_bit = @truncate(fst_num >> @truncate(idx));
            self.full_adders_array[idx].snd_bit = @truncate(snd_num >> @truncate(idx));
        }
    }

    /// Returns the outcome of the sum between the 36-bits integers currently hold by the circuit.
    pub fn perform_sum(self: *@This()) ParallelAdderResult {
        var summed_number: u36 = 0;
        var final_carry: u1 = undefined;

        // Sums each digits from less significant to most significant.
        // The resulting bit is stored in the correct i-th position of
        // `summed_number`; while the outputted `carry_out` is given as
        // input to the full adder to the left (i.e. the i+1-th).
        // The generated `carry_out` of the final full adder is
        // copied into `final_carry`.
        for (0..36) |i| {
            const addr: FullAdder = self.full_adders_array[i];
            const res = addr.perform_sum();

            summed_number = summed_number | (@as(u36, res.sum_bit) << @truncate(i));
            if (i != 35) {
                self.full_adders_array[i + 1].carry_in = res.carry_out;
            } else {
                final_carry = res.carry_out;
            }
        }

        const final_res: ParallelAdderResult = .{
            .summed_number = summed_number,
            .carry_out = final_carry,
        };
        return final_res;
    }

    /// Debug function used by `format`. It reconstruct the two operands
    /// whose digits are distributed among the full adder array.
    /// The retrieved numbers are returned in a ordered tuple.
    fn get_operands(self: @This()) (struct { u36, u36 }) {
        var fst_number: u36 = 0;
        var snd_number: u36 = 0;

        // Scans each full adder from less significant to most significant.
        // In each of them it retrieves the i-th digits of the two operands,
        // placing them in `fst_number` at the correct position.
        for (0..36) |i| {
            fst_number = fst_number | (@as(u36, self.full_adders_array[i].fst_bit) << @truncate(i));
            snd_number = snd_number | (@as(u36, self.full_adders_array[i].snd_bit) << @truncate(i));
        }

        const result = .{ fst_number, snd_number };
        return result;
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        const pair = self.get_operands();
        const fst_number = pair.@"0";
        const snd_number = pair.@"1";

        try writer.print("[{s}] = fst_number = {d}({b:.36})\tsnd_number = {d}({b:.36})", .{ self.name, fst_number, fst_number, snd_number, snd_number });
    }
};

/// Contains the outcome of an addition done by a ParallelAdder.
/// - `summed_number` : the sum's result represented as a 36-bit unsigned integer.
/// - `carry_out`: the overflow bit produced by the operation, being set to one when the result exceeds the fixed length of the number.
const ParallelAdderResult = struct {
    summed_number: u36,
    carry_out: u1,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("sum_number = {d}({b})\tcarry_output = {b}", .{ self.summed_number, self.summed_number, self.carry_out });
    }
};

//----------------------------------------------------- TESTS ------------------------------------------------------

/// This function is used to construct simple equality checks for a full adder.
/// It construct a dummy full adder, setting its value according to the passed
/// arguments. Finally, it applies the sum and returns the boolean obtained by
/// checking if the results match the expected ones.
/// - `fst_operand`: the 1-bit value of the first operand.
/// - `snd_operand`: the 1-bit value of the second operand.
/// - `carry_in`: the 1-bit value of the input overflow value.
/// - `exp_sum`: the expected resulting 1-bit sum.
/// - `exp_carry_out`: the expected 1-bit output overflow value.
fn check_full_adder_sum(fst_operand: u1, snd_operand: u1, carry_in: u1, exp_sum: u1, exp_carry_out: u1) bool {
    const dummy_full_adder: FullAdder = .{
        .fst_bit = fst_operand,
        .snd_bit = snd_operand,
        .carry_in = carry_in,
    };
    const result = dummy_full_adder.perform_sum();
    const sum_eql: bool = result.sum_bit == exp_sum;
    const carry_out_eql: bool = result.carry_out == exp_carry_out;
    return sum_eql and carry_out_eql;
}

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
test "full_adder_sum" {
    try expect(check_full_adder_sum(0, 0, 0, 0, 0));
    try expect(check_full_adder_sum(0, 0, 1, 1, 0));
    try expect(check_full_adder_sum(1, 0, 0, 1, 0));
    try expect(check_full_adder_sum(1, 0, 1, 0, 1));
    try expect(check_full_adder_sum(0, 1, 0, 1, 0));
    try expect(check_full_adder_sum(0, 1, 1, 0, 1));
    try expect(check_full_adder_sum(1, 1, 0, 0, 1));
    try expect(check_full_adder_sum(1, 1, 1, 1, 1));
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
fn check_parallel_adder_sum(fst_operand: u36, snd_operand: u36, exp_sum: u36, exp_carry_out: u1) bool {
    var dummy_parallel_adder: ParallelAdder = ParallelAdder.init("??");

    dummy_parallel_adder.set_operands(fst_operand, snd_operand);
    const result = dummy_parallel_adder.perform_sum();

    const sum_eql: bool = result.summed_number == exp_sum;
    const carry_out_eql: bool = result.carry_out == exp_carry_out;
    return sum_eql and carry_out_eql;
}

// Check if the ParallelAdder constructs returns the correct result for
// some edge cases.
// N | First Num. | Second Num. | Sum | Carry-output |
// 1 | 0          | 0           | 0   | 0            |
// 2 | 25         | 36          | 61  | 0            |
// 3 | 111111...1 | 1           | 0   | 1            |
test "parallel_adder_sum" {
    try expect(check_parallel_adder_sum(0, 0, 0, 0));
    try expect(check_parallel_adder_sum(25, 36, 61, 0));
    try expect(check_parallel_adder_sum(0b111111111111111111111111111111111111, 0b1, 0, 1));
}
