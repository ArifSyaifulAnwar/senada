$file = "pubspec.yaml"

$content = Get-Content $file

foreach ($line in $content) {
    if ($line -match "^version:") {
        $current = $line.Split(" ")[1]

        $name,$build = $current.Split("+")
        $newBuild = [int]$build + 1

        $newVersion = "$name+$newBuild"

        $newLine = "version: $newVersion"
        $content = $content -replace $line,$newLine

        Write-Host "Version updated to $newVersion"
        break
    }
}

Set-Content $file $content