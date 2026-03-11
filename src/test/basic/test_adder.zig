//! This files contains tests for the adders constructs defined inside "src/basic/adder.zig".

const std = @import("std");
const expect = std.testing.expect;

const adder_f = @import("CEP_basic_circuits").adder_f;
const FullAdder = adder_f.FullAdder;
const ParallelAdder = adder_f.ParallelAdder;

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

    dummy_parallel_adder.set_numbers(fst_operand, snd_operand);
    const result = dummy_parallel_adder.execute_add();

    const sum_eql: bool = result.sum_number == exp_sum;
    const carry_out_eql: bool = result.carry_output == exp_carry_out;
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
