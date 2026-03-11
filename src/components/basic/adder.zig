//! Defines various types of circuits capable of performing
//! additon between numbers.
//! Each class of adders distinguish itself by the fixed-length of
//! number supported and their capability of detecting an overflow after the execution
//! of a sum.

const std = @import("std");

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
