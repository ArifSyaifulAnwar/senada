param(
    [ValidateSet('android', 'ios', 'web', 'all')]
    [string]$Target = 'android',
    [switch]$SkipClean
)

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
Set-Location $projectRoot

$versionLine = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([^+\s]+)(?:\+(\d+))?\s*$' | Select-Object -First 1
if ($null -eq $versionLine) { throw 'Version tidak ditemukan di pubspec.yaml.' }

$buildName = $versionLine.Matches[0].Groups[1].Value
$buildNumber = [Math]::Floor([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() / 60).ToString()

Write-Host "Build target : $Target"
Write-Host "Build name   : $buildName"
Write-Host "Build number : $buildNumber"
Write-Host 'pubspec.yaml tidak akan diubah.'

if (-not $SkipClean) {
    flutter clean
    if ($LASTEXITCODE -ne 0) { throw 'flutter clean gagal.' }
}
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get gagal.' }

function Build-Android {
    flutter build appbundle --release --build-name=$buildName --build-number=$buildNumber
    if ($LASTEXITCODE -ne 0) { throw 'Build Android App Bundle gagal.' }
    $source = Join-Path $projectRoot 'build\app\outputs\bundle\release\app-release.aab'
    $destination = Join-Path $projectRoot "build\app\outputs\bundle\release\senada-$buildName+$buildNumber.aab"
    Copy-Item -LiteralPath $source -Destination $destination -Force
    Write-Host "Android selesai: $destination"
}

function Build-Ios {
    if (-not $IsMacOS) { throw 'Build iOS hanya dapat dijalankan di macOS dengan Xcode.' }
    flutter build ipa --release --build-name=$buildName --build-number=$buildNumber
    if ($LASTEXITCODE -ne 0) { throw 'Build iOS IPA gagal.' }
    Write-Host 'iOS selesai: build/ios/ipa'
}

function Build-Web {
    flutter build web --release --build-name=$buildName --build-number=$buildNumber `
        --dart-define=APP_VERSION=$buildName `
        --dart-define=APP_BUILD_NUMBER=$buildNumber
    if ($LASTEXITCODE -ne 0) { throw 'Build Web gagal.' }
    Write-Host 'Web selesai: build/web'
}

switch ($Target) {
    'android' { Build-Android }
    'ios' { Build-Ios }
    'web' { Build-Web }
    'all' {
        Build-Android
        Build-Web
        if ($IsMacOS) { Build-Ios } else { Write-Warning 'iOS dilewati karena bukan macOS.' }
    }
}
