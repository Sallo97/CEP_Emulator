//! A selection line is a sequence of bits activating portions of
//! a source.

const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const SelectionLineError = error{ OutOfRange, GroupsIntersection };

/// A Selection Line is always associated to a (virtual) input.
/// The bits set in the line acts as a mask, retrieving the matching
/// content in the input.
///
/// A selection group is a set of bits within the line which all share
/// the same value.
///
/// A Selection Line is abstracted as a ordered list of selection groups.
/// Instead of letting the user manually set the value of the line, it
/// sets the groups.
///
/// To define a specialization of SelectionLine, the following parameters are requested:
/// - `SizeT`: the raw content of the selection line, divided into selection groups. Usually an
///            unsigned integer interpreted as a bit sequence.
///
/// The generated instance has the following fields:
/// - `groups`: an ordered list of selection groups. Each group must
///             be mutually exclusive with all the others.
///
/// - `value`: the current value of the selection line
pub fn SelectionLine(SizeT: type) type {
    return struct {
        const SelectionGroup = SizeT;
        groups: std.ArrayList(SelectionGroup) = undefined,
        _value: SizeT = 0,

        /// Returns a new instance having no `groups` and `value` set to zero.
        pub fn init() @This() {
            return @This(){
                .groups = std.ArrayList(SelectionGroup).empty,
            };
        }

        /// Clears all the memory occupied by the instance
        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) !void {
            self.groups.deinit(allocator);
        }

        /// Returns the value of the selection line
        pub fn value(self: @This()) SizeT {
            return self._value;
        }

        /// Zeroes the value of the instance.
        pub fn clearValue(self: *@This()) void {
            self._value = 0;
        }

        // Appends the `candidate` group as the last one. If the group has members in common
        // with another one already in the instance, an `GroupsIntersection` error
        // is thrown and the group is not inserted.
        pub fn addGroup(self: *@This(), allocator: std.mem.Allocator, candidate: SizeT) !void {
            for (self.groups.items) |member| {
                const intersection = member & candidate;
                if (intersection > 0) {
                    return SelectionLineError.GroupsIntersection;
                }
            }
            try self.groups.append(allocator, candidate);
        }

        /// Updates the value by setting in it to one all the bits
        /// of the requested group
        /// - `g_idx`: the index recognizing the selection group.
        pub fn setGroup(self: *@This(), g_idx: usize) !void {
            if (g_idx > self.groups.items.len) return SelectionLineError.OutOfRange;

            const mask: SizeT = self.groups.items[g_idx];
            self._value |= mask;
        }
    };
}

test "init" {
    // Create a new instance and check that is value is zero
    // and it has no groups.
    const dummy_line = SelectionLine(u5).init();
    try expectEqual(0, dummy_line._value);
    try expectEqual(0, dummy_line.groups.items.len);
}

test "addGroup" {
    // Create a new instance and add the group 0b01100
    // groups => [ ]
    var dummy_line = SelectionLine(u5).init();
    defer dummy_line.deinit(std.testing.allocator) catch unreachable;

    // Add group 0b01100
    // pos             0
    // groups => [ (0b01100) ]
    dummy_line.addGroup(std.testing.allocator, 0b01100) catch unreachable;
    expectEqual(0b01100, dummy_line.groups.getLast()) catch unreachable;

    // Add group 0b10000
    // pos             0          1
    // groups => [ (0b01100), (0b10000) ]
    dummy_line.addGroup(std.testing.allocator, 0b10000) catch unreachable;
    expectEqual(0b10000, dummy_line.groups.getLast()) catch unreachable;

    // Try to add group 0b00111
    // pos             0          1
    // groups => [ (0b01100), (0b10000) ]
    //                 ^ => error! There is an intersection with groups[0], `GroupsIntersection` is thrown.
    expectError(SelectionLineError.GroupsIntersection, dummy_line.addGroup(std.testing.allocator, 0b00111)) catch unreachable;

    // Add group 0b00011
    // pos             0           1         2
    // groups => [ (0b01100), (0b10000), (0b00011) ]
    dummy_line.addGroup(std.testing.allocator, 0b00011) catch unreachable;
    expectEqual(0b00011, dummy_line.groups.getLast()) catch unreachable;
}

test "updateValue and clearValue" {
    // Set a new instance having the following status:
    // value => 0
    // pos             0           1         2
    // groups => [ (0b01100), (0b10000), (0b00011) ]
    var dummy_line = SelectionLine(u5).init();
    defer dummy_line.deinit(std.testing.allocator) catch unreachable;
    dummy_line.addGroup(std.testing.allocator, 0b01100) catch unreachable;
    dummy_line.addGroup(std.testing.allocator, 0b10000) catch unreachable;
    dummy_line.addGroup(std.testing.allocator, 0b00011) catch unreachable;

    // value => 0b01100
    dummy_line.setGroup(0) catch unreachable;
    expectEqual(0b01100, dummy_line._value) catch unreachable;

    // value => 0b11100
    dummy_line.setGroup(1) catch unreachable;
    expectEqual(0b11100, dummy_line._value) catch unreachable;

    // value => 0b11111
    dummy_line.setGroup(2) catch unreachable;
    expectEqual(0b11111, dummy_line._value) catch unreachable;

    // value => 0
    dummy_line.clearValue();
    expectEqual(0, dummy_line._value) catch unreachable;
}
