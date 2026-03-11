//! This files contains tests for the Adders constructs defined inside "src/basic/adder.zig".

const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;
const adder_f = @import("CEP_basic_circuits").adder_f;
const FullAdder = adder_f.FullAdder;
const ParallelAdder = adder_f.ParallelAdder;

/// Returns if a full adder applies the requested addition correctly, i.e.
/// it returns `exp_sum` and `exp_carry_out` after setting its first bit to
/// `fst_bit`, its second bit to `snd_bit`, and its carry-in to `carry_in`.
fn check_full_adder_sum(fst_bit: u1, snd_bit: u1, carry_in: u1, exp_sum: u1, exp_carry_out: u1) bool {
    const dummy_full_adder: FullAdder = .{
        .fst_bit = fst_bit,
        .snd_bit = snd_bit,
        .carry_in = carry_in,
    };
    const result = dummy_full_adder.perform_sum();

    const sum_eql: bool = result.sum_bit == exp_sum;
    const carry_out_eql: bool = result.carry_out == exp_carry_out;
    return sum_eql and carry_out_eql;
}

// This test checks that the full adder returns
// the correct results for all possible cases.
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
fn check_parallel_adder_sum(fst_number: u36, snd_number: u36, expected_sum: u36, expected_carry_out: u1) bool {
    var dummy_parallel_adder: ParallelAdder = ParallelAdder.init("??");

    dummy_parallel_adder.set_numbers(fst_number, snd_number);
    const result = dummy_parallel_adder.execute_add();

    const sum_eql: bool = result.sum_number == expected_sum;
    const carry_out_eql: bool = result.carry_output == expected_carry_out;
    return sum_eql and carry_out_eql;
}

test "parallel_adder_sum" {
    try expect(check_parallel_adder_sum(25, 36, 61, 0));
    try expect(check_parallel_adder_sum(0, 0, 0, 0));
    try expect(check_parallel_adder_sum(0b111111111111111111111111111111111111, 0b1, 0, 1));


    // -------------------------- DEBUG ----------------------------------------
    // var dummy_parallel_adder: ParallelAdder = ParallelAdder.init("??");
    // _ = dummy_parallel_adder.set_numbers(0b111111111111111111111111111111111111, 0b1);
    // const result = dummy_parallel_adder.execute_add();

    // var stderr_buffer: [1024]u8 = undefined;
    // var writer = std.fs.File.stderr().writer(&stderr_buffer);
    // const stderr = &writer.interface;
    // try stderr.print("result = {d}\t carry-out={b}", .{ result.sum_number, result.carry_output });
    // try stderr.flush();
    // -------------------------- DEBUG ----------------------------------------



}
