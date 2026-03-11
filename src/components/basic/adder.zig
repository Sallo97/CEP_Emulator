//! An adder (also called summer) at its core is a circuit
//! capable of performing addition between numbers.
//!
//! The CEP uses parallel adders mainly in the Arithmetic Unit, for
//! implementing mathematical operations.

const std = @import("std");

/// Struct containing the result of a full adder circuit.
/// A full adder circuit returns always a sum bit and a carry-output bit.
const FullAdderResult = struct {
    sum_bit: u1,
    carry_out: u1,

    //--------- METHODS -----------------------------------
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("sum_bit = {b}\tcarry_output = {b}", .{ self.sum_bit, self.carry_out });
    }
};

/// The result of a parallel full adder.
/// It returns the summed 36-bit number and the carry output bit.
const ParallelAdderResult = struct {
    sum_number: u36,
    carry_output: u1,

    //------------------- METHODS -----------------------------------------------
    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("sum_number = {d}({b})\tcarry_output = {b}", .{ self.sum_number, self.sum_number, self.carry_output });
    }
};

/// A full adder has in input two bits and a carry.
/// It adds them and returns as outputs the result of
/// the sum and a carry-output.
pub const FullAdder = struct {
    fst_bit: u1 = 0,
    snd_bit: u1 = 0,
    carry_in: u1 = 0,

    //---------------- METHODS ----------------------------
    pub fn perform_sum(self: FullAdder) FullAdderResult {
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

/// A Parallel Adder can add two binary numbers of any length.
/// It adds all pairs of bits at once instead of one after the other.
/// The circuit is made by connecting as many full addresses as the bit_length (i.e.
/// the width of the binary number supported).
///
/// Each full adder will send its carry-output as input to the adder to its left.
///
/// A Parallel Adder is distinguished by its 2-letter identifier.
pub const ParallelAdder = struct {
    full_adders_array: [36]FullAdder,
    name: *const [2:0]u8,

    //------------ METHODS ------------------------------------------------------

    /// Initializes a Parallel Adder, setting its name to the requested
    /// `name`, and setting the two 36-bit numbers to zero.
    /// CALL THIS FUNCTION WHEN YOU WANT TO CONSTRUCT A PARALLEL ADDER.
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

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void {
        const pair = self.get_pair_numbers();
        const fst_number = pair.@"0";
        const snd_number = pair.@"1";

        try writer.print("[{s}] = fst_number = {d}({b:.36})\tsnd_number = {d}({b:.36})", .{ self.name, fst_number, fst_number, snd_number, snd_number });
    }

    /// Returns a pair containing the first and second number
    /// currently set in the Parallel Adder.
    pub fn get_pair_numbers(self: @This()) (struct { u36, u36 }) {
        var fst_number: u36 = 0;
        var snd_number: u36 = 0;

        for (0..36) |i| {
            fst_number = fst_number | (@as(u36, self.full_adders_array[i].fst_bit) << @truncate(i));
            snd_number = snd_number | (@as(u36, self.full_adders_array[i].snd_bit) << @truncate(i));
        }

        const result = .{ fst_number, snd_number };

        return result;
    }

    /// This function will distribute the two numbers to add among
    /// the various full adders.
    pub fn set_numbers(self: *@This(), fst_num: u36, snd_num: u36) void {
        for (0..36) |idx| {
            self.full_adders_array[idx].fst_bit = @truncate(fst_num >> @truncate(idx));
            self.full_adders_array[idx].snd_bit = @truncate(snd_num >> @truncate(idx));
        }
    }

    /// Executes the parallel addition between the two setted numbers
    /// Recall to call `set_numbers` before to prepare the adder for the sum.
    pub fn execute_add(self: *@This()) ParallelAdderResult {
        var summed_number: u36 = 0;
        var final_carry: u1 = 0;
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
            .sum_number = summed_number,
            .carry_output = final_carry,
        };
        return final_res;
    }
};
