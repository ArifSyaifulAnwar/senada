# Naikkan version
.\version.ps1

# Ambil version terbaru dari pubspec.yaml
$versionLine = Select-String -Path pubspec.yaml -Pattern "^version:"
$version = $versionLine.Line.Split(" ")[1]

Write-Host "Building version $version..."

# Build AAB
flutter build appbundle

# Rename file hasil build
$source = "build/app/outputs/bundle/release/app-release.aab"
$dest = "build/app/outputs/bundle/release/absensi-$version.aab"

Rename-Item $source $dest -Force

Write-Host "Build selesai: $dest"