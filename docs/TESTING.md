# Run the validation tests

## Full check

1. Open a normal PowerShell window. Administrator access is not required.
2. Copy these commands, paste them, and press Enter.

   ```powershell
   Set-Location D:\MouseTrail
   git pull
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-Validation.ps1
   ```

3. Wait for the app to build and the tests to finish.
4. Check that the summary says **Failed: 0**.
5. The machine-readable report is saved in `TestResults\results.xml`.

The first run downloads the pinned Pester 5.7.1 package from PowerShell Gallery
into this repository's `.tools` folder. It is compatible with Windows PowerShell
5.1. Your globally installed Pester remains available. The full check also needs
the .NET 10 SDK and package-download connectivity on the first build.

Tests start temporary tracker processes on available ports, use temporary data,
and stop those test processes afterwards. The IIS checks use `-WhatIf` and fixtures.
They do not install IIS, change certificates or modify deployed websites.

## Quick script-only check

1. Open PowerShell in the repository folder.
2. Run this command.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-Validation.ps1 -ScriptsOnly
   ```

This skips the .NET build and live tracker tests.

## Use an existing build

After the full check has built the app, run this command to test it again.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-Validation.ps1 -SkipBuild
```

## VS Code

1. Open the `D:\MouseTrail` folder in VS Code.
2. Open **Terminal > New Terminal**.
3. Run the same validation command above.
4. Open `tests\Deployment.Tests.ps1` or `tests\Tracker.Tests.ps1` to inspect the tests.

The validation runner explicitly imports the project's pinned Pester version,
so it works even if VS Code discovers the older Windows-provided version first.

## What is covered

- PowerShell parsing and installer path/ownership validation.
- No filesystem changes from a valid `-WhatIf` run.
- IIS file-extension and ClickOnce MIME rules.
- Loading existing history and calibration.
- Start, pause and finish controls without losing previous totals.
- Saved calibration, invalid-input rejection and token protection.
- CSV export and browser-installation assets.

Actual Windows ClickOnce installation, upgrades, certificate enrollment and
browser layout remain separate interactive/environment-specific checks.
