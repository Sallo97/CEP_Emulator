//! This file defines the Main Memory, i.e. the component holding
//! data closer to the execution units.

const std = @import("std");
const Register = @import("CEP_simple_circuits").registerF;
const assert = std.debug.assert;
const expectEqual = std.testing.expectEqual;

pub const MainMemoryError = error{
    OutOfRange,
};

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
const MainMemory = struct {
    const name = "Main Memory";

    fst_group: [4096]u36,
    snd_group: [4096]u36,
    reg_z_ref: *Register = undefined,

    /// Initialize the instance, setting all entries in both
    /// core groups to zero.
    /// - `allocator`: entity delegated with the allocation of space.
    /// - `reg_z`: a reference to the register used for reading or writing
    ///            Main Memory's content.
    pub fn init(allocator: std.mem.Allocator, reg_z_ref: *Register) !void {
        const instance = MainMemory{};
        instance.reg_z_ref = reg_z_ref;
        instance.fst_group = allocator.alloc(u36, 4096);
        instance.snd_group = allocator.alloc(u36, 4096);
        instance.clearMemory();
    }

    /// Reads the data hold at the specified entry index and copies
    /// it into register `Z`.
    /// If the address goes beyond the range (i.e. 8191), then
    /// an `MainMemoryError.OutOfRange` error is thrown.
    /// - `address`: a value ranging between [0, 8191] specifying
    ///              which entry to read.
    pub fn readMemory(self: *@This(), address: u15) !void {
        // Core groups ranges:
        // - first core group: [0, 4095]
        // - second core group: [4096, 8191]
        // Recall that if we are in the second core group,
        // the requested entry is at index address - 4095.
        const data: MainMemoryError.OutOfRange!u36 =
            if (0 <= address and address <= 4095) fst_blk: {
                break :fst_blk self.fst_group[address];
            } else if (4096 <= address and address <= 8191) snd_blk: {
                const corrected_idx = address - 4096;
                break :snd_blk self.snd_group[corrected_idx];
            } else MainMemoryError.OutOfRange;
        self.reg_z_ref.*.checkAndSetData(data);
    }

    /// Writes the content of register `Z` into the specified instance's entry.
    /// If the address goes beyond the range (i.e. 8191), then an
    /// `MainMemoryError.OutOfRange` error is thrown.
    /// - `address`: a value ranging between [0, 8191] specifying
    ///              where to write `Z`'s content.
    pub fn writeData(self: *@This(), address: u15) !void {
        // Core groups ranges:
        // - first core group: [0, 4095]
        // - second core group: [4096, 8191]
        // Recall that if we are in the second core group,
        // the requested entry is at index address - 4095.
        const data: u36 = self.reg_z_ref.*.convertAndGetData();
        if (0 <= address and address <= 4095) {
            self.fst_group[address] = data;
        } else if (4096 <= address and address <= 8191) {
            const corrected_idx = address - 4096;
            self.snd_group[corrected_idx];
        } else MainMemoryError.OutOfRange;
    }

    /// Sets all entries in both core groups to zero.
    pub fn clearMemory(self: *@This()) !void {
        for (self.fst_group) |entry| entry = 0;
        for (self.snd_group) |entry| entry = 0;
    }

    /// Frees up the memory allocated by the instance
    pub fn free(self: *@This(), allocator: std.mem.Allocator) !void {
        allocator.free(self.fst_group);
        allocator.free(self.snd_group);
    }
};
