//! This file defines the Main Memory, i.e. the component holding
//! data closer to the execution units.

const std = @import("std");
const Register = @import("simple_circuits/register.zig").Register;
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

pub const MainMemoryError = error{
    OutOfRange,
};

/// Identifies the core group referred.
const CoreGroupT = enum { FstT, SndT };

/// A volatile memory unit holding up to 8192 memory words.
/// The component is divided in two magnetic core groups,
/// each containing 4096 memory words. It is assumed the first
/// group ranges from addresses 0 to 4095, while the
/// second group from 4096 to 8191.
///
/// Reading or writing data to the instance is done through the register `Z`.
/// This register is considered part of the Main Memory, but physically is
/// situated in the Arithmetic Unit. To keep this detail consistent, our
/// instances hold a reference to a register `Z`, stored in an Arithmetic
/// Unit.
///
/// It is adviced to initialize an instance using the `init` method.
pub const MainMemory = struct {
    const name = "Main Memory";

    fst_group: []u36 = undefined,
    snd_group: []u36 = undefined,
    reg_z_ref: *Register = undefined,

    /// Initialize the instance, setting all entries in both
    /// core groups to zero.
    /// - `allocator`: entity delegated with the allocation of space.
    /// - `reg_z`: a reference to the register used for reading or writing
    ///            Main Memory's content.
    pub fn init(allocator: std.mem.Allocator, reg_z_ref: *Register) !MainMemory {
        var instance = MainMemory{};
        instance.reg_z_ref = reg_z_ref;
        instance.fst_group = try allocator.alloc(u36, 4096);
        instance.snd_group = try allocator.alloc(u36, 4096);
        try instance.clearMemory();
        return instance;
    }

    /// Reads the data hold at the specified entry index and copies
    /// it into register `Z`.
    /// If the address goes beyond the range (i.e. 8191), then
    /// an `MainMemoryError.OutOfRange` error is thrown.
    /// - `address`: a value ranging between [0, 8191] specifying
    ///              which entry to read.
    pub fn readMemory(self: *@This(), address: u15) !void {
        // Core groups ranges:
        // * first core group: [0, 4095]
        // * second core group: [4096, 8191]
        // Recall that if we are in the second core group,
        // the requested entry is at index "address - 4095".
        const data =
            if (0 <= address and address <= 4095) fst_blk: {
                break :fst_blk self.fst_group[address];
            } else if (4096 <= address and address <= 8191) snd_blk: {
                const corrected_idx = address - 4096;
                break :snd_blk self.snd_group[corrected_idx];
            } else MainMemoryError.OutOfRange;
        try self.reg_z_ref.*.checkAndSetData(try data);
    }

    /// Writes the content of register `Z` into the specified instance's entry.
    /// If the address goes beyond the range (i.e. 8191), then an
    /// `MainMemoryError.OutOfRange` error is thrown.
    /// - `address`: a value ranging between [0, 8191] specifying
    ///              where to write `Z`'s content.
    pub fn writeData(self: *@This(), address: u15) !void {
        // Core groups ranges:
        // * first core group: [0, 4095]
        // * second core group: [4096, 8191]
        // Recall that if we are in the second core group,
        // the requested entry is at index "address - 4095".
        const data: u36 = self.reg_z_ref.*.convertAndGetData();
        if (0 <= address and address <= 4095) {
            self.fst_group[address] = data;
        } else if (4096 <= address and address <= 8191) {
            const corrected_idx = address - 4096;
            self.snd_group[corrected_idx] = data;
        } else return MainMemoryError.OutOfRange;
    }

    /// Sets all entries in both core groups to zero.
    pub fn clearMemory(self: *@This()) !void {
        for (self.fst_group) |*entry| entry.* = 0;
        for (self.snd_group) |*entry| entry.* = 0;
    }

    /// Frees up the memory allocated by the instance
    pub fn free(self: *@This(), allocator: std.mem.Allocator) !void {
        allocator.free(self.fst_group);
        allocator.free(self.snd_group);
    }

    /// Helper function delegated to printing a core group.
    /// It is used by `format` for printing the whole memory.
    /// - `group`: identifies the core group to print.
    /// - `start_addr`: the address associated to the first entry in the core group
    pub fn formatCoreGroup(
        self: @This(),
        writer: *std.Io.Writer,
        core_group: CoreGroupT,
        start_addr: usize,
    ) std.Io.Writer.Error!void {
        var addr = start_addr;
        var idx: usize = 0;
        while (idx < 4096) {
            // -----------------------  ...
            for (0..8) |_| try writer.print("---------", .{});
            try writer.print("\n", .{});

            // addr    addr+1    addr+2 ...
            for (0..8) |_| {
                defer addr += 1;
                try writer.print("  {}\t", .{addr});
            }
            try writer.print("\n", .{});

            // | val[idx] | val[idx + 1] | ...
            for (0..8) |_| {
                defer idx += 1;
                switch (core_group) {
                    .FstT => {
                        try writer.print("| {}\t", .{self.fst_group[idx]});
                    },
                    .SndT => {
                        try writer.print("| {}\t", .{self.snd_group[idx]});
                    },
                }
            }
            try writer.print("\n", .{});
        }
    }

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) std.Io.Writer.Error!void {
        // We only print entries whose value is different than zero.
        // When writing an entry, we specify the address in memory
        // and below the content:
        //   addr
        // | cont |
        try writer.print("--- {s} ---\n", .{MainMemory.name});
        try self.formatCoreGroup(writer, CoreGroupT.FstT, 0);
        try self.formatCoreGroup(writer, CoreGroupT.SndT, 4096);
    }
};

//----------------------------------------------------- TESTS ------------------------------------------------------

var stderr_buffer: [1024]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
const stderr = &stderr_writer.interface;

test "init_main_mem" {
    // Checks if when the main memory is initialized through method `init`,
    // the returned instance has all entries set to zero.
    var dummy_z_reg: Register = Register.init(@constCast("Z"), Register.RegisterT.word_t);
    var dummy_main_mem = try MainMemory.init(std.testing.allocator, &dummy_z_reg);
    defer dummy_main_mem.free(std.testing.allocator) catch unreachable;
    for (dummy_main_mem.fst_group) |entry| {
        try expectEqual(0, entry);
    }
    for (dummy_main_mem.snd_group) |entry| {
        try expectEqual(0, entry);
    }
}

test "write_and_read" {
    // Write some values into memory and read them back.
    var dummy_z_reg: Register = Register.init(@constCast("Z"), Register.RegisterT.word_t);
    var dummy_main_mem = try MainMemory.init(std.testing.allocator, &dummy_z_reg);
    defer dummy_main_mem.free(std.testing.allocator) catch unreachable;

    try dummy_z_reg.checkAndSetData(4);
    try dummy_main_mem.writeData(0b000000000_000000000_000000000_000000000);
    try dummy_z_reg.checkAndSetData(8);
    try dummy_main_mem.writeData(0b000000000_000000000_000000000_000000001);

    try dummy_main_mem.readMemory(0b000000000_000000000_000000000_000000000);
    try expectEqual(4, dummy_z_reg.convertAndGetData());
    try dummy_main_mem.readMemory(0b000000000_000000000_000000000_000000001);
    try expectEqual(8, dummy_z_reg.convertAndGetData());
}

// test "formatCoreGroup" {
//     var dummy_z_reg: Register = Register.init(@constCast("Z"), Register.RegisterT.word_t);
//     var dummy_main_mem = try MainMemory.init(std.testing.allocator, &dummy_z_reg);
//     defer dummy_main_mem.free(std.testing.allocator) catch unreachable;

//     try dummy_main_mem.formatCoreGroup(stderr, CoreGroupT.FstT, 0);
//     try dummy_main_mem.formatCoreGroup(stderr, CoreGroupT.SndT, 4096);
//     try stderr.flush();

//     return error.SkipZigTest;
// }

// test "format" {
//     var dummy_z_reg: Register = Register.init(@constCast("Z"), Register.RegisterT.word_t);
//     var dummy_main_mem = try MainMemory.init(std.testing.allocator, &dummy_z_reg);
//     defer dummy_main_mem.free(std.testing.allocator) catch unreachable;

//     try dummy_main_mem.format(stderr);
//     try stderr.flush();
//     return error.SkipZigTest;
// }
