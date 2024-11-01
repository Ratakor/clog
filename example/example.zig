const std = @import("std");
const axe = @import("axe");

pub const std_options: std.Options = .{
    .logFn = axe.Comptime(.{
        .mutex = .{ .global = .{
            .lock = std.debug.lockStdErr,
            .unlock = std.debug.unlockStdErr,
        } },
    }).standardLog,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();

    // comptime
    const comptime_log = axe.Comptime(.{
        .styles = .none, // colored by default
        .format = "[%l]%s: %f\n", // the log format string, default is "%l%s: %f\n"
        .scope_format = " ~ %", // % is a placeholder for scope, default is "(%)"
        .level_text = .{ // same as zig by default
            .err = "ErrOr",
            .debug = "DeBuG",
        },
        // .scope = .main, // scope can also be set here, it will be ignored for std.log
        .writers = &.{std.io.getStdOut().writer().any()}, // stderr is default
        .buffering = true, // true by default
        .time = .disabled, // disabled by default, doesn't work at comptime
        .mutex = .none, // none by default
    });
    comptime_log.debug("Hello, comptime with no colors", .{});
    comptime_log.scoped(.main).err("comptime scoped", .{});

    // comptime with std.log
    // std.log supports all the features of axe.Comptime
    std.log.info("std.log.info with axe.Comptime(.{{}})", .{});
    std.log.scoped(.main).warn("this is scoped", .{});

    // runtime
    var f = try std.fs.cwd().createFile("log.txt", .{});
    defer f.close();
    const writers = [_]std.io.AnyWriter{
        std.io.getStdErr().writer().any(),
        f.writer().any(),
    };
    const log = try axe.Runtime(.{
        .format = "%t %l%s: %f\n",
        .scope_format = "@%",
        .styles = .{
            .err = &.{ .{ .bg_hex = "ff0000" }, .bold, .underline },
            .warn = &.{ .{ .rgb = .{ .r = 255, .g = 255, .b = 0 } }, .strikethrough },
            .info = &.{ .green, .italic },
        },
        .level_text = .{
            .err = "ERROR",
            .warn = "WARN",
            .info = "INFO",
            .debug = "DEBUG",
        },
        // .writers = &writers, // not possible because f.writer().any() is not comptime
        .time = .{ .gofmt = .date_time }, // .date_time is a preset but custom format is also possible
        .mutex = .default, // default to std.Thread.Mutex
    }).init(allocator, &writers, &env); // null can be used instead of &env
    defer log.deinit(allocator);

    log.debug("Hello, runtime! This will have no color if NO_COLOR is defined", .{});
    log.info("the time can be formatted like strftime or time.go", .{});
    log.scoped(.main).err("scope also works at runtime", .{});
    log.warn("this is output to stderr and log.txt", .{});

    // json log
    var json_file = try std.fs.cwd().createFile("log.json", .{});
    defer json_file.close();
    const json_log = try axe.Runtime(.{
        .format =
        \\{"level":"%l",%s"time":"%t","data":%f}
        \\
        ,
        .scope_format =
        \\"scope":"%",
        ,
        .styles = .none,
        .time = .{ .gofmt = .rfc3339 },
    }).init(allocator, &.{json_file.writer().any()}, &env);
    defer json_log.deinit(allocator);

    json_log.debug("\"json log\"", .{});
    json_log.scoped(.main).info("\"json scoped\"", .{});
    // it's easy to have struct instead of a string as data
    const data = .{ .a = 42, .b = 3.14 };
    json_log.info("{}", .{std.json.fmt(data, .{})});
}
