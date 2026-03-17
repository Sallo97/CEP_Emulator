//! This file defines the Arithmetic Unit, i.e. the component in the CEP responsible
//! for executing all arithmetic computations.

const std = @import("std");
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const Register = @import("simple_circuits/register.zig").Register;
const ParallelAdder = @import("simple_circuits/adder.zig").ParallelAdder;

/// Defines the kind of operation requested to the Arithmetic Unit by the CPU.
const OperationT = enum {
    CopyT,
    NegationT,
    AdditionT,
};

/// Defines the registers requested for an operation.
const OperandT = enum {
    A,
    B,
    C,
    Z,
};

/// A circuit specialized in implementing arithmetic computations.
/// The unit supports both fixed point and floating point arithmetics.
/// Its main components are:
/// - two 36-bits registers `A` and `B`, used as accumulators.
/// - register `C`, used for storing the memory address of the current operand
///   or generic auxiliary data.
/// - the adder `AD`.
///
/// Altough they are not part of the unit, physically are present:
/// - the memory register `Z`, which contains the content pointed by the current memory address.
/// It is adviced to construct an instance through the `init` method.
///
/// The instruction list defines the flag register `G` for holding the overflow bit of an arithmetic instruction.
/// It is not specified where it resides, so we assume it is inside the arithmetic unit.
const ArithmeticUnit = struct {
    const name = "Arithmetic Unit";

    a_reg: Register = Register.init('A', Register.RegisterT.word_t),
    b_reg: Register = Register.init('B', Register.RegisterT.word_t),
    c_reg: Register = Register.init('C', Register.RegisterT.address_t),
    ad_add: ParallelAdder = ParallelAdder.init("AD"),

    z_reg: Register = Register.init('Z', Register.RegisterT.word_t),

    g_reg: Register = Register.init('G', Register.RegisterT.flag_t),

    /// Initializes an Arithmetic Unit, having all of its registers set to zero.
    /// It is adviced to construct an instance through this method instead of manually.
    pub fn init() ArithmeticUnit {
        const arithmetic_unit: ArithmeticUnit = .{};
        return arithmetic_unit;
    }

    /// Apply the requested operation.
    /// Invokes ArithmeticUnitError if something went wrong.
    /// - `allocator`: will be used to allocate temporary information needed during the processing.
    /// - `operation_t`: the kind of operation requested (e.g. Addition, Copy, etc...).
    /// - `number_t`: the kind of number used, i.e. if they are integers, fixed or floating point numbers.
    /// - `precision_t`: the size of the operands (i.e. if a number spans one or two registers).
    pub fn applyOperation(self: *@This(), allocator: std.mem.Allocator, operation_t: OperationT, operands: []OperandT) !void {
        var operands_ptr_list = self.getOperandPtrArray(allocator, operands);
        defer operands_ptr_list.deinit(allocator);

        switch (operation_t) {
            .CopyT => {
                // A copy operation is always between two
                // operands.
                //
                // The source register's content is simply
                // copied and set as the new value of the
                // destination register.
                //
                // This operation never causes an overflow.
                assert(operands_ptr_list.items.len == 2);
                const src_reg_ptr: *Register = operands_ptr_list.items[0];
                const dst_reg_ptr: *Register = operands_ptr_list.items[1];

                try dst_reg_ptr.checkAndSetData(src_reg_ptr.convertAndGetData());
            },
            .NegationT => {
                // A negation operation has always just one operand.
                //
                // The negation is implemented in-hardware by summing
                // the number with 100...000 (i.e. a word having only the
                // most significant bit set to one).
                //
                // This operation can cause an overflow: when the number is
                // negative, the addition with 100...000 will cause the
                // carry-out to be set to one.
                assert(operands_ptr_list.items.len == 1);
                const to_negate_reg_ptr: *Register = operands_ptr_list.items[0];
                const init_value: u36 = to_negate_reg_ptr.convertAndGetData();
                const negation_operand: u36 = 0b100000000000000000000000000000000000;

                self.ad_add.setOperands(negation_operand, init_value);
                const final_value = self.ad_add.performSum();

                try to_negate_reg_ptr.checkAndSetData(final_value.summed_number);
                try self.g_reg.checkAndSetData(final_value.carry_out);
            },
            .AdditionT => {
                // The addition operation has always three operands:
                // - the first one is the return register.
                // - the last two are the operand registers.
                //
                // The sum is implemented by passing the source registers'
                // content to the parallel adder and setting the destination
                // register and flag register `G` to the result of the addition.
                //
                // This operation can cause an overflow when the result of the
                // addition exceeds 36-bits.
                assert(operands_ptr_list.items.len == 3);
                const fst_operand_reg_ptr = operands_ptr_list.items[0];
                const snd_operand_reg_ptr = operands_ptr_list.items[1];
                const return_reg_ptr = operands_ptr_list.items[2];

                self.ad_add.setOperands(fst_operand_reg_ptr.convertAndGetData(), snd_operand_reg_ptr.convertAndGetData());
                const sum_result = self.ad_add.performSum();

                try return_reg_ptr.checkAndSetData(sum_result.summed_number);
                try self.g_reg.checkAndSetData(sum_result.carry_out);
            },
        }
    }

    /// Private function which given a list of operands it returns
    /// a list of pointers to the associated real registers.
    fn getOperandPtrArray(self: *@This(), allocator: std.mem.Allocator, operands: []OperandT) std.ArrayList(*Register) {
        var op_list: std.ArrayList(*Register) = .empty;
        for (operands) |operand| {

            // Retrieve the current operand's pointer.
            const op_ptr: *Register = switch (operand) {
                .A => &self.a_reg,
                .B => &self.b_reg,
                .C => &self.c_reg,
                .Z => &self.z_reg,
            };

            op_list.append(allocator, op_ptr) catch unreachable;
        }
        return op_list;
    }

    /// Sets all registers of the instance to zero.
    pub fn clearAllRegisters(self: *@This()) void {
        try self.a_reg.clearData();
        try self.b_reg.clearData();
        try self.c_reg.clearData();
        try self.z_reg.clearData();
        try self.g_reg.clearData();

        self.ad_add.clearAdder();
    }

    pub fn format(self: @This(), writer: *std.io.Writer) !void {
        const component_prefix = "\n-";
        try writer.print("[{s}]", .{ArithmeticUnit.name});
        try writer.print("{s}", .{component_prefix});
        try self.a_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.b_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.c_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.ad_add.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.z_reg.format(writer);
        try writer.print("{s}", .{component_prefix});
        try self.g_reg.format(writer);
        try writer.print("\n", .{});
        try writer.flush();
    }
};

// Defines a writer to the standard error, which is used for testing the `format` function.
var stderr_buffer: [1024]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
const stderr = &stderr_writer.interface;

test "init" {
    const dummy_arithmetic_unit = ArithmeticUnit.init();
    _ = dummy_arithmetic_unit;
    // try dummy_arithmetic_unit.format(stderr);
}

test "get_operand" {
    var dummy_arithmetic_unit = ArithmeticUnit.init();
    const dummy_allocator = std.testing.allocator;
    const operands = [_]OperandT{ .A, .B, .C, .Z, .A, .B, .C, .C };
    var operands_ptr_list: std.ArrayList(*Register) = dummy_arithmetic_unit.getOperandPtrArray(dummy_allocator, @constCast(&operands));
    defer operands_ptr_list.deinit(dummy_allocator);

    try expectEqual(8, operands_ptr_list.items.len);
}

test "copy_operation" {
    var dummy_arithmetic_unit = ArithmeticUnit.init();
    try dummy_arithmetic_unit.a_reg.checkAndSetData(0b100);
    const operands = [_]OperandT{ .A, .Z };
    try dummy_arithmetic_unit.applyOperation(std.testing.allocator, OperationT.CopyT, @constCast(&operands));

    try expectEqual(4, dummy_arithmetic_unit.z_reg.convertAndGetData());
}

test "negation_operation" {
    var dummy_arithmetic_unit = ArithmeticUnit.init();
    try dummy_arithmetic_unit.z_reg.checkAndSetData(0b000000000000000000000000000000000100);
    const operands = [_]OperandT{.Z};
    try dummy_arithmetic_unit.applyOperation(std.testing.allocator, OperationT.NegationT, @constCast(&operands));

    try expectEqual(0b100000000000000000000000000000000100, dummy_arithmetic_unit.z_reg.convertAndGetData());
    try expectEqual(0b0, dummy_arithmetic_unit.g_reg.convertAndGetData());

    try dummy_arithmetic_unit.z_reg.checkAndSetData(0b100000000000000000000000000000000100);
    try dummy_arithmetic_unit.applyOperation(std.testing.allocator, OperationT.NegationT, @constCast(&operands));

    try expectEqual(0b000000000000000000000000000000000100, dummy_arithmetic_unit.z_reg.convertAndGetData());
    try expectEqual(0b1, dummy_arithmetic_unit.g_reg.convertAndGetData());
}

test "integer_sum_operation" {
    var dummy_arithmetic_unit = ArithmeticUnit.init();
    try dummy_arithmetic_unit.a_reg.checkAndSetData(0b10);
    try dummy_arithmetic_unit.z_reg.checkAndSetData(0b11);
    var operands = [_]OperandT{ .A, .Z, .A };
    try dummy_arithmetic_unit.applyOperation(std.testing.allocator, OperationT.AdditionT, @constCast(&operands));
    try expectEqual(0b101, dummy_arithmetic_unit.a_reg.convertAndGetData());
    try expectEqual(0b0, dummy_arithmetic_unit.g_reg.convertAndGetData());

    dummy_arithmetic_unit.clearAllRegisters();
    try dummy_arithmetic_unit.a_reg.checkAndSetData(0b111111111111111111111111111111111111);
    try dummy_arithmetic_unit.b_reg.checkAndSetData(0b000000000000000000000000000000000001);
    operands = [_]OperandT{ .A, .B, .Z };
    try dummy_arithmetic_unit.applyOperation(std.testing.allocator, OperationT.AdditionT, @constCast(&operands));
    try expectEqual(0b0, dummy_arithmetic_unit.z_reg.convertAndGetData());
    try expectEqual(0b1, dummy_arithmetic_unit.g_reg.convertAndGetData());
}
