const std = @import("std");
const cli = @import("./cli.zig");
const template = @import("./template.zig");
const sysfetch = @import("./root.zig");
const String = @import("containers").ASCIIString;

const DEFAULT_TEMPLATE =
    \\CPU
    \\├─Manufacturer: {cpu.manufacturer}
    \\├─Model: {cpu.model}
    \\└─No. of cores: {cpu.cores}
    \\  └─No. of threads: {cpu.threads}
    \\Memory
    \\└─Total: {memory.total} KiB
    \\  └─Free: {memory.free} KiB
    \\OS
    \\├─Name: {os.name}
    \\└─Version: {os.version}
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const parsing_result = try cli.parse(allocator);

    switch (parsing_result) {
        .help => {
            try handle_help();
        },
        .version => {
            try handle_version();
        },
        .default => {
            try handle_default(allocator);
        },
    }
}

fn handle_help() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\ Usage: sysfetch [OPTIONS]
        \\
        \\ Sysfetch is a Neofetch alternative for Linux written in Zig.
        \\
        \\ OPTIONS:
        \\     DEFAULT      display system information
        \\     --help       display help message
        \\     --version    display version information
        \\
    , .{});
}

fn handle_version() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("sysfetch 0.1.0\n", .{});
}

fn handle_default(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();

    var cpu_info = sysfetch.CPUInfo.init(allocator);
    defer cpu_info.deinit();

    var memory_info = sysfetch.MemoryInfo.init(allocator);
    defer memory_info.deinit();

    var os_info = sysfetch.OSInfo.init(allocator);
    defer os_info.deinit();

    try cpu_info.fetch();
    try memory_info.fetch();
    try os_info.fetch();

    var map = std.StringHashMap([]const u8).init(allocator);
    defer map.deinit();

    if (cpu_info.model_name) |model_name| {
        try map.put("cpu.model", model_name);
    }

    if (cpu_info.manufacturer_name) |manufacturer_name| {
        try map.put("cpu.manufacturer", manufacturer_name);
    }

    var cpu_cores: ?[]u8 = null;
    if (cpu_info.cores) |cores| {
        cpu_cores = try std.fmt.allocPrint(allocator, "{d}", .{cores});
        try map.put("cpu.cores", cpu_cores.?);
    }
    defer if (cpu_cores) |cores| allocator.free(cores);

    var cpu_threads: ?[]u8 = null;
    if (cpu_info.threads) |threads| {
        cpu_threads = try std.fmt.allocPrint(allocator, "{d}", .{threads});
        try map.put("cpu.threads", cpu_threads.?);
    }
    defer if (cpu_threads) |threads| allocator.free(threads);

    var memory_total: ?[]u8 = null;
    if (memory_info.physical_total) |total| {
        memory_total = try std.fmt.allocPrint(allocator, "{d}", .{total});
        try map.put("memory.total", memory_total.?);
    }
    defer if (memory_total) |total| allocator.free(total);

    var memory_free: ?[]u8 = null;
    if (memory_info.physical_free) |free| {
        memory_free = try std.fmt.allocPrint(allocator, "{d}", .{free});
        try map.put("memory.free", memory_free.?);
    }
    defer if (memory_free) |free| allocator.free(free);

    if (os_info.name) |value| {
        try map.put("os.name", value.string);
    }

    if (os_info.version) |value| {
        try map.put("os.version", value.string);
    }

    var result = try template.parse(allocator, DEFAULT_TEMPLATE, map);
    defer result.deinit();

    try stdout.print("{s}", .{result});
}

