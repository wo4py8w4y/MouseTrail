#Requires -Version 5.1
[CmdletBinding()]
param([switch]$ScriptsOnly, [switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$modulePath = Join-Path $PSScriptRoot '.tools/Pester/5.7.1'
$manifest = Join-Path $modulePath 'Pester.psd1'
if (-not (Test-Path -LiteralPath $manifest)) {
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    $archive = Join-Path $PSScriptRoot '.tools/Pester.5.7.1.zip'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://www.powershellgallery.com/api/v2/package/Pester/5.7.1' -OutFile $archive
    Expand-Archive -LiteralPath $archive -DestinationPath $modulePath -Force
}
Import-Module $manifest -Force
if (-not $ScriptsOnly -and -not $SkipBuild) {
    & dotnet publish (Join-Path $PSScriptRoot 'src/MouseTrail/MouseTrail.csproj') -c Release -r win-x64 --self-contained true -o (Join-Path $PSScriptRoot 'deploy/payload')
    if ($LASTEXITCODE -ne 0) { throw 'Application build failed.' }
}
$configuration = New-PesterConfiguration
$configuration.Run.Path = if ($ScriptsOnly) { Join-Path $PSScriptRoot 'tests/Deployment.Tests.ps1' } else { Join-Path $PSScriptRoot 'tests' }
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputPath = Join-Path $PSScriptRoot 'TestResults/results.xml'
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'TestResults') -Force | Out-Null
$result = Invoke-Pester -Configuration $configuration
if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) { exit 1 }
