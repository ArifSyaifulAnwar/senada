$ErrorActionPreference = 'Stop'
$pubspecPath = Join-Path $PSScriptRoot 'pubspec.yaml'
$versionLine = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([^+\s]+)(?:\+(\d+))?\s*$' | Select-Object -First 1
if ($null -eq $versionLine) { throw 'Version tidak ditemukan di pubspec.yaml.' }
$buildName = $versionLine.Matches[0].Groups[1].Value
$buildNumber = [Math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 60).ToString()
Write-Host "$buildName+$buildNumber"
Write-Host 'pubspec.yaml tidak diubah.'
