using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
var profile = builder.Configuration["profile"] ?? "default";
if (!System.Text.RegularExpressions.Regex.IsMatch(profile, "^[a-zA-Z0-9_-]{1,32}$"))
    throw new ArgumentException("Profile names must contain 1–32 letters, numbers, underscores or hyphens.");
profile = profile.ToLowerInvariant();
var profilePort = profile == "default" ? 8765 : 18000 + BitConverter.ToUInt16(SHA256.HashData(Encoding.UTF8.GetBytes(profile)), 0) % 40000;
var port = int.TryParse(builder.Configuration["port"], out var requestedPort) ? requestedPort : profilePort;
if (port < 1024 || port > 65535) throw new ArgumentException("Choose a port between 1024 and 65535.");
var localUrl = $"http://127.0.0.1:{port}";
var baseDataFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MouseTrailNative");
var dataFolder = Environment.GetEnvironmentVariable("MOUSETRAIL_DATA") ?? (profile == "default" ? baseDataFolder : Path.Combine(baseDataFolder, "profiles", profile));
Directory.CreateDirectory(dataFolder);
using var instanceLock = new FileStream(Path.Combine(dataFolder, "instance.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None);
var store = new Tracker(dataFolder);
var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
builder.WebHost.UseUrls(localUrl);
var app = builder.Build();
var webRoot = Path.Combine(AppContext.BaseDirectory, "www");
app.Use(async (context, next) =>
{
    if (context.Request.Host.Value != $"127.0.0.1:{port}")
    {
        context.Response.StatusCode = 403;
        return;
    }
    context.Response.Headers.CacheControl = "no-store";
    context.Response.Headers.XContentTypeOptions = "nosniff";
    if (context.Request.Path.StartsWithSegments("/api") && context.Request.Headers["X-MouseTrail-Token"] != token)
    {
        context.Response.StatusCode = 403;
        return;
    }
    await next();
});
app.MapGet("/", () => Results.Content(File.ReadAllText(Path.Combine(webRoot, "index.html")).Replace("__TOKEN__", token).Replace("__PROFILE__", profile), "text/html"));
foreach (var asset in new Dictionary<string, string> {
    ["manifest.webmanifest"] = "application/manifest+json", ["sw.js"] = "text/javascript",
    ["offline.html"] = "text/html", ["icon-192.png"] = "image/png", ["icon-512.png"] = "image/png" })
{
    var name = asset.Key;
    var type = asset.Value;
    app.MapGet("/" + name, () => Results.File(Path.Combine(webRoot, name), type));
}
app.MapGet("/api/state", () => Results.Json(store.Snapshot()));
app.MapGet("/api/export", () => Results.Text(store.Export(), "text/csv"));
app.MapPost("/api/{command}", async (string command, HttpRequest request) =>
{
    try
    {
        double? dpi = null;
        if (command == "dpi")
        {
            var value = await JsonSerializer.DeserializeAsync<JsonElement>(request.Body);
            if (!value.TryGetProperty("dpi", out var field) || !field.TryGetDouble(out var number))
                return Results.BadRequest(new { error = "Enter a numeric screen PPI." });
            dpi = number;
        }
        store.Command(command, dpi);
        return Results.Json(store.Snapshot());
    }
    catch (Exception error) when (error is ArgumentException or JsonException)
    {
        return Results.BadRequest(new { error = error.Message });
    }
});
Native.SetProcessDPIAware();
using var stop = new CancellationTokenSource();
var polling = Task.Run(async () =>
{
    using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(50));
    try
    {
        while (await timer.WaitForNextTickAsync(stop.Token)) store.Tick();
    }
    catch (OperationCanceledException) { }
});
app.Lifetime.ApplicationStarted.Register(() =>
{
    if (Environment.GetEnvironmentVariable("MOUSETRAIL_NO_BROWSER") != "1")
        Process.Start(new ProcessStartInfo(localUrl) { UseShellExecute = true });
});
try { await app.RunAsync(); }
finally
{
    stop.Cancel();
    await polling;
    store.Command("pause", null);
}

sealed class Session
{
    public long id { get; set; }
    public string started { get; set; } = "";
    public double pixels { get; set; }
    public double seconds { get; set; }
    public int samples { get; set; }
    public double dpi { get; set; }
    public double movingSeconds { get; set; }
    public double maxSpeed { get; set; }
    public double maxStep { get; set; }
    public int[] histogram { get; set; } = new int[8];
    public int[] directions { get; set; } = new int[8];
}
sealed record Sample(long sequence, double timestamp, int x, int y, double dx, double dy, double distance, double interval, double speed, double? ax, double? ay);
sealed class SavedState
{
    public double Dpi { get; set; } = 96;
    public List<Session> Sessions { get; set; } = [];
}
sealed class Tracker
{
    readonly object gate = new();
    readonly string path;
    readonly SavedState saved;
    Session? current;
    bool running;
    Native.Point? previous;
    long last = Stopwatch.GetTimestamp();
    long checkpoint = Stopwatch.GetTimestamp();
    string? error;
    readonly Queue<Sample> telemetry = new();
    long sequence;
    (double X, double Y, double Interval)? previousVelocity;

    public Tracker(string folder)
    {
        path = Path.Combine(folder, "history.json");
        saved = File.Exists(path) ? JsonSerializer.Deserialize<SavedState>(File.ReadAllText(path)) ?? throw new InvalidDataException("History could not be read.") : new SavedState();
    }
    void Save()
    {
        var temp = path + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(saved));
        File.Move(temp, path, true);
    }
    public void Command(string command, double? dpi)
    {
        lock (gate)
        {
            switch (command)
            {
                case "start":
                    if (current is null)
                    {
                        current = new Session { id = saved.Sessions.Count == 0 ? 1 : saved.Sessions.Max(x => x.id) + 1, started = DateTimeOffset.Now.ToString("O"), dpi = saved.Dpi };
                        saved.Sessions.Add(current);
                    }
                    if (!running) previous = null;
                    running = true;
                    break;
                case "pause": running = false; previous = null; break;
                case "new": running = false; previous = null; current = null; telemetry.Clear(); break;
                case "dpi":
                    if (dpi is null || !double.IsFinite(dpi.Value) || dpi < 20 || dpi > 2000)
                        throw new ArgumentException("Enter screen PPI between 20 and 2000.");
                    saved.Dpi = dpi.Value;
                    if (current is not null) current.dpi = dpi.Value;
                    break;
                default: throw new ArgumentException("Unknown action.");
            }
            Save();
        }
    }
    public void Tick()
    {
        lock (gate)
        {
            var now = Stopwatch.GetTimestamp();
            var elapsed = Stopwatch.GetElapsedTime(last, now).TotalSeconds;
            last = now;
            if (!running || current is null) { previous = null; return; }
            if (!Native.GetCursorPos(out var point))
            {
                error = "Cursor unavailable. Unlock your desktop to resume measurement.";
                previous = null;
                return;
            }
            error = null;
            if (previous is Native.Point before && elapsed < 1)
            {
                var dx = (double)point.X - before.X;
                var dy = (double)point.Y - before.Y;
                var distance = Math.Sqrt(dx * dx + dy * dy);
                current.pixels += distance;
                current.seconds += elapsed;
                var speed = distance / elapsed;
                var vx = dx / elapsed;
                var vy = -dy / elapsed;
                double? ax = null;
                double? ay = null;
                if (previousVelocity is { } velocity)
                {
                    var midpointInterval = (elapsed + velocity.Interval) / 2;
                    ax = (vx - velocity.X) / midpointInterval;
                    ay = (vy - velocity.Y) / midpointInterval;
                }
                previousVelocity = (vx, vy, elapsed);
                current.maxSpeed = Math.Max(current.maxSpeed, speed);
                current.maxStep = Math.Max(current.maxStep, distance);
                var bucket = distance == 0 ? 0 : distance < 2 ? 1 : distance < 5 ? 2 : distance < 10 ? 3 : distance < 25 ? 4 : distance < 50 ? 5 : distance < 100 ? 6 : 7;
                current.histogram[bucket]++;
                if (distance > 0)
                {
                    current.samples++;
                    current.movingSeconds += elapsed;
                    var direction = ((int)Math.Round(Math.Atan2(dy, dx) / (Math.PI / 4)) + 8) % 8;
                    current.directions[direction]++;
                }
                telemetry.Enqueue(new Sample(++sequence, current.seconds, point.X, point.Y, dx, dy, distance, elapsed, speed, ax, ay));
                while (telemetry.Count > 240) telemetry.Dequeue();
            }
            else previousVelocity = null;
            previous = point;
            if (Stopwatch.GetElapsedTime(checkpoint, now).TotalSeconds >= 5)
            {
                Save();
                checkpoint = now;
            }
        }
    }
    public object Snapshot()
    {
        lock (gate)
        {
            var history = saved.Sessions.AsEnumerable().Reverse().Take(100).Select(x => new { x.id, x.started, x.pixels, x.seconds, x.samples, x.dpi }).ToArray();
            return new { running, pixels = current?.pixels ?? 0, seconds = current?.seconds ?? 0, samples = current?.samples ?? 0, dpi = saved.Dpi, session_id = current?.id, error, history, lifetime_pixels = saved.Sessions.Sum(x => x.pixels), telemetry = telemetry.ToArray(), histogram = current?.histogram ?? new int[8], directions = current?.directions ?? new int[8], moving_seconds = current?.movingSeconds ?? 0, max_speed = current?.maxSpeed ?? 0, max_step = current?.maxStep ?? 0 };
        }
    }
    public string Export()
    {
        lock (gate)
        {
            var result = new StringBuilder("id,started,pixels,seconds,samples,dpi\r\n");
            foreach (var session in saved.Sessions.AsEnumerable().Reverse())
                result.AppendLine(FormattableString.Invariant($"{session.id},{session.started},{session.pixels},{session.seconds},{session.samples},{session.dpi}"));
            return result.ToString();
        }
    }
}
static class Native
{
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X; public int Y; }
    [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
