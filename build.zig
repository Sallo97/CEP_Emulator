const std = @import("std");

pub fn build(b: *std.Build) void {
    // ------------------------------- COMMON PARAMS ----------------------------------------

    const target = b.standardTargetOptions(.{});
    // const optimize = b.standardOptimizeOption(.{});

    // ------------------------------ BASIC CIRCUITS MODULE --------------------------------
    const simple_circuits_module = b.addModule(
        // Name of the module
        "CEP_simple_circuits",
        // Options
        .{ .root_source_file = b.path("src/components/simple_circuits/root.zig"), .target = target });

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
    const simple_circuits_tests_module = b.addModule(
        // Name of the module
        "simple_circuits_tests",
        // Options
        .{
            .root_source_file = b.path("src/components/simple_circuits/root.zig"),
            .target = target,
            .imports = &.{.{ .name = "CEP_basic_circuits", .module = simple_circuits_module }},
        });
    const simple_circuit_tests = b.addTest(.{ .root_module = simple_circuits_tests_module });

    const run_adder_mod_tests = b.addRunArtifact(simple_circuit_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_adder_mod_tests.step);
}
