# Verification results

Verified on the Windows development computer on 6 November 2026.

## Repeatable Pester check

The repository now includes `Invoke-Validation.ps1` and two Pester test files.
The full run on Windows PowerShell 5.1 with project-local Pester 5.7.1 completed
with **15 passed, 0 failed, 0 skipped**. Eight tests cover deployment-script
validation and seven exercise the packaged Windows tracker. No failing findings
were recorded in this run. See [the test instructions](TESTING.md) to repeat it.

## Earlier integration checks

| Check | Result |
|---|---|
| Self-contained executable startup | Passed |
| Windows cursor polling and session controls | Passed |
| History and calibration after process restart | Passed |
| Two concurrent named instances with separate history, calibration and access tokens | Passed |
| Dashboard equations, six plots, signed acceleration and themes' script syntax | Passed automated rendering checks |
| IIS installed through Windows optional features | Passed |
| Dedicated HTTP site on port 18080 | Passed, normal localhost URL returned 200 |
| Dedicated HTTPS site on port 18443 | Passed with generated self-signed certificate; test client explicitly disabled certificate trust validation |
| Application-pool NTFS permissions | Verified protected ACLs with SYSTEM and Administrators FullControl, dedicated pool ReadAndExecute |
| Anonymous identity | Verified use of application pool identity |
| ClickOnce MIME types | Passed over IIS |
| Deployment manifest and all eight application-file hashes | Verified against files downloaded through IIS |
| ClickOnce update setting | Verified before-application-startup checks in the deployment manifest |
| Private website configuration and ownership marker | Returned 404 |
| PowerShell scripts | Parsed successfully; WhatIf validated |

The local computer is not domain joined. Enterprise CA enrollment could not be
exercised here. The script includes Windows certificate enrollment with explicit
template selection and handling for requests that require CA approval.

The supplied ClickOnce manifests are unsigned preview manifests. A complete
interactive ClickOnce installation, subsequent version upgrade, and trusted
certificate deployment have not been verified. Code-signing support is included
but requires your publishing certificate. Browser PWA installation also requires
interactive verification in your target browser.

Local test sites remain installed as MouseTrail-Test and MouseTrail-TLS-Test,
with dedicated folders beneath C:\inetpub. No firewall rule was requested.
Self-signed test HTTPS certificates were created in LocalMachine\My; none were
added to a trusted root store. The currently running tracker was calibrated to
170 PPI as requested. The build was published separately to avoid replacing the
executable being used during testing.

The Exchange dashboard's UI branch contains Install-PrivateRepoAPI.ps1. It
generates a self-signed certificate for a Pode API and does not configure IIS or
enroll from an enterprise CA. Its general setup flow informed the new installer;
the IIS and enrollment implementation is specific to this package.
