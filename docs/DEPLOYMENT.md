# MouseTrail IIS deployment kit

This package contains a self-contained Windows x64 tracker, an IIS installation
page, ClickOnce manifests with update checks, and scripts for site configuration,
certificates, permissions and future releases.

## Quick local IIS test

For the IIS release ZIP, extract it. For a source checkout, first run the build script and enter the `deploy` directory. In **Windows PowerShell 5.1 as Administrator**, run the
following from the extracted directory. The port is configurable.

```powershell
.\Install-MouseTrailIIS.ps1 -InstallIis -SiteName MouseTrail-Test `
    -PhysicalPath C:\inetpub\MouseTrail-Test `
    -Protocol Http -DnsName localhost -Port 18080
```

Open `http://localhost:18080/` in Edge and select **Install MouseTrail for Windows**.
ClickOnce must be permitted by the browser and machine policy. If the browser
downloads `MouseTrail.application`, open it to start installation. The supplied
preview manifests are unsigned. Trust policy can block them. For normal deployment,
publish with a code-signing certificate trusted by your intended clients.

The initial ClickOnce provider URL is intentionally omitted. This lets the same
package use the original HTTP installation URL as its update location. Install
from the site rather than copying a deployment manifest into an unrelated folder.
Keep the installation URL stable for existing users. Once your hostname is known,
use `-PublicUrl` when publishing the next release to set a permanent update URL.

## IIS features, binding and permissions

`-InstallIis` installs Windows optional features on desktop Windows, or the IIS
role services on Windows Server. It stops and requests a restart if required.
The script creates a dedicated application pool with ApplicationPoolIdentity,
no managed runtime, anonymous downloads running as that pool identity, and no
directory listing. The server only serves static installation files.

The destination must be empty or previously created by this script. Existing
unrelated sites and directories are rejected. Source and destination paths must
not overlap. Links and junctions in either tree are rejected.

The script replaces permissions inside the dedicated site tree with protected
NTFS ACLs. Administrators and SYSTEM receive FullControl. The specific
`IIS AppPool\<SiteName>-Pool` receives ReadAndExecute. General Users, IUSR and
the broad IIS_IUSRS group receive no explicit access. This means your normal
unelevated account may be unable to browse the deployed folder; use an elevated
session to publish or inspect it. Private keys are stored in certificate stores,
outside the website directory.

`-Port` selects the website port. The default is HTTPS 8443. Production HTTPS
normally uses 443. Port 143 is normally IMAP. `-IPAddress` defaults to `*` so
both IPv4 and IPv6 localhost requests work. `-DnsName` supplies the Host binding
and certificate name. No firewall rule is created unless `-OpenFirewall` is passed.
Configure DNS and upstream firewall/NAT rules separately for public hosting.

## HTTPS certificates

Use an existing certificate from LocalMachine\My with a private key and Server
Authentication usage. If its thumbprint is omitted, the script searches for a
valid certificate matching the DNS name.

```powershell
.\Install-MouseTrailIIS.ps1 -SiteName MouseTrail `
    -PhysicalPath C:\inetpub\MouseTrail -DnsName downloads.example.com `
    -Port 443 -CertificateMode Existing -CertificateThumbprint YOUR_THUMBPRINT `
    -OpenFirewall
```

For an available enterprise CA, use `-CertificateMode EnterpriseCA` and optionally
`-CertificateTemplate WebServer`. The Windows enrollment policy selects the CA.
Your account/computer must have enrollment permission and the template must allow
the requested subject and DNS name. A pending request stops setup for CA approval.
The script does not install or modify a CA.

For a local HTTPS test, use a different dedicated site and directory.

```powershell
.\Install-MouseTrailIIS.ps1 -SiteName MouseTrail-TLS-Test `
    -PhysicalPath C:\inetpub\MouseTrail-TLS-Test `
    -DnsName localhost -Port 18443 -CertificateMode SelfSigned
```

The script generates a non-exportable test HTTPS key and binds its certificate
using SNI. A self-signed certificate is not automatically trusted by browsers or
ClickOnce. The script deliberately leaves trust-store enrollment to your normal
certificate-management process. Reuse the issued certificate with `Existing` on
later runs rather than generating another test certificate.

## ClickOnce signing and updates

HTTPS certificates and ClickOnce code-signing certificates have different usages.
Use a Code Signing certificate with a private key in the publisher's CurrentUser\My
store. Obtain one from an enterprise CA if available.

```powershell
.\New-MouseTrailSigningCertificate.ps1 -Mode EnterpriseCA -Template CodeSigning
.\Publish-MouseTrail.ps1 -Version 1.1.0.1 `
    -PublicUrl https://downloads.example.com/ `
    -SigningCertificateThumbprint YOUR_CODE_SIGNING_THUMBPRINT
```

The signing helper also supports `-Mode SelfSigned` for development. Clients must
trust the signing identity through their normal administrative process. For
public distribution, use a suitable publicly trusted code-signing identity.

Publish from the same Windows user that holds the signing key. The bundled
Microsoft dotnet-mage tool requires .NET on the publishing machine. End users
receive a self-contained .NET app. Windows ClickOnce infrastructure is also
required on clients; it is provided by Windows/.NET Framework on supported Windows.

Every release must have a new four-part version. Old version folders are retained.
The release files are copied before the entry deployment manifest is replaced, so
downloads see a complete version. ClickOnce checks for updates before starting.
Close any running tracker before accepting an application update.

To build source changes, install the .NET 10 SDK on the build machine, then run
`Build-MouseTrail.ps1` with a new version and signing thumbprint. That script builds
the bundled source into `payload` and publishes it to `site`.

To deploy a new release, run the IIS installation script again using the same
site name, directory, port and certificate. It copies the updated `site` folder
and restores the strict ACLs. To change bindings, update the site's binding
explicitly first. The script refuses unexpected existing bindings.

## Named local instances

The default instance preserves existing MouseTrailNative history. To run separate
instances, launch the payload executable with different names.

```powershell
.\payload\MouseTrail.exe --profile work
.\payload\MouseTrail.exe --profile testing
```

Names use 1–32 letters, numbers, underscores or hyphens. Each name gets its own
data directory and stable local port. If that port is already used, supply
`--port 18865`. Each instance observes the same desktop cursor but maintains
separate sessions, calibration and history. This is logical separation within
your Windows account, not a security boundary between mutually untrusted users.
Use different Windows accounts for that boundary.

Theme choices are saved per browser origin. Available themes are Midnight mint,
Amber terminal, Cyan lab and Violet spectrum. Enter 170 PPI for the screen discussed
during development; other screens need their own calibration.

## Package contents

- `site` — upload or deploy this directory to IIS.
- `site-template` — editable install-page and IIS configuration templates.
- `payload` — portable app files, used to create future deployments.
- `src` — application source and browser interface.
- `tools` — Microsoft dotnet-mage tooling, including its hidden .store directory.
- PowerShell scripts — publishing, builds, IIS setup and certificate enrollment.

Raw cursor samples stay in memory. History stores per-session summary metrics.
The website only distributes files; it receives no cursor measurements.
