//! Defines an assortment of functions manipulating numbers
//! through bit masks.

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const MaskUtilsError = error{OutOfRange};

/// An holder of functions manipulatin numbers using bit masks
/// represented as a generic struct, containing no fieds.
///
/// To define a specialization the following arguments are needed:
/// - `SizeT`: specifies the bit-size of the numbers manipulated.
pub fn MaskUtils(SizeT: type) type {
    return struct {
        const bits_length: usize = @typeInfo(SizeT).int.bits;

        /// Generates a bit-mask having all bits in the range [`start_pos`, `start_pos + len - 1`]
        /// (ordered from msb to lsb) set to one.
        ///
        /// - `start_pos`: the beginning of the range, which counts from left to right (i.e.
        ///                start_pos = 0 indicates the most significant bit of the mask).
        /// - `len`: the length of the range. Note that `start_pos + len` is excluded.
        pub fn contiguousMask(start_pos: usize, len: usize) !SizeT {
            // Check that the passed parameters are within the `SizeT` type's boundaries.
            const end_pos = if (len == 0) start_pos else start_pos + len - 1;
            if (start_pos >= bits_length or
                end_pos >= bits_length)
                return MaskUtilsError.OutOfRange;

            // Compute the mask
            var mask: SizeT = 0;
            for (0..len) |i| {
                const shift_amnt = bits_length - (start_pos + i + 1);
                const pow: SizeT = @as(SizeT, 1) << @intCast(shift_amnt);
                mask |= pow;
            }
            return mask;
        }

        /// Return true if the bit at given position `pos` (counting from the most
        /// significant bit to the least significant bit) is one, otherwise false.
        pub fn isSet(value: SizeT, pos: usize) !bool {
            if (pos >= bits_length) {
                return MaskUtilsError.OutOfRange;
            }
            const pow = bits_length - (pos + 1);
            const bit: u1 = @truncate(value >> @intCast(pow));
            return bit == 1;
        }

        /// Returns the sequence obtained by copying the bits of `from` specified
        /// by `mask` into `to`.
        ///
        /// - `mask`: identifies the portion of bits of `from` to copy.
        /// - `from`: the content we need to partially copy into `to`.
        /// - `to`: where we need to store the copied portion.
        pub fn copyContent(mask: SizeT, from: SizeT, to: SizeT) SizeT {
            const copied = mask & from;

            const to_preserve = ~mask;
            const kept = to_preserve & to;

            const result = copied | kept;
            return result;
        }

        /// Returns the number of bits set to one in `mask`.
        pub fn bitsSet(mask: SizeT) isize {
            var count: isize = 0;
            for (0..bits_length) |offset| {
                const bit: u1 = @truncate(mask >> @intCast(offset));
                if (bit == 1) count += 1;
            }
            return count;
        }

        /// Returns the position of the first bit set to one in `mask`.
        /// We assume position 0 is the most significant bit.
        /// If no bit set to one is found, it returns the special value `null`.
        pub fn fstSetPos(mask: SizeT) ?isize {
            var pos: isize = 0;
            var flag: bool = false;
            for (1..bits_length + 1) |offset| {
                const bit: u1 = @truncate(mask >> @intCast(bits_length - offset));
                if (bit == 1) {
                    flag = true;
                    break;
                } else pos += 1;
            }
            if (flag) {
                return pos;
            } else return null;
        }
    };
}

test "computeMask" {
    // Generate a mask of four bits having:
    // start_pos = 0    length = 2
    // The generated mask should be: 0b1100
    const example1: u4 = MaskUtils(u4).contiguousMask(0, 2) catch unreachable;
    try expectEqual(0b1100, example1);

    // Generate a mask of 36-bits having:
    // start_pos = 15   length = 15
    // The generated mask should be: 0b000000000000000111111111111111000000
    const example2: u36 = MaskUtils(u36).contiguousMask(15, 15) catch unreachable;
    try expectEqual(0b000000000000000111111111111111000000, example2);

    // Generate a mask of 15-bits having:
    // start_pos = 0    length = 0
    // The generated mask should be: 0b000000000000000
    const example3: u15 = MaskUtils(u15).contiguousMask(0, 0) catch unreachable;
    try expectEqual(0, example3);

    // Generate a mask of 15-bits having:
    // start_pos = 15   length = 2
    // The mask should not be generated, instead an `OutOfRange` error occurs.
    try expectError(MaskUtilsError.OutOfRange, MaskUtils(u15).contiguousMask(15, 2));

    // Generate a mask of 36-bits having:
    // start_pos = 33    length = 3
    // The mask should not be generated, instead an `OutOfRange` error should occur.
    try expectError(MaskUtilsError.OutOfRange, MaskUtils(u36).contiguousMask(33, 4));
}

test "isSet" {
    const MaskUtilsFive = MaskUtils(u5);
    const value = 0b01101;

    // Check if the bit at position 2 is within the group
    // pos   | 0 | 1 | 2 | 3 | 4 |
    // value | 0 | 1 | 1 | 0 | 1 |
    //                 ^ => should return true
    const example1 = MaskUtilsFive.isSet(value, 2) catch unreachable;
    try expectEqual(true, example1);

    // Check if the bit at position 4 is within the group
    // pos   | 0 | 1 | 2 | 3 | 4 |
    // value | 0 | 1 | 1 | 0 | 1 |
    //                         ^ => should return true
    const example2 = MaskUtilsFive.isSet(value, 4) catch unreachable;
    try expectEqual(true, example2);

    // Check if the bit at position 0 is within the group
    // pos   | 0 | 1 | 2 | 3 | 4 |
    // value | 0 | 1 | 1 | 0 | 1 |
    //         ^ => should return false
    const example3 = MaskUtilsFive.isSet(value, 0) catch unreachable;
    try expectEqual(false, example3);
}

test "copyContent" {
    // Define the common MaskUtilites managing numbers of five bit length (i.e. u5).
    const MaskUtilitiesFive = MaskUtils(u5);

    // portion = 0b01110    from = 0b00011  to = 0b10101
    // The result should be = 0b10011
    const example1 = MaskUtilitiesFive.copyContent(0b01110, 0b00011, 0b10101);
    expectEqual(0b10011, example1) catch unreachable;

    // portion = 0b10000    from = 0b01111  to = 0b10000
    // The result should be = 0b00000
    const example2 = MaskUtilitiesFive.copyContent(0b10000, 0b01111, 0b10000);
    expectEqual(0b00000, example2) catch unreachable;

    // portion = 0b01011    from = 0b10111  to = 0b11001
    // The result should be = 0b10011
    const example3 = MaskUtilitiesFive.copyContent(0b01011, 0b10111, 0b11001);
    expectEqual(0b10011, example3) catch unreachable;
}

test "bitSet" {
    // SizeT = u6
    // mask = 0b110101
    // result = 4
    const example1 = MaskUtils(u6).bitsSet(0b110101);
    try expectEqual(4, example1);

    // SizeT = u8
    // mask = 0b00000000
    // result = 0
    const example2 = MaskUtils(u8).bitsSet(0b00000000);
    try expectEqual(0, example2);

    // SizeT = u4
    // mask = 0b1111
    // result = 4
    const example3 = MaskUtils(u4).bitsSet(0b1111);
    try expectEqual(4, example3);
}

test "fstSetPos" {
    // SizeT = u6
    // mask = 0b010010
    // result = 1
    const example1 = MaskUtils(u6).fstSetPos(0b010010);
    try expectEqual(1, example1);

    // SizeT = u8
    // mask = 0b00000001
    // result = 7
    const example2 = MaskUtils(u8).fstSetPos(0b00000001);
    try expectEqual(7, example2);

    // SizeT = u1
    // mask = 0b1
    // result = 0
    const example3 = MaskUtils(u1).fstSetPos(0b1);
    try expectEqual(0, example3);

    // SizeT = u10
    // mask = 0b0000000000
    // result = null
    const example4 = MaskUtils(u10).fstSetPos(0b0000000000);
    try expectEqual(null, example4);
}
