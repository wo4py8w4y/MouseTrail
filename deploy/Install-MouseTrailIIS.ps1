#Requires -Version 5.1
<#
.SYNOPSIS
Creates an isolated IIS static download site for MouseTrail ClickOnce releases.
.DESCRIPTION
Run in elevated Windows PowerShell 5.1. -WhatIf validates inputs and describes
the operation without changing features, certificates, IIS, files or ACLs.
Use a dedicated empty directory, or an existing directory owned by this script.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$SiteName = 'MouseTrail',
    [string]$SourcePath = (Join-Path $PSScriptRoot 'site'),
    [string]$PhysicalPath = 'C:\inetpub\MouseTrail',
    [ValidateRange(1,65535)][int]$Port = 8443,
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9.-]*$')][string]$DnsName = 'localhost',
    [string]$IPAddress = '*',
    [ValidateSet('Https','Http')][string]$Protocol = 'Https',
    [ValidateSet('Existing','EnterpriseCA','SelfSigned')][string]$CertificateMode = 'Existing',
    [string]$CertificateThumbprint,
    [ValidatePattern('^[a-zA-Z0-9 _-]+$')][string]$CertificateTemplate = 'WebServer',
    [switch]$InstallIis,
    [switch]$OpenFirewall
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath($SourcePath).TrimEnd('\')
$destination = [IO.Path]::GetFullPath($PhysicalPath).TrimEnd('\')
if ($destination -eq [IO.Path]::GetPathRoot($destination).TrimEnd('\')) { throw 'Choose a dedicated subdirectory, not a drive root.' }
if ($destination -eq $source -or $destination.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase) -or $source.StartsWith($destination+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Source and website directories must not overlap.' }
if ($IPAddress -ne '*') { [void][Net.IPAddress]::Parse($IPAddress) }
foreach ($required in @('index.html','web.config','MouseTrail.application')) {
    if (-not (Test-Path -LiteralPath (Join-Path $source $required))) { throw "Publish the release first. Missing $required." }
}
if (Get-ChildItem -LiteralPath $source -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Source contains a link or junction.' }
$marker = Join-Path $destination '.mousetrail-site.json'
if (Test-Path -LiteralPath $destination) {
    if ((Get-Item -LiteralPath $destination).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Website directory must not be a link or junction.' }
    if (@(Get-ChildItem -LiteralPath $destination -Force).Count -gt 0 -and -not (Test-Path -LiteralPath $marker)) { throw 'The target is nonempty and is not a MouseTrail-managed website.' }
    if (Get-ChildItem -LiteralPath $destination -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'Website directory contains a link or junction.' }
    if ((Test-Path -LiteralPath $marker) -and ((Get-Content $marker -Raw | ConvertFrom-Json).SiteName -ne $SiteName)) { throw 'The website directory belongs to another site.' }
}
$url = '{0}://{1}:{2}/' -f $Protocol.ToLowerInvariant(),$DnsName,$Port
if (-not $PSCmdlet.ShouldProcess($destination,"Configure IIS site $SiteName at $url with isolated application-pool read access")) { return }
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run this script from Windows PowerShell as Administrator.' }
if ($PSVersionTable.PSEdition -eq 'Core') { throw 'Use Windows PowerShell 5.1 (powershell.exe) for IIS administration.' }
if ($InstallIis) {
    if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
        $featureResult = Install-WindowsFeature Web-Server,Web-Static-Content,Web-Default-Doc,Web-Filtering,Web-Mgmt-Console,Web-Scripting-Tools
        if (-not $featureResult.Success) { throw 'IIS feature installation failed.' }
        if ($featureResult.RestartNeeded -eq 'Yes') { throw 'Restart Windows, then rerun this command.' }
    } else {
        $features = @('IIS-WebServerRole','IIS-WebServer','IIS-CommonHttpFeatures','IIS-StaticContent','IIS-DefaultDocument','IIS-Security','IIS-RequestFiltering','IIS-ManagementConsole','IIS-ManagementScriptingTools')
        $featureResult = Enable-WindowsOptionalFeature -Online -FeatureName $features -All -NoRestart
        if ($featureResult.RestartNeeded) { throw 'Restart Windows, then rerun this command.' }
    }
}
Import-Module WebAdministration -ErrorAction Stop
$existingSite = Get-Website -Name $SiteName -ErrorAction SilentlyContinue
if ($existingSite -and -not (Test-Path -LiteralPath $marker)) { throw 'This IIS site was not created by the MouseTrail installer. Choose a new site name.' }
if ($existingSite -and [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($existingSite.physicalPath)).TrimEnd('\') -ne $destination) { throw 'An IIS site with this name already uses another directory.' }
$binding = '{0}:{1}:{2}' -f $IPAddress,$Port,$DnsName
foreach ($site in Get-Website) {
    foreach ($entry in $site.bindings.Collection) {
        if ($site.name -ne $SiteName -and $entry.bindingInformation -eq $binding -and $entry.protocol -eq $Protocol.ToLowerInvariant()) { throw "The binding is already used by $($site.name)." }
    }
}
$certificate = $null
if ($Protocol -eq 'Https') {
    switch ($CertificateMode) {
        'Existing' {
            if ($CertificateThumbprint) { $certificate = Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $CertificateThumbprint.Replace(' ','')) }
            else {
                $certificate = Get-ChildItem Cert:\LocalMachine\My | Where-Object {
                    $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date) -and @($_.DnsNameList | ForEach-Object { $_.Unicode }) -contains $DnsName -and @($_.EnhancedKeyUsageList | ForEach-Object { $_.ObjectId }) -contains '1.3.6.1.5.5.7.3.1'
                } | Sort-Object NotAfter -Descending | Select-Object -First 1
            }
            if (-not $certificate) { throw 'No matching HTTPS certificate found. Supply a thumbprint, choose EnterpriseCA, or choose SelfSigned for local testing.' }
        }
        'EnterpriseCA' {
            $enrollment = Get-Certificate -Template $CertificateTemplate -DnsName $DnsName -SubjectName "CN=$DnsName" -CertStoreLocation Cert:\LocalMachine\My
            if ($enrollment.Status -ne 'Issued') { throw 'The enterprise CA did not issue the certificate immediately. Complete approval, then rerun using Existing and its thumbprint.' }
            $certificate = $enrollment.Certificate
        }
        'SelfSigned' {
            $certificate = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation Cert:\LocalMachine\My -Type SSLServerAuthentication -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddYears(1) -FriendlyName "$SiteName local HTTPS"
            Write-Warning 'The self-signed HTTPS certificate is for testing. Browsers and ClickOnce clients must trust it before HTTPS installation can succeed.'
        }
    }
    if (-not $certificate.HasPrivateKey -or $certificate.NotAfter -le (Get-Date) -or $certificate.NotBefore -gt (Get-Date)) { throw 'The HTTPS certificate must be valid and have a private key.' }
    if (@($certificate.EnhancedKeyUsageList | ForEach-Object { $_.ObjectId }) -notcontains '1.3.6.1.5.5.7.3.1') { throw 'The certificate must support Server Authentication.' }
    if (-not @($certificate.DnsNameList.Unicode | Where-Object { $DnsName -like $_ }).Count) { throw 'The certificate does not cover the configured DNS name.' }
}
$pool = "$SiteName-Pool"
if ((Test-Path "IIS:\AppPools\$pool") -and -not $existingSite) { throw 'An application pool with this name already exists. Choose a new site name.' }
if (-not (Test-Path "IIS:\AppPools\$pool")) { New-WebAppPool -Name $pool | Out-Null }
if (@(Get-Website | Where-Object { $_.applicationPool -eq $pool -and $_.name -ne $SiteName }).Count) { throw 'The requested application pool is shared with another site.' }
Set-ItemProperty "IIS:\AppPools\$pool" -Name managedRuntimeVersion -Value ''
Set-ItemProperty "IIS:\AppPools\$pool" -Name processModel.identityType -Value 4
New-Item -ItemType Directory -Path $destination -Force | Out-Null
# Replace access rules only inside the validated, dedicated website tree.
$poolIdentity = [Security.Principal.NTAccount]::new("IIS AppPool\$pool")
$poolSid = $poolIdentity.Translate([Security.Principal.SecurityIdentifier])
$adminSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
$systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
function Set-SiteAcl {
    param([IO.FileSystemInfo]$Item)
    $acl = if ($Item.PSIsContainer) { [Security.AccessControl.DirectorySecurity]::new() } else { [Security.AccessControl.FileSecurity]::new() }
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetOwner($adminSid)
    $inheritance = if ($Item.PSIsContainer) { [Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit' } else { [Security.AccessControl.InheritanceFlags]::None }
    foreach ($sid in @($adminSid,$systemSid)) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl',$inheritance,'None','Allow'))
    }
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($poolSid,'ReadAndExecute',$inheritance,'None','Allow'))
    Set-Acl -LiteralPath $Item.FullName -AclObject $acl
}
Set-SiteAcl (Get-Item -LiteralPath $destination)
# Stage version files first and replace the deployment manifest last.
Get-ChildItem -LiteralPath $source -Force | Where-Object Name -ne 'MouseTrail.application' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $destination -Recurse -Force }
$pendingManifest = Join-Path $destination 'MouseTrail.application.pending'
Copy-Item -LiteralPath (Join-Path $source 'MouseTrail.application') -Destination $pendingManifest -Force
Move-Item -LiteralPath $pendingManifest -Destination (Join-Path $destination 'MouseTrail.application') -Force
@{SiteName=$SiteName;Port=$Port;Url=$url} | ConvertTo-Json | Set-Content -LiteralPath $marker -Encoding UTF8
Get-ChildItem -LiteralPath $destination -Recurse -Force | ForEach-Object { Set-SiteAcl $_ }
if (-not $existingSite) {
    New-Website -Name $SiteName -PhysicalPath $destination -ApplicationPool $pool -IPAddress $IPAddress -Port $Port -HostHeader $DnsName -Ssl:($Protocol -eq 'Https') | Out-Null
} else {
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name applicationPool -Value $pool
    $bindings = @(Get-WebBinding -Name $SiteName)
    if ($bindings.Count -ne 1 -or $bindings[0].bindingInformation -ne $binding -or $bindings[0].protocol -ne $Protocol.ToLowerInvariant()) { throw 'The existing site has different bindings. Adjust its binding explicitly before rerunning.' }
}
if ($Protocol -eq 'Https') {
    Set-WebBinding -Name $SiteName -BindingInformation $binding -PropertyName sslFlags -Value 1
    $httpsBinding = Get-WebBinding -Name $SiteName -Protocol https | Where-Object bindingInformation -eq $binding
    $httpsBinding.AddSslCertificate($certificate.Thumbprint,'My')
}
# Blank anonymous username means use this site's application pool identity.
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location $SiteName -Filter 'system.webServer/security/authentication/anonymousAuthentication' -Name enabled -Value $true
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Location $SiteName -Filter 'system.webServer/security/authentication/anonymousAuthentication' -Name userName -Value ''
if ($OpenFirewall) {
    if ($IPAddress -eq '127.0.0.1') { throw 'A loopback-only site does not need an inbound firewall rule.' }
    $ruleName = "$SiteName-Download-$Port"
    if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name $ruleName -DisplayName "$SiteName download site TCP $Port" -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port | Out-Null
    }
}
Start-WebAppPool -Name $pool
Start-Website -Name $SiteName
Write-Output "Site ready at $url"
Write-Output "Files: $destination"
Write-Output "Anonymous downloads use IIS AppPool\$pool with ReadAndExecute permission."
