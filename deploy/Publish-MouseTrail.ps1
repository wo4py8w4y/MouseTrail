#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidatePattern('^\d+\.\d+\.\d+\.\d+$')][string]$Version = '1.1.0.0',
    [string]$PayloadPath = (Join-Path $PSScriptRoot 'payload'),
    [string]$OutputPath = (Join-Path $PSScriptRoot 'site'),
    [uri]$PublicUrl,
    [string]$SigningCertificateThumbprint,
    [string]$MagePath = (Join-Path $PSScriptRoot 'tools/dotnet-mage.exe')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath (Join-Path $PayloadPath 'MouseTrail.exe'))) { throw 'Payload is missing MouseTrail.exe.' }
if (-not (Test-Path -LiteralPath $MagePath)) {
    $toolFolder = Split-Path -Parent $MagePath
    & dotnet tool install --tool-path $toolFolder Microsoft.DotNet.Mage --version 10.0.0
    if ($LASTEXITCODE -ne 0) { throw 'Unable to restore Microsoft dotnet-mage. Check the .NET SDK and NuGet connectivity.' }
}
if ($PublicUrl -and ($PublicUrl.Scheme -notin @('https','http') -or $PublicUrl.Query -or $PublicUrl.Fragment -or $PublicUrl.UserInfo)) { throw 'Use an HTTP or HTTPS directory URL without credentials, query or fragment.' }
if ([version]$Version -ne [version]::Parse($Version)) { throw 'Invalid release version.' }
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
$versionFolder = Join-Path $OutputPath "ApplicationFiles/$Version"
if (Test-Path -LiteralPath $versionFolder) { throw "Release $Version already exists. Publish each update with a new version number." }
New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
Copy-Item -Path (Join-Path $PayloadPath '*') -Destination $versionFolder -Recurse -Force
function Invoke-Mage {
    param([string[]]$Arguments)
    & $MagePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Manifest generation failed with exit code $LASTEXITCODE." }
}
Invoke-Mage -Arguments @('-AddLauncher','MouseTrail.exe','-TargetDirectory',$versionFolder)
$application = Join-Path $versionFolder 'MouseTrail.exe.manifest'
Invoke-Mage -Arguments @('-New','Application','-ToFile',$application,'-Name','MouseTrail','-Version',$Version,'-Processor','msil','-FromDirectory',$versionFolder,'-UseManifestForTrust','true','-Publisher','MouseTrail')
if ($SigningCertificateThumbprint) {
    Invoke-Mage -Arguments @('-Sign',$application,'-CertHash',$SigningCertificateThumbprint)
    Invoke-Mage -Arguments @('-Verify',$application)
}
# Hashes refer to original filenames. ClickOnce removes .deploy during download.
Get-ChildItem -LiteralPath $versionFolder -File -Recurse | Where-Object Extension -ne '.manifest' | ForEach-Object {
    Rename-Item -LiteralPath $_.FullName -NewName ($_.Name + '.deploy')
}
$deployment = Join-Path $OutputPath 'MouseTrail.application.new'
$arguments = @('-New','Deployment','-ToFile',$deployment,'-Name','MouseTrail','-Version',$Version,'-Processor','msil','-Install','true','-MapFileExtensions','true','-AppManifest',$application,'-AppCodeBase',"ApplicationFiles/$Version/MouseTrail.exe.manifest",'-Publisher','MouseTrail')
if ($PublicUrl) {
    $arguments += @('-ProviderURL',($PublicUrl.AbsoluteUri.TrimEnd('/') + '/MouseTrail.application'))
} else {
    # Without a provider URL, ClickOnce checks for updates at the original install URL.
    $arguments += @('-IncludeProviderURL','false')
}
Invoke-Mage -Arguments $arguments
if ($SigningCertificateThumbprint) {
    Invoke-Mage -Arguments @('-Sign',$deployment,'-CertHash',$SigningCertificateThumbprint)
    Invoke-Mage -Arguments @('-Verify',$deployment)
}
Copy-Item -Path (Join-Path $PSScriptRoot 'site-template/*') -Destination $OutputPath -Force
$page = Get-Content -LiteralPath (Join-Path $OutputPath 'index.html') -Raw
$page.Replace('__VERSION__',$Version) | Set-Content -LiteralPath (Join-Path $OutputPath 'index.html') -Encoding UTF8
# Replace the entry manifest last so clients never see a partially copied release.
Move-Item -LiteralPath $deployment -Destination (Join-Path $OutputPath 'MouseTrail.application') -Force
Write-Output "Published release $Version to $OutputPath"
if (-not $SigningCertificateThumbprint) { Write-Warning 'This preview has unsigned ClickOnce manifests. For trusted deployment, republish with a code-signing certificate.' }
