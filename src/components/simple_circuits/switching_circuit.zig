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
const SrcHandler = @import("./src_handler.zig").SrcHandler;

const SwitchError = error{
    InvalidName,
};

// /// A component which, given some inputs coming from attached sources,
// /// computes a single output depending on some custom logic and selection
// /// lines.
// ///
// /// A switching circuit is attached to one or more input components, which usually
// /// are registers and parallel adders. These components can be mixed to provide
// /// more inputs than the actual number of attached devices. The management of the
// /// incoming information is handled by the struct `SrcHandler`.
// /// An instance has always the first entry (e0) set to zero.
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
//     comptime : usize,
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
