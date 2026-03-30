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

const SwitchError = error{
    InvalidName,
};
const SrcHandlerError = error{ OutOfRange, NotAttached, AlreadyAttached };

/// An object representing the sources coming to a SwitchCircuit.
/// The sources are divided into the physical devices attached to the
/// handler and the abstact values obtained by mixing the content of the
/// connected entities.
///
/// To define a specialization of SourcesHandler the following parameters are requested:
/// - `device_num`: the cardinality of real devices attached to the handler. This value cannot change.
/// - `src_num`: the cardinality of abstract sources attached to the handler. An abstract source is one
///              obtained by mixing the content coming from multiple attached devices.
/// - `SizeT`: the type of the content coming from a device/source. This is usually an unsigned integer interpreted
///            as a bit sequence.
///
/// The generated struct has the following fields:
/// - `attached_devices`: a map between  <device_name, content> in which `device_name` is its namethe `content` refers to the output
///                       of the associated device. It should be read-only.
///
/// - `sources`: the array of abstract sources defined. Each entry is an ordered list of the devices and their range of influence
///              in the content of the source.
fn SrcHandler(comptime src_num: usize, comptime SizeT: type) type {
    return struct {
        /// Represents an abstract source, i.e. a incoming value obtained by mixing the content of
        /// multiple real devices.
        /// - `device_name`: The unique identifier of the device. The special name `00` will refer
        ///                  to the constant zero.
        ///
        /// - `bits`: the number of consecutive bits associated to the device in the source after the positions
        ///           of the previous entries.
        const SrcPair = struct {
            const zero = [2]u8{ '0', '0' };
            device_name: [2]u8,
            bits: usize,
        };

        attached_devices: std.AutoHashMap([2]u8, *SizeT) = undefined,
        sources: [src_num]std.ArrayList(SrcPair) = undefined,

        /// Set the `idx`-th source to the sequences specified by the user.
        pub fn setSource(self: *@This(), idx: usize, list: std.ArrayList(SrcPair)) !void {
            // Check that `idx` is within the cardinality of `sources`.
            if (idx > self.sources.len - 1) {
                return SrcHandlerError.OutOfRange;
            }

            // Check that all devices in `list` are attached
            for (list.items) |srcPair| {
                const is_zero: bool = srcPair.device_name[0] == '0' and srcPair.device_name[1] == '0';
                const not_attached = !self.attached_devices.contains(srcPair.device_name);
                if (not_attached and !is_zero) {
                    return SrcHandlerError.NotAttached;
                }
            }

            self.sources[idx] = list;
        }

        /// Attachs to the devices a register.
        pub fn attachRegister(self: *@This(), reg: *Register(SizeT)) !void {
            if (self.attached_devices.contains(reg.name))
                return SrcHandlerError.AlreadyAttached;

            try self.attached_devices.put(reg.*.name, &reg.data);
        }

        /// Attachs to the device a parallel adder.
        pub fn attachParallelAdder(self: *@This(), addr: *ParallelAdder(SizeT)) !void {
            if (self.attached_devices.contains(addr.name))
                return SrcHandlerError.AlreadyAttached;

            try self.attached_devices.put(addr.name, &addr.sum);
        }

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{ .attached_devices = .init(allocator) };
        }

        pub fn deinit(self: *@This()) void {
            self.attached_devices.deinit();
        }

        /// Returns the bit-mask of SizeT bits, whose bits set to one starts at `start_pos` (numbering from msb to lsb)
        /// and are `len`.
        /// It is by sourceValue to identify the range associated to a particular
        /// device.
        fn computeMask(start_pos: usize, len: usize) !SizeT {
            // Check that the passed parameters are not ouside
            // the range of `SizeT`.
            // E.g. if SizeT = u4, then `start_pos` and `len` should
            // not be greater than 4
            const type_len = @typeInfo(SizeT).int.bits;
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

        /// Returns the value of the idx-th source.
        /// Recall that sources are identified by their position in `sources`, e.g.
        /// source 3 is the one at position sources[3].
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
    var dummy_handler = FourBitSrcHandler.init(std.testing.allocator);
    defer dummy_handler.deinit();

    dummy_handler.attachRegister(&reg_a) catch unreachable;
    dummy_handler.attachRegister(&reg_b) catch unreachable;
    dummy_handler.attachParallelAdder(&addr_ad) catch unreachable;

    var e0: std.ArrayList(FourBitSrcHandler.SrcPair) = .empty;
    defer e0.deinit(std.testing.allocator);
    try e0.append(std.testing.allocator, FourBitSrcHandler.SrcPair{ .device_name = FourBitSrcHandler.SrcPair.zero, .bits = 4 });
    dummy_handler.setSource(0, e0) catch unreachable;

    var e1: std.ArrayList(FourBitSrcHandler.SrcPair) = .empty;
    defer e1.deinit(std.testing.allocator);
    try e1.append(std.testing.allocator, FourBitSrcHandler.SrcPair{ .device_name = reg_a.name, .bits = 4 });
    dummy_handler.setSource(1, e1) catch unreachable;

    var e2: std.ArrayList(FourBitSrcHandler.SrcPair) = .empty;
    defer e2.deinit(std.testing.allocator);
    try e2.append(std.testing.allocator, FourBitSrcHandler.SrcPair{ .device_name = reg_a.name, .bits = 2 });
    try e2.append(std.testing.allocator, FourBitSrcHandler.SrcPair{ .device_name = reg_b.name, .bits = 2 });
    dummy_handler.setSource(2, e2) catch unreachable;

    var e3: std.ArrayList(FourBitSrcHandler.SrcPair) = .empty;
    defer e3.deinit(std.testing.allocator);
    try e3.append(std.testing.allocator, FourBitSrcHandler.SrcPair{ .device_name = addr_ad.name, .bits = 3 });
    try e3.append(std.testing.allocator, FourBitSrcHandler.SrcPair{ .device_name = FourBitSrcHandler.SrcPair.zero, .bits = 1 });
    dummy_handler.setSource(3, e3) catch unreachable;

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

// /// A component which, given some inputs coming from attached sources,
// /// computes a single output depending on some custom logic and selection
// /// lines.
// ///
// /// A switching circuit is attached to one or more input components, which usually
// /// are registers and parallel adders. The actual sources used to determine the output
// /// can be more, obtained by mixing the contents of the attached devices. The number
// /// of input devices is fixed and set by the parameter `input_num`; the number of
// /// actual sources is also fixed.
// /// The number of bits of the inputs' content is fixed and set by the parameter `SizeT`.
// ///
// /// A selection line is an input which will be used by the custom logic of each instance
// /// to decide which source to use and how to use it in producing the output. The number
// /// of bits of all selection lines is fixed and set by the parameter `SizeT`.
// ///
// /// Selection lines are divided into groups. Each member of a group is a single
// /// bit which must share the same value as all other participants. The number of
// /// groups is not always the same between selection lines, i.e. different selection
// /// lines have different number of groups.
// ///
// /// A switching circuit does not hold data, rather it routes content depending
// /// on its custom logic. The action applied at each cycle depends on the current
// /// selection lines' groups being activated.
// /// The logic is custom to each instance, so an user needs to provide it in the
// /// form of a function taking as input the `input_devices` and `select_groups` fields
// /// and returning the sequence of bits (which has length `SizeT`) being produced as output.
// ///
// /// The parameter requested to create a custom SwitchingCircuit type are:
// /// - `SizeT`: specifies the number of bits of each content within the instance.
// ///
// /// - `input_num`: the cardinality of real devices attached to the instance.
// ///
// /// - `select_num`: the cardinality of virtual sources (i.e. inputs which can be obtained by mixing
// ///                 the content of multiple attached devices), which is equivalent to the number
// ///                 of selection lines.
// ///
// /// The fields of the generated type are:
// /// - `name`: identifies the instance. Usually switching circuits have a two-letter name in caps, with
// ///           the first always being a `K` and the second being the name of the device which will received
// ///           the output (e.g. "KB" is the name of the switching circuit determining the new value of reg-
// ///           ister "B").
// ///
// /// - `attached_inputs`: A list of pointers representing the devices (i.e. either registers and adders),
// ///                      connected as inputs to the instance. The list is an HashMap where each entry has
// ///                      as key the name of the device and as value the pointer to the data of the device
// ///                      (in the case of register what they are holding, in the case of a parallel adder
// ///                      the result of the last addition it had done).
// ///                      The sources are fixed at the initializaton of the instanche and must not change
// ///                      during execution.
// ///
// /// - `select_groups`: an array containing for each selection line the list of groups defined withing. A group
// ///                    is interpreted as a bitmask, which identifies the bits in common. When working with a group
// ///                    extra care must be taken to check that all members have the same boolean value.
// ///
// /// - `logic_fun`: a pointer to the function implementing the logic of the instance. This function must take as input
// ///                the `attached_inputs` and `select_groups` field of the instance, and return as output a bit sequence
// ///                of length `SizeT`.
// pub fn SwitchingCircuit(
//     comptime SizeT: type,
//     comptime input_num: usize,
//     comptime select_num: usize,
// ) type {
//     return struct {
//         name: [2]u8 = undefined,
//         select_groups: [select_num]std.ArrayList(SizeT) = undefined,

//         /// Initialize an instanche of the custom made switching circuit, having only defined
//         /// its name.
//         /// - `name`: the name of the instance.
//         /// - `allocator`: used to initialized `attached_inputs`.
//         pub fn init(name: []u8, allocator: std.mem.Allocator) !@This() {
//             if (name.len != 2) {
//                 return SwitchError.InvalidName;
//             }

//             const conv_name = [2]u8{ name[0], name[1] };

//             const sw = @This(){
//                 .name = conv_name,
//                 .attached_inputs = .init(allocator),
//             };
//             return sw;
//         }

//         /// Adds a register to the list of input devices.
//         pub fn attachRegister(self: *@This(), reg: *Register(SizeT)) !void {
//             const reg_name: [2]u8 = [2]u8{ reg.name[0], reg.name[1] };
//             try self.attached_inputs.put(reg_name, &reg.data);
//         }

//         /// Adds a register to the list of input devices.
//         pub fn attachAdder(self: *@This(), addr: *ParallelAdder(SizeT)) !void {
//             const addr_name: [2]u8 = [2]u8{ addr.name[0], addr.name[1] };
//             try self.attached_inputs.put(addr_name, &addr.sum);
//         }

//         /// Frees up used heap memory.
//         pub fn deinit(
//             self: *@This(),
//         ) void {
//             self.attached_inputs.deinit();
//         }

//         /// Returns the content of the attached device of the given name
//         /// If there isn't an attached device with the given name, the
//         /// `NotAttached` error is raised.
//         pub fn getInputContent(self: @This(), device_name: [2]u8) !SizeT {
//             const ptr = self.attached_inputs.get(device_name);
//             return if (ptr) |value| value.* else SwitchError.NotAttached;
//         }
//     };
// }
