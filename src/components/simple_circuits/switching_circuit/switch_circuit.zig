//! This file defines a Switching Circuit, i.e. an object
//! which receives data in input and according to the current
//! value of the selection lines and its logic computes an output.

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const Device = @import("utils").Device;
const SelectLine = @import("selection_line.zig").SelectionLine;
const MaskUtilsT = @import("utils").MaskUtils;

const SwitchCircuitError = error{ InvalidName, OutOfRange, NotAttached, AlreadyAttached, OverflowBits };

/// A component which transmits some inputs, coming from attached sources,
/// to a single output.
///
/// A switching circuit is attached to one or more input components (usually
/// registers, parallel adders or mixture of both). For each input, a selection line is associated,
/// which determines the content preserved when said source is passed in output.
///
/// A switching circuit does not hold data, rather it routes content depending
/// on its custom logic. The action applied at each cycle depends on the current
/// selection lines' groups being activated.
///
/// To define a specialization of Switching Circuit the following parameters are requested:
/// - `SizeT`: the type of the content hold by the inputs. This is usually an unsigned integer interpreted
///            as a bit sequence.
///
/// - `dev_num`: the cardinality of physical devices attached to the instance.
///
/// - `src_num`: the cardinality of virtual sources attached to the handler. This value is fixed from the
///              start and does not consider the default source e0 (i.e. the one pointing to the constant zero).
///              This means that the true cardinality of virtual sources is `src_num + 1`.
///
/// The generated struct has the following fields:
/// - `name`: identifies the instance. Usually switching circuits have a two-letter name all in caps, with
///           the first letter always being a `K` and the second being the name of the device attacched to
///           its output (e.g. "KB" is the name of the switching circuit determining the new value of register
///           `B`).
///
/// - `output`: contains the value computed on the last cycle.
///
/// - `devices`: an array of Device instances.
///
/// - `virtual_srcs`: an array of abstract inputs, obtained by mixing the content of real attached devices.
///                   An entry is a list of pairs in the form <dev_idx, mask> where
///     * `dev_idx`: the index in `devices` of the associated Device.
///     * `mask`: the portion of content requested from the device.
///
/// - `select_lines: an array of select_lines. Each member determines portion of the associated virtual source should be picked.
///                  Note that, while the default virtual source e0 is alway initialized, its associated selection line must
///                  be defined manually.
pub fn SwitchCircuit(comptime SizeT: type, comptime dev_num: usize, comptime src_num: usize) type {
    return struct {
        /// the true number of virtual soruces attacched. It counts the default source e0 providing the constant zero.
        const total_srcs = src_num + 1;
        const bits_length = @typeInfo(SizeT).int.bits;

        name: [2]u8 = undefined,
        _output: SizeT = 0,

        devices: [dev_num]Device(SizeT) = undefined,
        select_lines: [total_srcs]SelectLine(SizeT) = undefined,
        virtual_sources: [total_srcs]std.ArrayList(DevPortion) = undefined,
        // Represents a portion of data coming from a physical device:
        // - `idx`: the index in `devices` of the device.
        // - `mask`: the content to copy, represented as a bit-mask.
        // - `negated`: if the retrieved content should be negated before returned or not.
        const DevPortion = struct {
            idx: usize = undefined,
            mask: SizeT = undefined,
            negated: bool = undefined,
        };

        /// Initializes an empty instance having the default virtual source e0 already set.
        pub fn init(name: []u8) !@This() {
            if (name.len != 2) {
                return SwitchCircuitError.InvalidName;
            }
            const conv_name = [2]u8{ name[0], name[1] };

            var in_hdl = SwitchCircuit(SizeT, dev_num, src_num){
                .name = conv_name,
            };
            for (0..total_srcs) |idx| {
                in_hdl.virtual_sources[idx] = .empty;
                in_hdl.select_lines[idx] = .init();
            }
            return in_hdl;
        }

        /// Clear the memory occupied by the instance.
        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) !void {
            for (0..total_srcs) |idx| {
                self.virtual_sources[idx].deinit(allocator);
                try self.select_lines[idx].deinit(allocator);
            }
        }

        /// Returns the portion of content of the idx-th virtual source, selected
        /// according to the current value of the associated selection line.
        fn srcValue(self: @This(), idx: usize) !SizeT {
            if (idx >= total_srcs) {
                return SwitchCircuitError.OutOfRange;
            }

            // Retrieve the raw content of the virtual source
            var raw_data: SizeT = 0;
            var curr_pos: isize = 0;

            const src = self.virtual_sources[idx];
            for (src.items) |mem| {
                const content = c_blk: {
                    const temp_cont = self.devices[mem.idx].getData() & mem.mask;
                    break :c_blk if (!mem.negated) temp_cont else ~temp_cont;
                };

                // Copy the content and the correct position
                const pos_content = MaskUtilsT(SizeT).fstSetPos(mem.mask);
                if (pos_content == null) break;
                const shift_amt: isize = curr_pos - pos_content.?;
                const positioned_content = if (shift_amt > 0) content >> @intCast(@abs(shift_amt)) else content << @intCast(@abs(shift_amt));
                raw_data = if (!mem.negated) raw_data | positioned_content else raw_data & positioned_content;

                // Update
                curr_pos += MaskUtilsT(SizeT).bitsSet(mem.mask);
            }

            // Return only the portions of the raw content being selected
            // by the associated select line.
            const res = raw_data & self.select_lines[idx].value();
            return res;
        }

        /// Sets the current `output` of the instance.
        /// The produced value is obtained by merging the content
        /// coming from each source according to how their selection
        /// lines are set.
        pub fn computeOutput(self: *@This()) !void {
            var res: SizeT = 0;
            var prev_mask: SizeT = 0;
            for (0..total_srcs) |idx| {
                const preserve_mask = ~self.select_lines[idx].value() | prev_mask;
                const kept = res & preserve_mask;
                const portion = blk: {
                    const src_val = try self.srcValue(idx);
                    break :blk src_val & ~preserve_mask;
                };

                res = portion | kept;
                prev_mask = self.select_lines[idx].value();
            }
            self._output = res;
        }

        /// Returns the entry as a device
        pub fn asDevice(self: *@This()) Device(SizeT) {
            return .{ ._name = &self.name, ._data = &self._output };
        }
    };
}

// =============================== TESTS ==================================

const debug_allocator = std.testing.allocator;

test "srcValue_1" {
    // In this test the select lines are always fully set (i.e. all
    // the content is always retrieved).
    // - Number type: u4.
    // - Attached (dummy) devices (# = 3):
    //      * A  : data = 0b1010
    //      * B  : data = 0b1100
    //      * AD : data = 0b1101
    // - virtual sources (# = 4):
    //      * e0 = 0 0 0 0     = [                                          ]  ⚠︎ This is initialized automatically by the `init` method.
    //      * e1 = a1 a2 a3 a4 = [ (0 , 0b1111, false)                      ]
    //      * e2 = a1 a2 b3 b4 = [ (0 , 0b1100, false) ; (1, 0b0011, false) ]
    //      * e3 = d1 d2 d3 0  = [ (2 , 0b1110, false)                      ]
    // - selection lines (# = 4):
    //      * ξ_0 = [ ξ_0(0,1,2,3) = 0b1111 ]   value = 0b1111
    //      * ξ_1 = [ ξ_1(0,1,2,3) = 0b1111 ]   value = 0b1111
    //      * ξ_2 = [ ξ_2(0,1,2,3) = 0b1111 ]   value = 0b1111
    //      * ξ_3 = [ ξ_3(0,1,2,3) = 0b1111 ]   value = 0b1111
    //

    var sw = try SwitchCircuit(u4, 3, 3).init(@constCast("KA"));
    defer sw.deinit(debug_allocator) catch unreachable;

    sw.devices[0] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', ' ' }),
        ._data = @constCast(&@as(u4, 0b1010)),
    };
    sw.devices[1] = Device(u4){
        ._name = @constCast(&[2]u8{ 'B', ' ' }),
        ._data = @constCast(&@as(u4, 0b1100)),
    };
    sw.devices[2] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', 'D' }),
        ._data = @constCast(&@as(u4, 0b1101)),
    };

    //      * ξ_0 = [ ξ_0(0,1,2,3) = 0b1111 ]   value = 0b1111
    sw.select_lines[0].addGroup(debug_allocator, 0b1111) catch unreachable;
    sw.select_lines[0].setGroup(0) catch unreachable;

    //      * e1 = a1 a2 a3 a4 = [ (0 , 0b1111)               ]
    //      * ξ_1 = [ ξ_1(0,1,2,3) = 0b1111 ]   value = 0b1111
    sw.virtual_sources[1].append(debug_allocator, .{ .idx = 0, .mask = 0b1111 }) catch unreachable;
    sw.select_lines[1].addGroup(debug_allocator, 0b1111) catch unreachable;
    sw.select_lines[1].setGroup(0) catch unreachable;

    //      * e2 = a1 a2 b3 b4 = [ (0 , 0b1100) ; (1, 0b0011) ]
    //      * ξ_2 = [ ξ_2(0,1,2,3) = 0b1111 ]   value = 0b1111
    sw.virtual_sources[2].append(debug_allocator, .{ .idx = 0, .mask = 0b1100, .negated = false }) catch unreachable;
    sw.virtual_sources[2].append(debug_allocator, .{ .idx = 1, .mask = 0b0011, .negated = false }) catch unreachable;
    sw.select_lines[2].addGroup(debug_allocator, 0b1111) catch unreachable;
    sw.select_lines[2].setGroup(0) catch unreachable;

    //      * e3 = d1 d2 d3 0  = [ (2 , 0b1110) ]
    //      * ξ_3 = [ ξ_3(0,1,2,3) = 0b1111 ]   value = 0b1111
    sw.virtual_sources[3].append(debug_allocator, .{ .idx = 2, .mask = 0b1110, .negated = false }) catch unreachable;
    sw.select_lines[3].addGroup(debug_allocator, 0b1111) catch unreachable;
    sw.select_lines[3].setGroup(0) catch unreachable;

    // Try to retrive e0 = 0 0 0 0  line = 0b1111
    // It should return value: 0b0000
    const e0_val = try sw.srcValue(0);
    expectEqual(0, e0_val) catch unreachable;

    // Try to retrieve e1 = a1 a2 a3 a4 line = 0b1111
    // It should return value: 0b1010
    const e1_val = try sw.srcValue(1);
    expectEqual(0b1010, e1_val) catch unreachable;

    // Try to retrieve e2 = a1 a2 b3 b4 line = 0b1111
    // It should return value: 0b1000
    const e2_val = try sw.srcValue(2);
    expectEqual(0b1000, e2_val) catch unreachable;

    // Try to retrieve e3 = d1 d2 d3 0 line = 0b1111
    // It should return value: 0b1100
    const e3_val = try sw.srcValue(3);
    expectEqual(0b1100, e3_val) catch unreachable;
}

test "srcValue_2" {
    // In this test we define more complex select lines to see
    // them in action.
    // - Number type: u4.
    // - Attached (dummy) devices (#3):
    //      * A : data = 0b1010
    //      * B : data = 0b1100
    //      * C : data = 0b1101
    // - virtual sources (# = 4):
    //      * e0 = 0 0 0 0     = [                                          ]  ⚠︎ This is initialized automatically by the `init` method.
    //      * e1 = a1 a2 a3 a4 = [ (0 , 0b1111, false)                      ]
    //      * e2 = a1 a2 b3 b4 = [ (0 , 0b1100, false) ; (1, 0b0011. false) ]
    //      * e3 = d1 d2 d3 0  = [ (2 , 0b1110, false)                      ]
    // - selection lines (# = 4):
    //      * ξ_0 = [ ξ(0-1) = 0b1100  ; ξ(2-3) = 0b0011                                ] value = ξ(0,1) = 0b1100
    //      * ξ_1 = [ ξ(0-2) = 0b1110  ; ξ(3)   = 0b0001                                ] value = ξ(3) = 0b0001
    //      * ξ_2 = [ ξ(0) = 0b1000    ; ξ(1)   = 0b0100 ; ξ(2) = 0b0010; ξ(3) = 0b0001 ] value = ξ(0)ξ(1)ξ(2)ξ(3) = 0b1111
    //      * ξ_3 = [ ξ(0, 3) = 0b1001 ; ξ(1)   = 0b0100 ; ξ(2) = 0b0010                ] value = ξ(0, 3)ξ(2) = 0b1011
    //
    // The produced value should be:
    // - value (e0) = 0b0000
    // - value (e1) = 0b0000
    // - value (e2) = 0b1000
    // - value (e3) = 0b1000

    var sw = try SwitchCircuit(u4, 3, 3).init(@constCast("KA"));
    defer sw.deinit(debug_allocator) catch unreachable;

    sw.devices[0] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', ' ' }),
        ._data = @constCast(&@as(u4, 0b1010)),
    };
    sw.devices[1] = Device(u4){
        ._name = @constCast(&[2]u8{ 'B', ' ' }),
        ._data = @constCast(&@as(u4, 0b1100)),
    };
    sw.devices[2] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', 'D' }),
        ._data = @constCast(&@as(u4, 0b1101)),
    };

    //      * ξ_0 = [ ξ(0-1) = 0b1100  ; ξ(2-3) = 0b0011                                ] value = ξ(0,1) = 0b1100
    try sw.select_lines[0].addGroup(debug_allocator, 0b1100);
    try sw.select_lines[0].addGroup(debug_allocator, 0b0011);
    try sw.select_lines[0].setGroup(0);

    //      * e1 = a1 a2 a3 a4 = [ (0 , 0b1111)               ]
    //      * ξ_1 = [ ξ(0-2) = 0b1110  ; ξ(3)   = 0b0001                                ] value = ξ(3) = 0b0001
    try sw.virtual_sources[1].append(debug_allocator, .{ .idx = 0, .mask = 0b1111 });
    try sw.select_lines[1].addGroup(debug_allocator, 0b1110);
    try sw.select_lines[1].addGroup(debug_allocator, 0b0001);
    try sw.select_lines[1].setGroup(1);

    //      * e2 = a1 a2 b3 b4 = [ (0 , 0b1100) ; (1, 0b0011) ]
    //      * ξ_2 = [ ξ(0) = 0b1000    ; ξ(1)   = 0b0100 ; ξ(2) = 0b0010; ξ(3) = 0b0001 ] value = ξ(0)ξ(1)ξ(2)ξ(3) = 0b1111
    try sw.virtual_sources[2].append(debug_allocator, .{ .idx = 0, .mask = 0b1100 });
    try sw.virtual_sources[2].append(debug_allocator, .{ .idx = 1, .mask = 0b0011 });
    try sw.select_lines[2].addGroup(debug_allocator, 0b1000);
    try sw.select_lines[2].addGroup(debug_allocator, 0b0100);
    try sw.select_lines[2].addGroup(debug_allocator, 0b0010);
    try sw.select_lines[2].addGroup(debug_allocator, 0b0001);
    try sw.select_lines[2].setGroup(0);
    try sw.select_lines[2].setGroup(1);
    try sw.select_lines[2].setGroup(2);
    try sw.select_lines[2].setGroup(3);

    //      * e3 = d1 d2 d3 0  = [ (2 , 0b1110) ]
    //      * ξ_3 = [ ξ(0, 3) = 0b1001 ; ξ(1)   = 0b0100 ; ξ(2) = 0b0010                ] value = ξ(0, 3)ξ(2) = 0b1011
    try sw.virtual_sources[3].append(debug_allocator, .{ .idx = 2, .mask = 0b1110 });
    try sw.select_lines[3].addGroup(debug_allocator, 0b1001);
    try sw.select_lines[3].addGroup(debug_allocator, 0b0100);
    try sw.select_lines[3].addGroup(debug_allocator, 0b0010);
    try sw.select_lines[3].setGroup(0);
    try sw.select_lines[3].setGroup(2);

    // - value (e0) = 0b0000
    const e0_val = try sw.srcValue(0);
    try expectEqual(0b0000, e0_val);

    // - value (e1) = 0b0000
    const e1_val = try sw.srcValue(1);
    try expectEqual(0b0000, e1_val);

    // - value (e2) = 0b1000
    const e2_val = try sw.srcValue(2);
    try expectEqual(0b1000, e2_val);

    // - value (e3) = 0b1000
    const e3_val = try sw.srcValue(3);
    try expectEqual(0b1000, e3_val);
}

test "srcValue3" {
    // - Number type = u4
    // - Attached (dummy) devices (#3):
    //      * A  : data = 0b1110
    //      * B  : data = 0b1000
    //      * AD : data = 0b0010
    // - virtual sources (# = 3):
    //      * e0 =   0   0  0    0   = [                                         ]
    //      * e1 = ~(a0) d0 d1   d2  = [ (0, 0b1000, true)  ; (2, 0b1110, false) ]
    //      * e2 =   b1  b2 b3 ~(a0) = [ (1, 0b0111, false) ; (0, 0b1000, true ) ]
    // - selection lines (# = 3):
    //      * ξ_0 = [ ξ_0(0-3) = 0b1111 ]
    //      * ξ_1 = [ ξ_1(0-3) = 0b1111 ]
    //      * ξ_2 = [ ξ_2(0-3) = 0b1111 ]
    // Selection lines are assumed to be activated!
    //
    // The produced values should be:
    // - value (e1) = 0b0001
    // - value (e2) = 0b0000

    var sw = try SwitchCircuit(u4, 3, 3).init(@constCast("KA"));
    defer sw.deinit(debug_allocator) catch unreachable;

    sw.devices[0] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', ' ' }),
        ._data = @constCast(&@as(u4, 0b1110)),
    };
    sw.devices[1] = Device(u4){
        ._name = @constCast(&[2]u8{ 'B', ' ' }),
        ._data = @constCast(&@as(u4, 0b1000)),
    };
    sw.devices[2] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', 'D' }),
        ._data = @constCast(&@as(u4, 0b0010)),
    };

    //      * ξ_0 = [ ξ_0(0-3) ]
    try sw.select_lines[0].addGroup(debug_allocator, 0b1111);

    //      * e1 = ~(a0) d0 d1   d2  = [ (0, 0b1000, true)  ; (2, 0b1110, false) ]
    //      * ξ_1 = [ ξ_1(0-3) = 0b1111 ]
    try sw.virtual_sources[1].append(debug_allocator, .{ .idx = 0, .mask = 0b1000, .negated = true });
    try sw.virtual_sources[1].append(debug_allocator, .{ .idx = 2, .mask = 0b1110, .negated = false });
    try sw.select_lines[1].addGroup(debug_allocator, 0b1111);
    try sw.select_lines[1].setGroup(0);

    //      * e2 =   b1  b2 b3 ~(a0) = [ (1, 0b0111, false) ; (0, 0b1000, true ) ]
    //      * ξ_2 = [ ξ_2(0-3) = 0b1111 ]
    try sw.virtual_sources[2].append(debug_allocator, .{ .idx = 1, .mask = 0b0111, .negated = false });
    try sw.virtual_sources[2].append(debug_allocator, .{ .idx = 0, .mask = 0b1000, .negated = true });

    // Try to retrieve e1 = ~(a0) d0 d1 d2  line = 0b1111
    // It should return value: 0b0001
    const e1_val = try sw.srcValue(1);
    try expectEqual(0b0001, e1_val);

    // Try to retrieve e2 = b1  b2 b3 ~(a0) line = 0b1111
    // It should return value: 0b0000
    const e2_val = try sw.srcValue(2);
    try expectEqual(0b0000, e2_val);
}

test "computeOutput" {
    // - Number type: u4.
    // - Attached (dummy) devices (# = 1):
    //      * A : data = 0b1010
    // - virtual sources (# = 2):
    //      * e0 = 0  0  0  0  = [              ]
    //      * e1 = a1 a2 a3 a4 = [ (0 , 0b1111) ]
    // - selection lines (# = 4):
    //      * ξ_0 = [ ξ_0(0) = 0b1000 ; ξ_0(1,2) = 0b0110 ; ξ_0(3) = 0b0001 ] value = 0b1000
    //      * ξ_1 = [ ξ_1(0,1,2,3)                                          ] value = 0b1111
    //
    // The produced value should be:
    // - computeOutput() = 0b  0       010
    //                         ^        ^
    //                      from e0  from e1

    var sw = try SwitchCircuit(u4, 1, 1).init(@constCast("KA"));
    defer sw.deinit(debug_allocator) catch unreachable;

    sw.devices[0] = Device(u4){
        ._name = @constCast(&[2]u8{ 'A', ' ' }),
        ._data = @constCast(&@as(u4, 0b1010)),
    };

    //      * ξ_0 = [ ξ_0(0) = 0b1000 ; ξ_0(1,2) = 0b0110 ; ξ_0(3) = 0b0001 ] value = 0b1000
    try sw.select_lines[0].addGroup(debug_allocator, 0b1000);
    try sw.select_lines[0].addGroup(debug_allocator, 0b0110);
    try sw.select_lines[0].addGroup(debug_allocator, 0b0001);
    try sw.select_lines[0].setGroup(0);

    //      * e1 = a1 a2 a3 a4 = [ (0 , 0b1111) ]
    //      * ξ_1 = [ ξ_1(0,1,2,3)                                          ] value = 0b1111
    try sw.virtual_sources[1].append(debug_allocator, .{ .idx = 0, .mask = 0b1111 });
    try sw.select_lines[1].addGroup(debug_allocator, 0b1111);
    try sw.select_lines[1].setGroup(0);

    // The produced value should be:
    // - computeOutput() = 0b  0       010
    //                         ^        ^
    //                      from e0  from e1
    try sw.computeOutput();
    try expectEqual(0b0010, sw._output);
}
