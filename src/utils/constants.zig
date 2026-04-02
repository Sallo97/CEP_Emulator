//! This file holds all the constants of the project

/// A struct holding the various sizes types in the CEP.
/// These have now names according to their usages
/// within the computer.
pub const CepSizesT = struct {
    pub const WorldT = u36;
    pub const AddressT = u15;
    pub const MicroOpT = u8;
    pub const FlagT = u1;
};
