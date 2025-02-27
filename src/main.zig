const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const ArrayList = std.ArrayList;

const Dmap = struct {
    ignore_patterns: ArrayList([]const u8),
    text_extensions: ArrayList([]const u8),
};

fn parseDmap(allocator: std.mem.Allocator, dir: fs.Dir) !Dmap {
    var dmap = Dmap{
        .ignore_patterns = ArrayList([]const u8).init(allocator),
        .text_extensions = ArrayList([]const u8).init(allocator),
    };
    const file = dir.openFile("llm-dirmap.config", .{}) catch return dmap;
    defer file.close();

    var reader = file.reader();
    var line_buf: [1024]u8 = undefined;
    var in_ignore = false;
    var in_text_extensions = false;

    while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        const trimmed = mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (mem.eql(u8, trimmed, "[ignore]")) {
            in_ignore = true;
            in_text_extensions = false;
            continue;
        } else if (mem.eql(u8, trimmed, "[text_extensions]")) {
            in_ignore = false;
            in_text_extensions = true;
            continue;
        }

        if (in_ignore) {
            const trimmed_copy = try allocator.dupe(u8, trimmed);
            try dmap.ignore_patterns.append(trimmed_copy);
        } else if (in_text_extensions) {
            const trimmed_copy = try allocator.dupe(u8, trimmed);
            try dmap.text_extensions.append(trimmed_copy);
        }
    }
    return dmap;
}

fn shouldIgnore(path: []const u8, ignore_patterns: []const []const u8) bool {
    const normalized_path = if (mem.startsWith(u8, path, "./")) path[2..] else path;

    for (ignore_patterns) |pattern| {
        if (pattern.len > 2 and pattern[0] == '*' and pattern[1] == '.') {
            const ext = pattern[2..];
            if (mem.endsWith(u8, normalized_path, ext)) return true;
        }
        const pattern_base = if (pattern[pattern.len - 1] == '/')
            pattern[0 .. pattern.len - 1]
        else
            pattern;
        if (mem.eql(u8, normalized_path, pattern) or
            mem.eql(u8, normalized_path, pattern_base))
        {
            return true;
        }
        if (pattern[pattern.len - 1] == '/' and mem.startsWith(u8, normalized_path, pattern)) {
            return true;
        }
    }
    return false;
}

fn isTextFile(path: []const u8, text_extensions: []const []const u8) bool {
    for (text_extensions) |ext| {
        if (mem.endsWith(u8, path, ext)) return true;
    }
    return false;
}

fn traverseDir(
    allocator: std.mem.Allocator,
    dir: fs.Dir,
    base_path: []const u8,
    indent: usize,
    dmap: Dmap,
    map_lines: *ArrayList([]const u8),
    content_lines: *ArrayList([]const u8),
) !void {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        const full_path = try fs.path.join(allocator, &[_][]const u8{ base_path, entry.name });
        defer allocator.free(full_path);
        if (shouldIgnore(full_path, dmap.ignore_patterns.items)) continue;

        const indent_str = try allocator.alloc(u8, indent * 2);
        defer allocator.free(indent_str);
        @memset(indent_str, ' ');

        const line = if (entry.kind == .directory)
            try std.fmt.allocPrint(allocator, "{s}{s}/", .{ indent_str, entry.name })
        else
            try std.fmt.allocPrint(allocator, "{s}{s}", .{ indent_str, entry.name });
        try map_lines.append(line);

        if (entry.kind == .directory) {
            var sub_dir = try dir.openDir(entry.name, .{});
            defer sub_dir.close();
            try traverseDir(allocator, sub_dir, full_path, indent + 1, dmap, map_lines, content_lines);
        } else if (entry.kind == .file and isTextFile(full_path, dmap.text_extensions.items)) {
            const content_header = try std.fmt.allocPrint(allocator, "\nContents of {s}:\n", .{full_path});
            try content_lines.append(content_header);
            var file = try dir.openFile(entry.name, .{});
            defer file.close();
            const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
            try content_lines.append(content);
        }
    }
}

fn generateMapFile(allocator: std.mem.Allocator, dir_path: []const u8, output_file: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var dir = try fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    const dmap = try parseDmap(alloc, dir);
    var map_lines = ArrayList([]const u8).init(alloc);
    var content_lines = ArrayList([]const u8).init(alloc);

    try traverseDir(alloc, dir, dir_path, 0, dmap, &map_lines, &content_lines);

    var output = try fs.cwd().createFile(output_file, .{});
    defer output.close();
    var writer = output.writer();

    var total_chars: usize = 0;
    for (map_lines.items) |line| {
        try writer.print("{s}\n", .{line});
        total_chars += line.len + 1; // +1 for '\n'
    }
    for (content_lines.items) |line| {
        try writer.print("{s}\n", .{line});
        total_chars += line.len + 1; // +1 for '\n'
    }

    // Estimate tokens (1 token ≈ 4 characters)
    const estimated_tokens = total_chars / 4;
    std.debug.print("\nEstimated tokens for AI processing: {d}\n", .{estimated_tokens});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        std.debug.print("Usage: {s} <directory> <output_file>\n", .{args[0]});
        return error.InvalidArgs;
    }

    const dir_path = args[1];
    const output_file = args[2];
    try generateMapFile(allocator, dir_path, output_file);
}
