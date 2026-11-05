#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+\.\d+$')][string]$Version,
    [uri]$PublicUrl,
    [string]$SigningCertificateThumbprint
)
$ErrorActionPreference='Stop'
$payload = Join-Path $PSScriptRoot 'payload'
& dotnet publish (Join-Path $PSScriptRoot '../src/MouseTrail/MouseTrail.csproj') -c Release -r win-x64 --self-contained true "-p:Version=$Version" -o $payload
if ($LASTEXITCODE -ne 0) { throw 'Build failed. Install the .NET 10 SDK on the publishing computer if needed.' }
$parameters = @{Version=$Version;PayloadPath=$payload}
if ($PublicUrl) { $parameters.PublicUrl=$PublicUrl }
if ($SigningCertificateThumbprint) { $parameters.SigningCertificateThumbprint=$SigningCertificateThumbprint }
& (Join-Path $PSScriptRoot 'Publish-MouseTrail.ps1') @parameters
