//! This file defines a Switching Circuit, i.e. an object
//! which receives data in input and according to the current
//! value of the selection lines and its logic computes an output.

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const Register = @import("./register.zig").Register;
const ParallelAdder = @import("./adder.zig").ParallelAdder;
const CepSizesT = @import("./constants.zig").CepSizesT;

const SrcHandlerError = error{ OutOfRange, NotAttached, AlreadyAttached, OverflowBits };

/// An object representing the sources coming to a SwitchCircuit.
/// The sources are divided into the physical devices attached to the
/// handler and the abstact values obtained by mixing the content of the
/// connected entities.
///
/// To define a specialization of SourcesHandler the following parameters are requested:
/// - `device_num`: the cardinality of hardware components attached to the handler. This value is fixed and cannot be changed.
///
/// - `src_num`: the cardinality of abstract sources attached to the handler. An abstract source is one
///              obtained by mixing the content coming from multiple attached devices.
///
/// - `SizeT`: the type of the content coming from a device/source. This is usually an unsigned integer interpreted
///            as a bit sequence.
///
/// The generated struct has the following fields:
/// - `attached_devices`: a map having:
///     * as key the two-letter word identifier of an attached device.
///     * as value the pointer to the content provided as output by the device.
///
/// - `sources`: the array of abstract sources, where each entry is a listof `SrcPair`, specifying the range of consecutive bits
///              coming from said device.
pub fn SrcHandler(comptime src_num: usize, comptime SizeT: type) type {
    return struct {
        /// Represents a portion of consecutive bits coming from an hardware component.
        /// - `device_name`: The unique identifier of the device. The special name `00` will refer
        ///                  to the constant zero.
        ///
        /// - `bits`: the number of consecutive bits associated to the device. The starting position depends on the previous entries.
        ///           For the first element in the list, the start position is zero (i.e. the most significant bit).
        ///
        /// An instance of `SrcHandler` has always the first entry, indicated as `e0` set to zero.
        const SrcPair = struct {
            device_name: [2]u8,
            bits: usize,
        };
        const bits_length = @typeInfo(SizeT).int.bits;
        const device_zero_name = [2]u8{ '0', '0' };

        attached_devices: std.AutoHashMap([2]u8, *SizeT) = undefined,
        sources: [src_num]std.ArrayList(SrcPair) = undefined,

        /// Adds as last element to the virtual source of index `idx` the new `pair`.
        /// The starting position of the inserted sequence is assumed to start after the previous element in the list.
        /// - `idx`: the index identifying the source, which must be between `0` and `src_num` excluded. If the range condition
        ///          is not satisfied an `OutOfRange` error is thrown.
        ///
        /// - `pair`: a `SrcPair` instance specifying the device and number of consecutive bits added. If the
        ///           hardware component specified is not attached to the instance, an `NotAttached` error is thrown.
        ///           The number of `bits` must not exceed the length of the sequence, otherwise an `OverflowBits` error occurs.
        pub fn appendInSource(self: *@This(), idx: usize, pair: SrcPair, allocator: std.mem.Allocator) !void {
            // Check that the index isn't zero or over the range.
            if (idx == 0 and idx > self.sources.len - 1) {
                return SrcHandlerError.OutOfRange;
            }

            // Check that the device is attached.
            const is_zero: bool = pair.device_name[0] == '0' and pair.device_name[1] == '0';
            const not_attached = !self.attached_devices.contains(pair.device_name);
            if (not_attached and !is_zero) {
                return SrcHandlerError.NotAttached;
            }

            // Check that the bits do not exceeds the limits of `SizeT`.
            const len: usize = len_blk: {
                var res: usize = 0;
                for (self.sources[idx].items) |src| {
                    res += src.bits;
                }
                break :len_blk res;
            };
            if (len > bits_length) {
                return SrcHandlerError.OverflowBits;
            }

            try self.sources[idx].append(allocator, pair);
        }

        /// Attachs a register to the inputs of the handler.
        /// - `reg`: a pointer to the register. If in the attached devices there is an entry
        ///          sharing the same name, an `AlreadyAttached` error is thrown.
        pub fn attachRegister(self: *@This(), reg: *Register(SizeT)) !void {
            if (self.attached_devices.contains(reg.name))
                return SrcHandlerError.AlreadyAttached;

            try self.attached_devices.put(reg.*.name, &reg.data);
        }

        /// Attachs a parallel adder to the inputs of the handler.
        /// - `addr`: a pointer to the adder. If in the attached devices there is an entry
        ///          sharing the same name, an `AlreadyAttached` error is thrown.
        pub fn attachParallelAdder(self: *@This(), addr: *ParallelAdder(SizeT)) !void {
            if (self.attached_devices.contains(addr.name))
                return SrcHandlerError.AlreadyAttached;

            try self.attached_devices.put(addr.name, &addr.sum);
        }

        /// Initializes an instance, setting the first virtual source (e0)
        /// as the special fixed value returing always zero.
        pub fn init(allocator: std.mem.Allocator) !@This() {
            var source_handler = @This(){ .attached_devices = .init(allocator) };

            // Initialize the sources, setting the first one always to the
            // special pair zero.
            for (0..src_num) |idx| {
                source_handler.sources[idx] = std.ArrayList(SrcPair).empty;
            }

            const zero_pair = SrcPair{ .device_name = device_zero_name, .bits = bits_length };
            try source_handler.sources[0].append(allocator, zero_pair);

            return source_handler;
        }

        /// Clears all occupied memory within the instance.
        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.attached_devices.deinit();

            for (0..src_num) |idx| {
                self.sources[idx].deinit(allocator);
            }
        }

        /// Returns the mask obtained by setting bits from `start_pos` to `start_pos + len` (ordered from msb to lsb).
        /// It is used by `sourceValue` to identify the bit-range associated to a particular device.
        fn computeMask(start_pos: usize, len: usize) !SizeT {
            // Check that the passed parameters are not ouside
            // the range of `SizeT`.
            // E.g. if SizeT = u4, then `start_pos` and `len` should
            // not be greater than 4
            const type_len = bits_length;
            if (start_pos > type_len or
                start_pos + len > type_len)
                return SrcHandlerError.OutOfRange;

            var mask: SizeT = 0;
            for (0..len) |i| {
                const pow = type_len - (start_pos + i + 1);
                mask |= @as(SizeT, 1) << @truncate(pow);
            }
            return mask;
        }

        /// Returns the value of the source at index `idx`.
        pub fn srcValue(self: @This(), idx: usize) !SizeT {
            const device_list: std.ArrayList(SrcPair) = self.sources[idx];

            var res: SizeT = 0;
            var pos: usize = 0;

            for (device_list.items) |device| {
                const is_zero: bool = device.device_name[0] == '0' and device.device_name[1] == '0';
                if (!is_zero) {
                    const mask = try computeMask(pos, device.bits);
                    const raw_content: SizeT = self.attached_devices.get(device.device_name).?.*;
                    const to_copy: SizeT = raw_content & mask;
                    res |= to_copy;
                }
                pos += device.bits;
            }

            return res;
        }
    };
}

// =============================== TESTS ==================================

const debug_allocator = std.testing.allocator;

test "srcValue" {
    // Construct the common SrcHandler for all our tests.
    // - Number type: u4.
    // - Attached devices:
    //      * A (reg)  ; data = 0b1010
    //      * B (reg)  ; data = 0b1100
    //      * AD(addr) ; data = 0b1101
    // - sources: there are four sources
    //      * e0 = 0 0 0 0     = [ ("00", 4)             ]
    //      * e1 = a1 a2 a3 a4 = [ ("A ", 4)             ]
    //      * e2 = a1 a2 b3 b4 = [ ("A ", 2) ; ("B", 2)  ]
    //      * e3 = d1 d2 d3 0  = [ ("AD", 3) ; ("00", 1) ]
    const FourBitReg = Register(u4);
    const FourBitAdder = ParallelAdder(u4);

    var reg_a = FourBitReg.init(@constCast("A")) catch unreachable;
    reg_a.data = 0b1010;

    var reg_b = FourBitReg.init(@constCast("B")) catch unreachable;
    reg_b.data = 0b1100;

    var addr_ad = FourBitAdder.init(@constCast("AD")) catch unreachable;
    addr_ad.sum = 0b1101;

    const FourBitSrcHandler = SrcHandler(4, u4);
    var dummy_handler = FourBitSrcHandler.init(debug_allocator) catch unreachable;
    defer dummy_handler.deinit(debug_allocator);

    dummy_handler.attachRegister(&reg_a) catch unreachable;
    dummy_handler.attachRegister(&reg_b) catch unreachable;
    dummy_handler.attachParallelAdder(&addr_ad) catch unreachable;

    try dummy_handler.appendInSource(1, FourBitSrcHandler.SrcPair{ .device_name = reg_a.name, .bits = 4 }, debug_allocator);

    try dummy_handler.appendInSource(2, FourBitSrcHandler.SrcPair{ .device_name = reg_a.name, .bits = 2 }, debug_allocator);
    try dummy_handler.appendInSource(2, FourBitSrcHandler.SrcPair{ .device_name = reg_b.name, .bits = 2 }, debug_allocator);

    try dummy_handler.appendInSource(3, FourBitSrcHandler.SrcPair{ .device_name = addr_ad.name, .bits = 3 }, debug_allocator);
    try dummy_handler.appendInSource(3, FourBitSrcHandler.SrcPair{ .device_name = FourBitSrcHandler.device_zero_name, .bits = 1 }, debug_allocator);

    // Try to retrive e0 = d1 d2 d3 0 = [ ("AD", 3) ; ("00", 1) ]
    // It should return value: 0b0000
    const e0_val = dummy_handler.srcValue(0);
    try expectEqual(0, e0_val);

    // Try to retrieve e1 = a1 a2 a3 a4 = [ ("A ", 4) ]
    // It should return value: 0b1010
    const e1_val = dummy_handler.srcValue(1);
    try expectEqual(0b1010, e1_val);

    // Try to retrieve e2 = a1 a2 b3 b4 =  [ ("A ", 2) ; ("B", 2) ]
    // It should return value: 0b1000
    const e2_val = dummy_handler.srcValue(2);
    try expectEqual(0b1000, e2_val);

    // Try to retrieve e3 = d1 d2 d3 0 =  [ ("AD", 3) ; ("00", 1) ]
    // It should return value: 0b1100
    const e3_val = dummy_handler.srcValue(3);
    try expectEqual(0b1100, e3_val);
}

test "computeMask" {
    // Create a mask of four bits s.t. the starting position is 0
    // and the length is 2.
    // The generated mask should be: 0b1100
    const FourBitSrcHandler = SrcHandler(5, u4);
    const fst_mask: u4 = FourBitSrcHandler.computeMask(0, 2) catch unreachable;
    try expectEqual(0b1100, fst_mask);

    // Create a mask of 36-bits s.t. the starting position is 15
    // and the length is 15.
    // The generated mask should be: 0b000000000000000111111111111111000000
    const WordSrcHandler = SrcHandler(5, CepSizesT.WorldT);
    const snd_mask: CepSizesT.WorldT = WordSrcHandler.computeMask(15, 15) catch unreachable;
    try expectEqual(0b000000000000000111111111111111000000, snd_mask);

    // Create a mask of 15-bits s.t. the starting position is 0 and the length is 0.
    // The generated mask should be: 0b000000000000000
    const AddressSrcHandler = SrcHandler(5, CepSizesT.AddressT);
    const thrd_mask: CepSizesT.AddressT = AddressSrcHandler.computeMask(0, 0) catch unreachable;
    try expectEqual(0, thrd_mask);

    // Try to create a mask of 15-bits s.t. the starting position is 16 and the length is 2.
    // The mask should not be generated, instead an `OutOfRange` error should occur.
    try expectError(SrcHandlerError.OutOfRange, AddressSrcHandler.computeMask(15, 2));

    // Try to create a mask of 36-bits s.t. the starting position is 3 and the length 13.
    // The mask should not be generated, instead an `OutOfRange` error should occur.
    try expectError(SrcHandlerError.OutOfRange, AddressSrcHandler.computeMask(3, 13));
}
