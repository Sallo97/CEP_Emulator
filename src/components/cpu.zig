//! This file defines the CPU, specifying its field and functions.

const std = @import("std");
const reg = @import("register.zig");
const instr = @import("instruction.zig");

pub const CpuContext = struct {
    registers: reg.RegistersContext = .{},
    cycleCount: usize = 0,

    pub fn format(self: CpuContext, writer: *std.io.Writer) !void {
        try writer.print("------------CPU STATUS-----------\n", .{});
        try writer.print("number of cycles done: {d}\n", .{self.cycleCount});
        try self.registers.format(writer);

        try writer.writeAll("--------------------------------\n");
    }
};
