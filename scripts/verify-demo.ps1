$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $root
try {
  moon fmt --check
  if ($LASTEXITCODE -ne 0) { throw 'moon fmt --check failed' }

  moon check --target native --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'moon check failed' }

  moon build --target native --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'moon build failed' }

  moon test --target native --deny-warn
  if ($LASTEXITCODE -ne 0) { throw 'moon test failed' }

  $binary = Join-Path $root '_build/native/debug/build/cmd/main/main.exe'
  $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $processInfo.FileName = $binary
  $processInfo.Arguments = 'config validate --config examples/offline/moonarch.json'
  $processInfo.WorkingDirectory = $root
  $processInfo.UseShellExecute = $false
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $processInfo
  [void]$process.Start()
  $process.StandardOutput.Close()
  $process.WaitForExit()
  $stdoutFailureCode = $process.ExitCode
  $processError = $process.StandardError.ReadToEnd()
  $process.Dispose()
  if ($stdoutFailureCode -ne 3) {
    throw "expected stdout write failure to return 3, got $stdoutFailureCode; stderr: $processError"
  }

  moon run cmd/main --target native -- config validate --config examples/offline/moonarch.json
  if ($LASTEXITCODE -ne 0) { throw 'offline configuration validation failed' }

  moon run cmd/main --target native -- check --config _build/missing-config.json --graph examples/offline/graph.json
  if ($LASTEXITCODE -ne 2) { throw "expected configuration input error to return 2, got $LASTEXITCODE" }

  moon run cmd/main --target native -- check --config examples/offline/moonarch.json --graph _build/missing-graph.json
  if ($LASTEXITCODE -ne 3) { throw "expected graph input error to return 3, got $LASTEXITCODE" }

  moon run cmd/main --target native -- check --config examples/offline/moonarch.json --graph examples/offline/graph.json
  if ($LASTEXITCODE -ne 1) { throw "expected new findings to return 1, got $LASTEXITCODE" }

  moon run cmd/main --target native -- baseline create --output _build/demo-baseline.json --config examples/offline/moonarch.json --graph examples/offline/graph.json
  if ($LASTEXITCODE -ne 0) { throw 'baseline creation failed' }
  $generatedBaseline = Get-Content -Raw -LiteralPath '_build/demo-baseline.json' | ConvertFrom-Json
  $checkedInBaseline = Get-Content -Raw -LiteralPath 'examples/offline/baseline.json' | ConvertFrom-Json
  if (($generatedBaseline.fingerprints -join "`n") -ne ($checkedInBaseline.fingerprints -join "`n")) {
    throw 'generated baseline differs from the checked-in example baseline'
  }

  moon run cmd/main --target native -- check --config examples/offline/moonarch-baselined.json --graph examples/offline/graph.json --format json --output _build/offline-report.json
  if ($LASTEXITCODE -ne 0) { throw 'baselined offline check failed' }
  $offlineReport = Get-Content -Raw -LiteralPath '_build/offline-report.json' | ConvertFrom-Json
  if ($offlineReport.counts.new -ne 0 -or $offlineReport.counts.existing -ne 4) {
    throw 'baselined JSON report has unexpected finding counts'
  }
  if ((Get-Content -Raw -LiteralPath '_build/offline-report.json').Contains([char]27)) {
    throw 'machine-readable JSON report unexpectedly contains ANSI control codes'
  }

  moon run cmd/main --target native -- check --config examples/workspace/moonarch.json --workspace examples/workspace --format markdown --output _build/live-report.md
  if ($LASTEXITCODE -ne 0) { throw 'live workspace check failed' }
  $liveReport = Get-Content -Raw -LiteralPath '_build/live-report.md'
  if (-not $liveReport.Contains('## New findings')) { throw 'live Markdown report is incomplete' }

  Push-Location 'examples/workspace'
  try {
    moon check --target native --deny-warn
    if ($LASTEXITCODE -ne 0) { throw 'live example moon check failed' }
    moon build --target native --deny-warn
    if ($LASTEXITCODE -ne 0) { throw 'live example moon build failed' }
  }
  finally {
    Pop-Location
  }

  Write-Host 'MoonArch local verification passed.'
}
finally {
  Pop-Location
}
