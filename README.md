# MouseTrail

A Windows mouse-movement tracker with live graphs, an acceleration crosshair,
colour themes, and a browser dashboard. Your tracking data stays on your PC.

**Start with one of the two options below.**

## Option 1 — Run MouseTrail

1. Open the [download page](https://github.com/wo4py8w4y/MouseTrail/releases/tag/v1.1.0-preview).
2. Download **MouseTrail-Windows-v1.1.zip**.
3. Right-click the downloaded ZIP and select **Properties**.
4. If **Unblock** appears, select it and click **OK**.
5. Right-click the ZIP and select **Extract All**. Choose a folder you want to keep.
6. Open that folder and double-click **MouseTrail.exe**. Keep the `www` folder beside it.
7. Leave the tracker window open. Your browser should open the dashboard.
8. If the browser does not open, visit [the local dashboard](http://127.0.0.1:8765/).
9. Click **Start tracking** and move your mouse.
10. Use **Pause & save** to pause. Use **Finish session** to save and start fresh.

**Expected result** — the pixel counter changes and the graphs show your movement.
Windows x64 is required. Python and a separate .NET installation are not needed.

To choose a theme, use the **Theme** list at the top of the page.
To calibrate distance, enter your screen PPI in **Screen calibration** and click
**Save calibration**. The calibration link helps you find the value for your screen.

## Option 2 — Set up the IIS download website

Use this option to let people install MouseTrail from your own website.

1. Download **MouseTrail-IIS.zip** from the [download page](https://github.com/wo4py8w4y/MouseTrail/releases/tag/v1.1.0-preview).
2. Follow [the numbered IIS setup steps](docs/DEPLOYMENT.md#1-set-up-a-local-iis-download-site).
3. Open the installation page created by the script.
4. Click **Install MouseTrail for Windows**.

The guide covers downloading, unblocking, extracting, opening the correct admin
PowerShell window, copying the setup command, and checking the result.

## Install the browser shortcut

1. Start **MouseTrail.exe**.
2. Open its dashboard in Edge or Chrome.
3. Click **Install app**, or use the browser's install option.
4. Keep **MouseTrail.exe** running whenever you use that shortcut.

## What is working

- Live distance, speed, sampling-time and movement graphs.
- XY acceleration crosshair and scrolling telemetry console.
- Session history, calibration and CSV export.
- Four colour themes and separate named instances.
- Self-contained Windows executable.
- Separate IIS site, configurable ports, application-pool permissions and HTTPS setup.
- ClickOnce download files with startup update checks.

## Progress and remaining checks

| Area | Result |
|---|---|
| Native tracking, history, calibration and CSV export | Automated checks passed |
| Concurrent named instances | Isolation checks passed |
| Local IIS HTTP and HTTPS delivery | Tested on this development PC |
| IIS permissions and ClickOnce download hashes | Verified |
| Interactive ClickOnce installation and version upgrades | Still to verify |
| Production signing and enterprise CA enrollment | Needs the intended certificate/domain environment |
| Browser installation | Needs interactive verification in target browsers |

**This is an unsigned preview.** Unblocking a downloaded file removes its download
mark. It does not sign the app or establish publisher/certificate trust. Windows
or organisation policy may still restrict installation.

## More instructions

- [Step-by-step IIS setup, certificates and updates](docs/DEPLOYMENT.md)
- [Detailed deployment reference](docs/DEPLOYMENT-REFERENCE.md)
- [Verification results](docs/VALIDATION.md)
- [Changes so far](CHANGELOG.md)

The original concept came from [Mouse Distance Tracker for PowerShell](https://github.com/wo4py8w4y/Mouse-Distance-Tracker-ps1).

## Source code

The application is in `src/MouseTrail`. Deployment scripts are in `deploy`.
To build it yourself, follow [the source build steps](docs/DEPLOYMENT.md#4-build-and-publish-an-update).

## License

A distribution license has not yet been selected.
