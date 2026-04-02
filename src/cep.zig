//! Connects all components to handle initialization of the CEP.

const std = @import("std");
const cpu_t = @import("cpu.zig");
const main_memory_t = @import("main_memory.zig");

const Cep = struct {
    cpu_t: cpu_t,
    main_memory: main_memory_t,
};
