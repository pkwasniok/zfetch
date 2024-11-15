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
        const version_file = try std.fs.openFileAbsolute("/proc/version", .{ .mode = .read_only });
        defer version_file.close();

        var version_string = blk: {
            const reader = version_file.reader();

            const buffer = try reader.readAllAlloc(self.allocator, 2048);
            defer self.allocator.free(buffer);

            var string = ASCIIString.init(self.allocator);

            try string.pushString(buffer[0 .. buffer.len - 1]);

            break :blk string;
        };

        try version_string.removeString(0, 14);

        const index = version_string.indexOf(" ").?;

        try version_string.removeString(index, 2048);

        if (self.name) |*name| {
            name.deinit();
        }

        if (self.version) |*version| {
            version.deinit();
        }

        self.version = version_string;

        if (self.version.?.indexOf("arch") != null) {
            self.name = ASCIIString.init(self.allocator);
            try self.name.?.pushString("Arch Linux");
        } else {
            self.name = ASCIIString.init(self.allocator);
            try self.name.?.pushString("Linux");
        }

        const uptime_file = try std.fs.openFileAbsolute("/proc/uptime", .{ .mode = .read_only });
        defer uptime_file.close();

        {
            const reader = uptime_file.reader();

            const buffer = try reader.readAllAlloc(self.allocator, 1024);
            defer self.allocator.free(buffer);

            var string = ASCIIString.init(self.allocator);
            defer string.deinit();

            try string.pushString(buffer[0 .. buffer.len-1]);

            try string.removeString(string.indexOf(".").?, string.length());

            self.uptime = try std.fmt.parseInt(u32, string.buffer[0 .. string.length()], 10);
        }
    }
};
