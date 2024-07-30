const std = @import("std");
const utils = @import("utils.zig");
const Allocator = std.mem.Allocator;

pub const OSInfo = struct {
    hostname: []u8,
    uptime: u32,
};

pub const CPUInfo = struct {
    model: []u8,
};

pub const MemoryInfo = struct {
    total: u32,
    available: u32,
};

pub fn getOSInfo(allocator: Allocator) !OSInfo {
    const hostname = blk: {
        // Open hostname file
        const hostname_file = try std.fs.openFileAbsolute("/etc/hostname", .{ .mode = .read_only });
        defer hostname_file.close();

        // Read hostname from file
        const hostname_reader = hostname_file.reader();
        const hostname = (try hostname_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)).?;

        break :blk hostname;
    };

    const uptime = blk: {
        // Open uptime file
        const uptime_file = try std.fs.openFileAbsolute("/proc/uptime", .{ .mode = .read_only });
        defer uptime_file.close();

        // Read uptime from file
        const uptime_reader = uptime_file.reader();
        const uptime_text = (try uptime_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)).?;

        // Parse uptime
        const separator_index = std.mem.indexOf(u8, uptime_text, " ").?;
        break :blk try std.fmt.parseInt(u32, uptime_text[0 .. separator_index - 3], 10);
    };

    return OSInfo{
        .hostname = hostname,
        .uptime = uptime,
    };
}

pub fn getCPUInfo() !CPUInfo {
    return CPUInfo{
        .model = "",
    };
}

pub fn getMemoryInfo(allocator: Allocator) !MemoryInfo {
    // Open memory info file
    const meminfo_file = try std.fs.openFileAbsolute("/proc/meminfo", .{ .mode = .read_only });
    defer meminfo_file.close();

    // Parse memory info file
    var meminfo_keys = std.ArrayList([]u8).init(allocator);
    var meminfo_values = std.ArrayList([]u8).init(allocator);
    const meminfo_reader = meminfo_file.reader();
    while (try meminfo_reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 1024)) |line| {
        const separator_index = std.mem.indexOf(u8, line, ":").?;

        const key = line[0..separator_index];
        const value = utils.stripFront(line[separator_index + 1 ..]);

        try meminfo_keys.append(key);
        try meminfo_values.append(value);
    }

    // Parse meminfo file properties
    const total = try std.fmt.parseInt(u32, utils.deleteEnd(meminfo_values.items[0], 2), 10);
    const available = try std.fmt.parseInt(u32, utils.deleteEnd(meminfo_values.items[2], 2), 10);

    return MemoryInfo{
        .total = total,
        .available = available,
    };
}
