const std = @import("std");

pub fn build(b: *std.Build) void {
    // ------------------------------- COMMON PARAMS ----------------------------------------

    const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

    // ------------------------------ UTILS MODULE -----------------------------------------
    const utils_mod = b.addModule("utils", .{
        .root_source_file = b.path("src/utils/root.zig"),
        .target = target,
    });
    const utils_ref = std.Build.Module.Import{
        .name = "utils",
        .module = utils_mod,
    };

    const utils_t_mod = b.addModule("utils_test", .{
        .root_source_file = b.path("src/utils/test.zig"),
        .target = target,
        .imports = &.{utils_ref},
    });
    const utils_t = b.addTest(.{ .root_module = utils_t_mod });
    const run_utils_t = b.addRunArtifact(utils_t);
    const step_utils = b.step("utils_test", "Tests general common functions");
    step_utils.dependOn(&run_utils_t.step);

    // ------------------------------ SWITCHING CIRCUIT MODULES ------------------------------
    const sw_mod = b.addModule("switching_circuit", .{
        .root_source_file = b.path("src/components/simple_circuits/switching_circuit/root.zig"),
        .target = target,
    });
    const sw_ref = std.Build.Module.Import{
        .name = "switching_circuit",
        .module = sw_mod,
    };

    const sw_t_mod = b.addModule("switching_circuit_test", .{
        .root_source_file = b.path("src/components/simple_circuits/switching_circuit/test.zig"),
        .target = target,
        .imports = &.{utils_ref},
    });
    const sw_t = b.addTest(.{ .root_module = sw_t_mod });
    const run_sw_t = b.addRunArtifact(sw_t);
    const step_sw = b.step("switching_circuit_test", "Test functionality of SwitchingCircuit");
    step_sw.dependOn(&run_sw_t.step);

    // ------------------------------ SIMPLE CIRCUITS MODULES --------------------------------
    const smpl_circuits_mod = b.addModule("simple_circuits", .{
        .root_source_file = b.path("src/components/simple_circuits/root.zig"),
        .target = target,
    });
    const smpl_circuits_ref = std.Build.Module.Import{
        .name = "simple_circuits",
        .module = smpl_circuits_mod,
    };

    const smpl_circuits_t_mod = b.addModule("simple_circuits_tests", .{
        .root_source_file = b.path("src/components/simple_circuits/test.zig"),
        .target = target,
        .imports = &.{
            smpl_circuits_ref,
            utils_ref,
            sw_ref,
        },
    });
    const smpl_circuits_t = b.addTest(.{ .root_module = smpl_circuits_t_mod });
    const run_smpl_circuits_t = b.addRunArtifact(smpl_circuits_t);
    const step_smpl_circuits = b.step("simple_circuits_test", "tests for Registers and Parallel Adders");
    step_smpl_circuits.dependOn(&run_smpl_circuits_t.step);

    // ------------------------- ARITHMETIC UNIT MODULE DEFINITIONS -------------------
    const arith_mod = b.addModule("arithmetic_unit", .{
        .root_source_file = b.path("src/components/arithmetic_unit.zig"),
        .target = target,
    });
    const arith_ref = std.Build.Module.Import{
        .name = "airhtmetic_unit",
        .module = arith_mod,
    };

    const arith_t_mod = b.addModule("arithmetic_unit_test", .{
        .root_source_file = b.path("src/components/arithmetic_unit.zig"),
        .target = target,
        .imports = &.{
            arith_ref,
            utils_ref,
            smpl_circuits_ref,
        },
    });
    const arith_t = b.addTest(.{ .root_module = arith_t_mod });
    const run_arith_t = b.addRunArtifact(arith_t);
    const step_arith = b.step("arithmetic_unit_test", "Tests the arithmetic unit");
    step_arith.dependOn(&run_arith_t.step);

    // ------------------------- MAIN MODULE DEFINITIONS ------------------------------

    // Defines the module which wraps the emulator.
    const main_module = b.addModule(
        // Name of the module
        "CEP_emulator",
        // Options
        .{ .root_source_file = b.path("src/main.zig"), .target = target });

    // Defines the executable to start the CEP emulator.
    const main_exe = b.addExecutable(.{
        .name = "CEP_emulator",
        .root_module = main_module,
    });
    b.installArtifact(main_exe);

    // Defining the top level step for running the main executable.
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(main_exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // ----------------------------- TEST MODULE DEFINITIONS -----------------------------

}
