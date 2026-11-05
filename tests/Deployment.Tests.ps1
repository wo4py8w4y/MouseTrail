BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    $installer = Join-Path $repo 'deploy/Install-MouseTrailIIS.ps1'
}

Describe 'PowerShell deployment validation' {
    It 'parses all deployment scripts without errors' {
        foreach ($file in Get-ChildItem (Join-Path $repo 'deploy') -Filter '*.ps1') {
            $tokens = $null
            $parseErrors = $null
            [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            @($parseErrors).Count | Should -Be 0 -Because "$($file.Name) must parse in this PowerShell version"
        }
    }

    Context 'Installer path and ownership checks' {
        BeforeEach {
            $source = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            $destination = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $source | Out-Null
            foreach ($file in @('index.html','web.config','MouseTrail.application')) {
                Set-Content (Join-Path $source $file) 'fixture'
            }
        }

        It 'validates an empty target with WhatIf without creating files' {
            { & $installer -SourcePath $source -PhysicalPath $destination -SiteName PesterMouseTrail -Protocol Http -Port 18888 -WhatIf } | Should -Not -Throw
            Test-Path -LiteralPath $destination | Should -BeFalse
        }

        It 'rejects a destination inside the source' {
            { & $installer -SourcePath $source -PhysicalPath (Join-Path $source 'child') -WhatIf } | Should -Throw '*must not overlap*'
        }

        It 'rejects an unmanaged nonempty directory and preserves its file' {
            New-Item -ItemType Directory -Path $destination | Out-Null
            $existing = Join-Path $destination 'existing.txt'
            Set-Content $existing 'keep this'
            { & $installer -SourcePath $source -PhysicalPath $destination -WhatIf } | Should -Throw '*not a MouseTrail-managed*'
            (Get-Content $existing -Raw).Trim() | Should -Be 'keep this'
        }

        It 'rejects a folder owned by another website' {
            New-Item -ItemType Directory -Path $destination | Out-Null
            Set-Content (Join-Path $destination '.mousetrail-site.json') '{"SiteName":"AnotherWebsite"}'
            { & $installer -SourcePath $source -PhysicalPath $destination -SiteName PesterMouseTrail -WhatIf } | Should -Throw '*belongs to another site*'
        }

        It 'rejects a missing published manifest' {
            Remove-Item -LiteralPath (Join-Path $source 'MouseTrail.application')
            { & $installer -SourcePath $source -PhysicalPath $destination -WhatIf } | Should -Throw '*Missing MouseTrail.application*'
        }

        It 'rejects an invalid port before making changes' {
            { & $installer -SourcePath $source -PhysicalPath $destination -Port 65536 -WhatIf } | Should -Throw
            Test-Path -LiteralPath $destination | Should -BeFalse
        }
    }

    It 'allows the install page and ClickOnce downloads in the IIS template' {
        [xml]$config = Get-Content (Join-Path $repo 'deploy/site-template/web.config') -Raw
        $rules = $config.configuration.'system.webServer'.security.requestFiltering.fileExtensions.add
        foreach ($extension in @('.','.html','.application','.manifest','.deploy')) {
            @($rules | Where-Object { $_.fileExtension -eq $extension -and $_.allowed -eq 'true' }).Count | Should -Be 1
        }
        $mime = $config.configuration.'system.webServer'.staticContent.mimeMap
        ($mime | Where-Object fileExtension -eq '.application').mimeType | Should -Be 'application/x-ms-application'
        ($mime | Where-Object fileExtension -eq '.manifest').mimeType | Should -Be 'application/x-ms-manifest'
        ($mime | Where-Object fileExtension -eq '.deploy').mimeType | Should -Be 'application/octet-stream'
    }
}
