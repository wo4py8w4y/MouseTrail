# MouseTrail

**A Windows cursor telemetry app with an installable web dashboard.**

MouseTrail turns mouse movement into live equations, charts and a scrolling
sample console. A small, self-contained .NET executable reads the Windows cursor
API and serves the dashboard locally. Session history stays on your computer.

The project grew out of [Mouse Distance Tracker for PowerShell](https://github.com/wo4py8w4y/Mouse-Distance-Tracker-ps1).
This repository contains the current .NET application, browser interface and
IIS/ClickOnce deployment tooling.

> **Preview status**
>
> The native app and local IIS delivery have been tested. Interactive ClickOnce
> installation, version upgrades and production certificate signing remain to be
> verified. Published preview packages are unsigned.

## What it does

- Tracks cursor distance, sample count, elapsed tracking time and average speed.
- Shows live equations and a scrolling console of actual cursor samples.
- Plots speed, sample timing, step distance, movement-size histograms and direction counts.
- Displays acceleration on a centred XY crosshair, with positive and negative axes.
- Saves session history, calibration and lifetime totals locally.
- Exports basic session totals as CSV.
- Supports four colour themes and separate named local instances.
- Provides browser installation through a PWA manifest and service worker.
- Includes an IIS download site and ClickOnce publishing with update checks.

## Run the app

Download the portable Windows x64 ZIP from [Releases](https://github.com/wo4py8w4y/MouseTrail/releases),
extract it, and open **MouseTrail.exe**. Keep the `www` directory beside it.
The app opens its dashboard at `http://127.0.0.1:8765`.

Select **Start tracking**. **Pause & save** preserves the current session.
**Finish session** saves its totals and prepares a new session.

You can install the browser interface using **Install app** in Edge or Chrome.
The Windows tracker must remain running for tracking and history access. Closing
the browser window leaves tracking active. Press Ctrl+C in the tracker console
to exit cleanly.

The portable package includes its .NET runtime. End users need neither Python nor
a separate .NET installation. Windows x64 is required.

## Measurements and calibration

Cursor positions are sampled approximately every 50 milliseconds.

```text
step distance = sqrt(deltaX² + deltaY²)
speed         = step distance / sample interval
acceleration  = change in velocity / time between velocity midpoints
screen metres = total pixels / screen PPI × 0.0254
```

The calibration panel links to [dpi.lv](https://dpi.lv/). Enter the measured screen
PPI to estimate distance in metres. The default 96 PPI is approximate.

The acceleration chart uses positive X to the right and positive Y upward.
The raw console reports Windows screen coordinates, whose Y axis increases
downward. Acceleration estimates are sensitive to sampling jitter, cursor
warps and remote-desktop behaviour.

This measures the sampled cursor path across the desktop. Physical mouse travel
on the desk is a different quantity. Fast curved paths can be underestimated,
and one PPI value cannot accurately represent mixed-density monitors.

## Separate instances

```powershell
.\MouseTrail.exe --profile work
.\MouseTrail.exe --profile testing
```

Each profile gets its own history, calibration and stable local port. Names use
letters, numbers, hyphens or underscores. If a port is occupied, specify one.

```powershell
.\MouseTrail.exe --profile testing --port 18865
```

The default profile stores data in `%LOCALAPPDATA%\MouseTrailNative`.
Named profiles use its `profiles` subdirectory. Profiles are logical separation
within a Windows account. Use separate Windows accounts for a security boundary.

## Build from source

Install the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) on Windows.

```powershell
dotnet publish .\src\MouseTrail\MouseTrail.csproj -c Release -r win-x64 `
    --self-contained true -o .\deploy\payload
.\deploy\payload\MouseTrail.exe
```

The browser interface uses plain HTML, CSS and JavaScript. No frontend package
manager or third-party JavaScript framework is required.

## IIS and ClickOnce

IIS serves the installation page and downloadable application files. The tracker
runs on the user's PC after installation. Tracking measurements are not uploaded
to the IIS site.

Publish the first release from Windows PowerShell or PowerShell 7.

```powershell
.\deploy\Build-MouseTrail.ps1 -Version 1.1.0.0
```

This builds the self-contained app, obtains the pinned Microsoft manifest tool
if needed, and writes the website into `deploy\site`. For signed releases, add
`-SigningCertificateThumbprint` and optionally `-PublicUrl`.

In **Windows PowerShell 5.1 as Administrator**, create a separate IIS test site.

```powershell
.\deploy\Install-MouseTrailIIS.ps1 -InstallIis `
    -SiteName MouseTrail-Test -PhysicalPath C:\inetpub\MouseTrail-Test `
    -Protocol Http -DnsName localhost -Port 18080
```

The script supports custom ports, HTTPS bindings, an existing certificate,
enterprise CA enrollment, and self-signed certificates for local testing. It
creates a dedicated application pool and sets the website's NTFS permissions
for that pool, administrators and SYSTEM. It rejects unrelated existing sites
and nonempty unmanaged directories.

See [deployment instructions](docs/DEPLOYMENT.md) for certificate handling,
production hosting, updates, firewall options and filesystem permissions.

## Progress so far

| Area | Status |
|---|---|
| Native tracking and session controls | Implemented and exercised through the packaged app |
| History, calibration, export and concurrent named instances | Verified with automated checks |
| Equations, graphs, XY acceleration and themes | Implemented; render checks completed |
| Local IIS HTTP and HTTPS delivery | Tested on real IIS sites |
| Dedicated application-pool permissions | Verified against deployed NTFS ACLs |
| ClickOnce MIME types and application hashes | Verified through downloads from IIS |
| ClickOnce update configuration | Startup update checks present in generated manifests |
| Interactive ClickOnce install and upgrade | Pending |
| Trusted signing and enterprise CA enrollment | Pending an appropriate certificate/domain environment |
| Browser PWA installation | Needs interactive verification across target browsers |

Detailed evidence and limitations are in [validation notes](docs/VALIDATION.md).

## Next steps

- Complete a clean-machine ClickOnce installation and version-upgrade test.
- Validate signing and CA enrollment in the intended deployment environment.
- Test browser installation, reconnection and layout in Edge and Chrome.
- Improve desktop integration, such as tray controls and optional startup.
- Explore per-monitor calibration and richer historical telemetry exports.

## Repository layout

```text
src/MouseTrail/       .NET tracker and web interface
deploy/              Build, publishing, IIS and certificate scripts
deploy/site-template Installation page and IIS configuration
docs/                Deployment guide and verification record
```

Runtime data, certificates, generated release files and build outputs are excluded
from source control. Downloadable packages belong in GitHub Releases.

## License

A distribution license has not yet been selected.
