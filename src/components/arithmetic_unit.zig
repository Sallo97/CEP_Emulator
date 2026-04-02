//! This file defines the Arithmetic Unit, i.e. the region
//! of the computer dedicate in handling arithmetic operations.

const std = @import("std");

const Register = @import("simple_circuits").Register;
const ParallelAdder = @import("simple_circuits").ParallelAdder;
const SwitchCircuit = @import("simple_circuits").SwitchCircuit;
const CepSizesT = @import("utils").CepSizesT;

// An instance implementing the area in the computer responsible for
// handling arithmetic operations.
//
// It is made of the following components:
// - Registers (# = 3):
//      * A with type: WordReg inputs: [ KA ]
//      * B with type: WordReg inputs: [ KB ]
//      * C with type: WordReg inputs: [ KC ]
//
// - ParallelAdders (# = 1):
//      * AD with type: WordReg inputs: [ KV, KU ]
//
// - Switching Circuits (# = 5):
//      * KA with type: WordReg  inputs: [ AD, A,     ](# = 2)  #virtual_srcs: 5
//      * KB with type: WordReg  inputs: [ A,  AD, B  ](# = 3)  #virtual_srcs: 5
//      * KC with type: WordReg  inputs: [ AD, QC, AJ ](# = 3)  #virtual_srcs: 3
//      * KU with type: WordReg  inputs: [ E,  Z,  C  ](# = 3)  #virtual_srcs: 3
//      * KV with type: WordReg  inputs: [ A,  B,  C  ](# = 3)  #virtual_srcs: 3
const ArithmeticUnit = struct {
    // Register' fields
    reg_a: Register(CepSizesT.WorldT) = undefined,
    reg_b: Register(CepSizesT.WorldT) = undefined,
    reg_c: Register(CepSizesT.WorldT) = undefined,

    // ParallelAdders' fields
    addr_ad: ParallelAdder(CepSizesT.WorldT) = undefined,

    // Switching Circuits' fields
    sw_ka: SwitchCircuit(CepSizesT.WorldT, 2, 5) = undefined,
    sw_kb: SwitchCircuit(CepSizesT.WorldT, 3, 5) = undefined,
    sw_kc: SwitchCircuit(CepSizesT.WorldT, 3, 3) = undefined,
    sw_ku: SwitchCircuit(CepSizesT.WorldT, 3, 3) = undefined,
    sw_kv: SwitchCircuit(CepSizesT.WorldT, 3, 3) = undefined,

    pub fn init() ArithmeticUnit {
        // Registers' initialization

        // ParallelAdders' initialization

        // Switching Circuits' initialization
    }
};
