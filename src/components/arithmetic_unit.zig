//! This file defines the Arithmetic Unit, i.e. the region
//! of the computer dedicate in handling arithmetic operations.

const std = @import("std");

const Register = @import("simple_circuits").Register;
const ParallelAdder = @import("simple_circuits").ParallelAdder;
const SwitchCircuit = @import("simple_circuits").SwitchCircuit;
const Device = @import("utils").Device(CepSizesT.WorldT);
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
//      * KA with type: WordReg  inputs: [ AD,  A,  B  ](# = 3)  #virtual_srcs: 5
//      * KB with type: WordReg  inputs: [ AD,  A,  B  ](# = 3)  #virtual_srcs: 5
//      * KC with type: WordReg  inputs: [ AD,  QC, AJ ](# = 3)  #virtual_srcs: 3
//      * KU with type: WordReg  inputs: [ E,   Z,  C  ](# = 3)  #virtual_srcs: 3
//      * KV with type: WordReg  inputs: [ A,   B,  C  ](# = 3)  #virtual_srcs: 3
const ArithmeticUnit = struct {
    // Register' fields
    reg_a: Register(CepSizesT.WorldT) = .init("A"),
    reg_b: Register(CepSizesT.WorldT) = .init("B"),
    reg_c: Register(CepSizesT.WorldT) = .init("C"),

    // ParallelAdders' fields
    addr_ad: ParallelAdder(CepSizesT.WorldT) = ParallelAdder(CepSizesT.WorldT).init("AD"),

    // Switching Circuits' fields
    sw_ka: SwitchCircuit(CepSizesT.WorldT, 3, 5) = SwitchCircuit(CepSizesT.WorldT, 2, 5).init("KA"),
    sw_kb: SwitchCircuit(CepSizesT.WorldT, 3, 5) = SwitchCircuit(CepSizesT.WorldT, 3, 5).init("KB"),
    sw_kc: SwitchCircuit(CepSizesT.WorldT, 3, 3) = SwitchCircuit(CepSizesT.WorldT, 3, 3).init("KC"),
    sw_ku: SwitchCircuit(CepSizesT.WorldT, 3, 3) = SwitchCircuit(CepSizesT.WorldT, 3, 3).init("KU"),
    sw_kv: SwitchCircuit(CepSizesT.WorldT, 3, 3) = SwitchCircuit(CepSizesT.WorldT, 3, 3).init("KV"),

    /// The following components coming from external units must be passed to be attached
    /// (all abstracted as devices):
    /// - QC : the control panel.
    /// - AJ : parallel adder of the Address Unit.
    /// - E  : the register handling I/O devices.
    /// - Z  : the register of the Main Memory (actually is physically stored in the Arithmetic Unit).
    pub fn init(
        p_qc: Device,
        addr_aj: Device,
        reg_e: Device,
        reg_z: Device,
    ) ArithmeticUnit {
        const au = ArithmeticUnit{};

        // Phase 1 - for each component attach its inputs.
        //  - Registers
        au.reg_a.input = au.sw_ka.asDevice();
        au.reg_b.input = au.sw_kb.asDevice();
        au.reg_c.input = au.sw_kc.asDevice();

        //  - Parallel Adders
        au.addr_ad.inputs[0] = au.sw_kv.asDevice();
        au.addr_ad.inputs[1] = au.sw_ku.asDevice();

        //  - Switching Circuits
        au.sw_ka.devices[0] = au.addr_ad.asDevice();
        au.sw_ka.devices[1] = au.reg_a.asDevice();

        au.sw_kb.devices[0] = au.addr_ad.asDevice();
        au.sw_kb.devices[1] = au.reg_a.asDevice();
        au.sw_kb.devices[2] = au.reg_b.asDevice();

        au.sw_kc.devices[0] = au.addr_ad.asDevice();
        au.sw_kc.devices[1] = p_qc;
        au.sw_kc.devices[2] = addr_aj;

        au.sw_ku.devices[0] = reg_e;
        au.sw_ku.devices[1] = reg_z;
        au.sw_ku.devices[2] = au.reg_c.asDevice();

        au.sw_kv.devices[0] = au.reg_a.asDevice();
        au.sw_kv.devices[1] = au.reg_b.asDevice();
        au.sw_kv.devices[2] = au.reg_c.asDevice();

        // Phase 2 - for each switching circuit, define its
        // virtual sources and selection lines.

        // =========================================== KA ==================================================
        // - virtual sources (# = 6):
        //              KA(i = 0)   KA(i = 1-27)    KA(i = 28-34)   KA(i = 35)     List (DeviceName, idx)
        //      * e0 =     0            0              0               0           [                    ]
        //      * e1 =     d_0*         d_(i-1)        d_(i-1)         d_34        [ (AD, 0)            ]
        //      * e2 =     d_0          d_i            d_i             d_35        [ (AD, 0)            ]
        //      * e3 =     a_0          a_i            1             ~(d_0)        [ (A, 1) ; (AD, 0)   ]
        //      * e4 =   ~(a_0)         a_(i-1)        a_(i-1)         a_34        [ (A, 1)             ]
        //      * e5 =     a_1          a_(i+1)        a_(i+1)         b_0         [ (A, 1) ; (B, 2)    ]
        //
        // - selection groups (# = 6):
        //      * ξ_0 = [ ξ_0(0)     ; ξ_0(1-27) ; ξ_0(28-34) ; ξ_0(35) ]
        //      * ξ_1 = [ ξ_1(0-35)                                     ]
        //      * ξ_2 = [ ξ_2(0-27) ; ξ_2(28-35)                        ]
        //      * ξ_3 = [ ξ_3(0)    ; ξ_3(1-27)  ; ξ_3(35)              ]
        //      * ξ_4 = [ ξ_4(0)    ; ξ_4(1-35)                         ]
        //      * ξ_5 = [ ξ_5(0-34) ; ξ_5(35)                           ]

        // =========================================== KB ==================================================
        // - virtual sources (# = 6):
        //              KB(i = 0)   KB(i = 1-34)    KB(i = 35)     List (DeviceName, idx)
        //      * e0 =     0           0               0           [                    ]
        //      * e1 =     a_0         a_i             a_(35)      [ (A, 1 )            ]
        //      * e2 =     d_0         d_i             d_(35)      [ (AD, 0)            ]
        //      * e3 =     d_1         d_(i+1)         a_0         [ (AD, 0) ; (A, 1 )  ]
        //      * e4 =     d_(35)      b_(i-1)         b_34        [ (AD, 0) ; (B, 2 )  ]
        //      * e5 =     b_1         b_(i+1)         b_35        [ (B, 2 )            ]
        //
        // - selection groups (# = 6):
        //      * ξ_0 = [ ξ_0(0)    ; ξ_0(1-27) ; ξ_0(28-34) ; ξ_0(35) ]
        //      * ξ_1 = [ ξ_1(0-34) ; ξ_1(35)                          ]
        //      * ξ_2 = [ ξ_2(0-35)                                    ]
        //      * ξ_3 = [ ξ_3(0-34) ; ξ_3(35)                          ]
        //      * ξ_4 = [ ξ_4(0-35)                                    ]
        //      * ξ_5 = [ ξ_5(0-34) ; ξ_5(35)                          ]

        // =========================================== KC ==================================================
        // - virtual sources (# = 6):
        //              KC(i = 0-20)   KC(i = 21-35)    List (DeviceName, idx)
        //      * e0 =     0              0             [                    ]
        //      * e1 =     d_i            d_i           [ (AD, 0)            ]
        //      * e2 =     0              j_i           [ (AJ, 2)            ]
        //      * e3 =     0              q_i           [ (QC, 1)            ]
        //
        // - selection groups (# = 6):
        //      * ξ_0 = [ ξ_0(0-20) ; ξ_0(21-35) ]
        //      * ξ_1 = [ ξ_1(21-35)             ]
        //      * ξ_2 = [ ξ_2(21-35)             ]
        //      * ξ_3 = [ ξ_3(21-35)             ]

        // =========================================== KU ==================================================
        // - virtual sources (# = 6):
        //              KU(i = 0-35)     List (DeviceName, idx)
        //      * e0 =     0             [                    ]
        //      * e1 =     z_i           [ (Z, 1)             ]
        //      * e2 =     c_i           [ (C, 2)             ]
        //      * e3 =     e_i           [ (E, 0)             ]
        //
        // - selection groups (# = 6):
        //      * ξ_0 = [ ξ_0(0)    ; ξ_0(0, 2-20) ; ξ_0(21-27) ; ξ_0(28)              ]
        //      * ξ_1 = [ ξ_1(0-35)                                                    ]
        //      * ξ_2 = [ ξ_2(0-35)                                                    ]
        //      * ξ_3 = [ ξ_3(0-35)                                                    ]
        //      * ξ_4 = [ ξ_4(0-20) ; ξ_4(21-27)   ; ξ_4(28)    ; ξ_4(29-34) ; ξ_4(35) ]

        // =========================================== KV ==================================================
        // - virtual sources (# = 6):
        //              KV(i = 0-35)     List (DeviceName, idx)
        //      * e0 =     0             [                    ]
        //      * e1 =     c_i           [ (C, 2)             ]
        //      * e2 =     a_i           [ (A, 0)             ]
        //      * e3 =     b_i           [ (B, 1)             ]
        //
        // - selection groups (# = 6):
        //      * ξ_0 = [ ξ_0(0-20) ; ξ_0(21-27) ; ξ_0(28)    ; ξ_0(29-34) ; ξ_0(35) ]
        //      * ξ_1 = [ ξ_1(0-20) ; ξ_1(21-27) ; ξ_1(28-35)                        ]
        //      * ξ_2 = [ ξ_2(0-20) ; ξ_2(21-27) ; ξ_2(28-35)                        ]
        //      * ξ_3 = [ ξ_3(0-27) ; ξ_3(28-35)                                     ]
        //      * ξ_4 = [ ξ_4(0-20) ; ξ_4(21-27) ; ξ_4(28-35)                        ]

    }
};
