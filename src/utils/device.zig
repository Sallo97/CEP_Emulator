//! An entity abstracting an hardware component.

const std = @import("std");

/// A device abstracts an hardware components. This instance reprents how
/// an external device is seen by another one when attached.
/// It holds only the basic informations of the device:
/// - its identifier.
/// - its content.
pub fn Device(comptime SizeT: type) type {
    return struct {

        // Private fields. Direct usage is discouraged, instead
        // access them using the available public functions.
        _name: *[2]u8,
        _data: *SizeT,

        pub fn init(name: *[2]u8, data: *SizeT) @This() {
            return @This(){
                ._data = data,
                ._name = name,
            };
        }

        pub fn getData(self: @This()) SizeT {
            return self._data.*;
        }

        pub fn getName(self: @This()) [2]u8 {
            return self._name.*;
        }

        pub fn format(
            self: @This(),
            writer: *std.Io.Writer,
        ) std.Io.Writer.Error!void {
            try writer.print("[{s}] = {b}", .{ self._name.*, self._data.* });
        }
    };
}

// Defines a writer to the standard error, which is used for testing the `format` function.
var stderr_buffer: [1024]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buffer);
const stderr = &stderr_writer.interface;
