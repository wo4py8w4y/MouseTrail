BeforeAll {
    $repo = Split-Path -Parent $PSScriptRoot
    $executable = Join-Path $repo 'deploy/payload/MouseTrail.exe'
    if (-not (Test-Path $executable)) { throw 'Build the app first or run Invoke-Validation.ps1.' }

    function Start-TestTracker {
        $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
        $listener.Start()
        $port = $listener.LocalEndpoint.Port
        $listener.Stop()
        $data = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $data | Out-Null
        Set-Content (Join-Path $data 'history.json') '{"Dpi":144,"Sessions":[{"id":1,"started":"2026-01-01T00:00:00+00:00","pixels":1000,"seconds":10,"samples":20,"dpi":144}]}'
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $executable
        $info.Arguments = "--profile pester --port $port"
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.EnvironmentVariables['MOUSETRAIL_DATA'] = $data
        $info.EnvironmentVariables['MOUSETRAIL_NO_BROWSER'] = '1'
        $process = [Diagnostics.Process]::Start($info)
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $client = [pscustomobject]@{ Process=$process; Base="http://127.0.0.1:$port"; Headers=@{}; Data=$data; Output=$output; Errors=$errors }
        try {
            for ($attempt=0; $attempt -lt 100; $attempt++) {
                if ($process.HasExited) { throw "Tracker exited during startup: $($errors.Result)" }
                try {
                    $page = Invoke-WebRequest -UseBasicParsing -Uri $client.Base -TimeoutSec 2
                    if ($page.Content -match "const token='([^']+)'") {
                        $client.Headers['X-MouseTrail-Token'] = $matches[1]
                        return $client
                    }
                } catch [Net.WebException] { }
                Start-Sleep -Milliseconds 100
            }
            throw 'Tracker did not start in time.'
        } catch {
            if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
            $process.Dispose()
            throw
        }
    }

    function Invoke-TestCommand {
        param($Client, [string]$Command, [hashtable]$Body = @{})
        Invoke-RestMethod -Uri ($Client.Base + '/api/' + $Command) -Headers $Client.Headers -Method Post -ContentType 'application/json' -Body ($Body | ConvertTo-Json) -TimeoutSec 5
    }
}

Describe 'Packaged Windows tracker' {
    BeforeEach { $client = $null; $client = Start-TestTracker }
    AfterEach {
        if ($client) {
            if (-not $client.Process.HasExited) { $client.Process.Kill(); $client.Process.WaitForExit() }
            $client.Process.Dispose()
        }
    }

    It 'loads existing history and screen calibration' {
        $state = Invoke-RestMethod ($client.Base + '/api/state') -Headers $client.Headers
        $state.dpi | Should -Be 144
        $state.lifetime_pixels | Should -Be 1000
        $state.history.Count | Should -Be 1
    }

    It 'starts, pauses and finishes a session while retaining old totals' {
        (Invoke-TestCommand $client start).running | Should -BeTrue
        Start-Sleep -Milliseconds 250
        $paused = Invoke-TestCommand $client pause
        $paused.running | Should -BeFalse
        $finished = Invoke-TestCommand $client new
        $finished.pixels | Should -Be 0
        $finished.lifetime_pixels | Should -BeGreaterOrEqual 1000
        $finished.history.Count | Should -Be 2
    }

    It 'persists a changed calibration to disk' {
        (Invoke-TestCommand $client dpi @{dpi=170}).dpi | Should -Be 170
        (Get-Content (Join-Path $client.Data 'history.json') -Raw | ConvertFrom-Json).Dpi | Should -Be 170
    }

    It 'rejects invalid calibration without changing the saved value' {
        { Invoke-TestCommand $client dpi @{dpi=0} } | Should -Throw
        (Invoke-RestMethod ($client.Base + '/api/state') -Headers $client.Headers).dpi | Should -Be 144
    }

    It 'rejects API requests without the instance access token' {
        { Invoke-RestMethod ($client.Base + '/api/state') -TimeoutSec 5 } | Should -Throw
    }

    It 'exports existing session totals as CSV' {
        $response = Invoke-WebRequest -UseBasicParsing -Uri ($client.Base + '/api/export') -Headers $client.Headers
        $rows = $response.Content | ConvertFrom-Csv
        @($rows).Count | Should -Be 1
        $rows.pixels | Should -Be '1000'
    }

    It 'serves the browser install manifest and offline page' {
        $manifest = Invoke-RestMethod ($client.Base + '/manifest.webmanifest')
        $manifest.display | Should -Be 'standalone'
        foreach ($asset in @('/sw.js','/offline.html','/icon-192.png','/icon-512.png')) {
            (Invoke-WebRequest -UseBasicParsing ($client.Base + $asset)).StatusCode | Should -Be 200
        }
    }
}
