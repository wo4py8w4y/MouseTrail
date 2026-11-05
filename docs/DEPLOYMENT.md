# MouseTrail setup — step by step

## 1. Set up a local IIS download site

These steps use the **IIS release ZIP**. They do not require a source-code build.
The example uses a separate site named `MouseTrail` on port **18088**.

### Step 1 — Download the kit

Open the [release page](https://github.com/wo4py8w4y/MouseTrail/releases/tag/v1.1.0-preview).
Download **MouseTrail-IIS.zip** into your **Downloads** folder.

### Step 2 — Unblock the ZIP

In File Explorer, right-click **MouseTrail-IIS.zip** and select **Properties**.
If **Unblock** appears near the bottom, select it and click **OK**.

Unblock removes the Windows download mark. It does not sign the app or make an
untrusted publisher or HTTPS certificate trusted.

### Step 3 — Extract it

Right-click the ZIP and select **Extract All**.
Enter `C:\MouseTrail-Setup` as the destination and select **Extract**.

Open `C:\MouseTrail-Setup\MouseTrail-IIS`.
You should see **Install-MouseTrailIIS.ps1** and a folder named **site**.

### Step 4 — Open an administrator PowerShell window

Click **Start**, type **Windows PowerShell**, right-click **Windows PowerShell**,
and select **Run as administrator**. Accept the Windows approval prompt.

Use **Windows PowerShell 5.1** for IIS setup. The command below explicitly starts
that version even if your terminal normally uses PowerShell 7.

### Step 5 — Copy and run this command

Paste the entire command into the administrator window and press Enter.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\MouseTrail-Setup\MouseTrail-IIS\Install-MouseTrailIIS.ps1" -InstallIis -SiteName MouseTrail -PhysicalPath "C:\inetpub\MouseTrail" -Protocol Http -DnsName localhost -Port 18088
```

The execution-policy setting applies to this new PowerShell process and ends when
it exits. It does not change the machine's permanent policy. Organisation Group
Policy can still take precedence.

Wait for setup to finish. If it requests a Windows restart, restart and run the
same command again.

### Step 6 — Check the result

The last output should include **Site ready at http://localhost:18088/**.
Open [the new local installation page](http://localhost:18088/) in Edge.
You should see a MouseTrail page with an **Install MouseTrail for Windows** button.

If the installer reports a name, directory or port conflict, stop and choose a new
site name, destination and unused port. Existing sites are not taken over.

### Step 7 — Try the application installation

Click **Install MouseTrail for Windows**.
If Edge downloads **MouseTrail.application**, open that file.

Follow the Windows installation prompts. This preview is unsigned, so Windows or
organisation policy may block it. Record any error for the signing/install test.
Unblock-File does not resolve an untrusted publisher or certificate.

After a successful installation, open **MouseTrail** from Start. Keep its tracker
window open and click **Start tracking** in the dashboard.

### Step 8 — Check that it works

Move the mouse and check that the pixel counter changes. Click **Pause & save**.
Open a new session, then check that the previous session remains in history.

The browser dashboard normally uses `http://127.0.0.1:8765`. The IIS download page
uses `http://localhost:18088`. They are separate parts of the application.

## 2. Test HTTPS locally

Complete Section 1 first. Use another site and port for this test.

1. Open **Windows PowerShell as Administrator**.
2. Paste this command and press Enter.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\MouseTrail-Setup\MouseTrail-IIS\Install-MouseTrailIIS.ps1" -SiteName MouseTrail-HTTPS -PhysicalPath "C:\inetpub\MouseTrail-HTTPS" -DnsName localhost -Port 18488 -CertificateMode SelfSigned
   ```

3. Wait for **Site ready at https://localhost:18488/**.
4. Open `https://localhost:18488/` in Edge.
5. Expect a certificate trust warning until the certificate is trusted through your
   normal certificate-management process. The script creates the certificate and
   binding, but does not add it to a trusted root store.
6. Use a trusted certificate for normal installation and production distribution.

For enterprise CA enrollment or an existing certificate, follow the
[certificate reference](DEPLOYMENT-REFERENCE.md#https-certificates).

## 3. Run validation

The repository's validation steps are in [TESTING.md](TESTING.md).
They cover script checks and the native app. The interactive installation above
is a separate test.

## 4. Build and publish an update

These steps use a **source checkout**, such as `D:\MouseTrail`.
You need Git and the .NET 10 SDK on this publishing computer.

1. Open a normal PowerShell window.
2. Go to the repository and pull the latest changes.

   ```powershell
   Set-Location D:\MouseTrail
   git pull
   ```

3. Build a new version. Every release needs a new four-part version number.
   This example uses `1.1.0.1`; choose a higher unused number for later updates.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\deploy\Build-MouseTrail.ps1 -Version 1.1.0.1
   ```

4. Wait for the build and publishing commands to finish. The new site is in
   `D:\MouseTrail\deploy\site`.
5. Open **Windows PowerShell as Administrator**.
6. Deploy that site using the **same name, directory and port** used in Section 1.

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\MouseTrail\deploy\Install-MouseTrailIIS.ps1" -SiteName MouseTrail -PhysicalPath "C:\inetpub\MouseTrail" -Protocol Http -DnsName localhost -Port 18088
   ```

7. On the client, close the running tracker and open MouseTrail again from Start.
8. Check whether ClickOnce offers the new version. Record the installed version
   and confirm that session history remains available.

For production signing, obtain a trusted code-signing certificate first and pass
its thumbprint when publishing. Use the same signing identity for subsequent
releases. The [signing reference](DEPLOYMENT-REFERENCE.md#clickonce-signing-and-updates)
explains the relevant parameters.

## If PowerShell blocks a script

1. Confirm the script came from this repository or its release package.
2. Unblock that specific file if it was downloaded separately.

   ```powershell
   Unblock-File -LiteralPath "C:\MouseTrail-Setup\MouseTrail-IIS\Install-MouseTrailIIS.ps1"
   ```

3. Use the explicit `powershell.exe -ExecutionPolicy Bypass -File ...` command in
   the setup steps. It applies only to that process.
4. If Group Policy still blocks the script, use your organisation's approved
   signing/deployment process.

Microsoft documents the behaviour of [execution-policy scopes](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies)
and [Unblock-File](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/unblock-file).
