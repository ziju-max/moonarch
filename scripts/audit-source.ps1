$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$files = Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.mbt' |
  Where-Object {
    $relative = $_.FullName.Substring($root.Length).TrimStart('\', '/')
    $relative -notmatch '(?:^|[\\/])(?:_build|\.mooncakes|\.git)(?:[\\/]|$)'
  }
$productionFiles = $files | Where-Object { $_.Name -notmatch '(_test|_wbtest)\.mbt$' }
$testFiles = $files | Where-Object { $_.Name -match '(_test|_wbtest)\.mbt$' }

function Count-EffectiveLines($selectedFiles) {
  $count = 0
  foreach ($file in $selectedFiles) {
    foreach ($line in Get-Content -LiteralPath $file.FullName) {
      $trimmed = $line.Trim()
      if ($trimmed.Length -gt 0 -and -not $trimmed.StartsWith('//')) {
        $count++
      }
    }
  }
  return $count
}

$productionLines = Count-EffectiveLines $productionFiles
$testLines = Count-EffectiveLines $testFiles
$allLines = $productionLines + $testLines
Write-Output "MoonBit source files: $($files.Count)"
Write-Output "Production effective lines: $productionLines"
Write-Output "Test effective lines: $testLines"
Write-Output "Total effective lines: $allLines"

$branch = git -C $root branch --show-current
$commitCount = [int](git -C $root rev-list --count HEAD 2>$null)
$remoteNames = @(git -C $root remote)
Write-Output "Local branch: $branch"
Write-Output "Local commits: $commitCount"
Write-Output "Configured remotes: $($remoteNames.Count)"
