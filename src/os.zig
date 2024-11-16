const std = @import("std");
const ASCIIString = @import("containers").ASCIIString;

pub const OSInfo = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    name: ?ASCIIString,
    version: ?ASCIIString,
    uptime: ?u32,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .name = null,
            .version = null,
            .uptime = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.name) |*name| {
            name.deinit();
        }

        if (self.version) |*version| {
            version.deinit();
        }
    }

    pub fn fetch(self: *Self) !void {
        const os_name = try fetch_os_name(self.allocator);

        if (self.name) |*name| {
            name.deinit();
        }

        self.name = os_name;

        const os_version = try fetch_os_version(self.allocator);

        if (self.version) |*version| {
            version.deinit();
        }

        self.version = os_version;

        const os_uptime = try fetch_os_uptime(self.allocator);
        self.uptime = os_uptime;
    }

    fn fetch_os_name(allocator: std.mem.Allocator) !ASCIIString {
        const file = try std.fs.openFileAbsolute("/proc/version", .{ .mode = .read_only });
        defer file.close();

        const reader = file.reader();

        const buffer = try reader.readAllAlloc(allocator, 1024);
        defer allocator.free(buffer);

        var string = ASCIIString.init(allocator);

        try string.pushString(buffer[0 .. buffer.len - 1]);
        try string.removeString(string.indexOf(" ").?, 1024);

        return string;
    }

    fn fetch_os_version(allocator: std.mem.Allocator) !ASCIIString {
        const file = try std.fs.openFileAbsolute("/proc/version", .{ .mode = .read_only });
        defer file.close();

        const reader = file.reader();

        const buffer = try reader.readAllAlloc(allocator, 1024);
        defer allocator.free(buffer);

        var string = ASCIIString.init(allocator);

        try string.pushString(buffer[0 .. buffer.len - 1]);
        try string.removeString(0, string.indexOf(" ").? + 1);
        try string.removeString(0, string.indexOf(" ").? + 1);
        try string.removeString(string.indexOf(" ").? + 1, 1024);

        return string;
    }

    fn fetch_os_uptime(allocator: std.mem.Allocator) !u32 {
        const file = try std.fs.openFileAbsolute("/proc/uptime", .{ .mode = .read_only });
        defer file.close();

        const reader = file.reader();

        const buffer = try reader.readAllAlloc(allocator, 1024);
        defer allocator.free(buffer);

        var string = ASCIIString.init(allocator);
        defer string.deinit();

        try string.pushString(buffer[0 .. buffer.len - 1]);
        try string.removeString(string.indexOf(".").?, string.length());

        const uptime = try std.fmt.parseInt(u32, string.buffer[0..string.length()], 10);

        return uptime;
    }
};
