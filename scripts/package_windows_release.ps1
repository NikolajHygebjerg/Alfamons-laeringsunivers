# Pakker Windows release til upload på egen hjemmeside.
# Kør på en Windows-PC med Flutter SDK + Visual Studio 2022 (Desktop development with C++).
# Fra repo-roden:  powershell -ExecutionPolicy Bypass -File scripts\package_windows_release.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

Write-Host ">> flutter pub get"
flutter pub get

$pubVersion = $null
foreach ($line in Get-Content (Join-Path $root "pubspec.yaml")) {
  if ($line -match '^\s*version:\s*(\S+)') {
    $pubVersion = $Matches[1]
    break
  }
}
if (-not $pubVersion) { throw "Kunne ikke læse version fra pubspec.yaml" }
$safeVersion = $pubVersion -replace '\+', '-'

Write-Host ">> flutter build windows --release"
flutter build windows --release

$buildDir = Join-Path $root "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $buildDir "Alfamons.exe"))) {
    if (Test-Path (Join-Path $buildDir "alfamon_flutter.exe")) {
        throw "Forventede Alfamons.exe. Opdater BINARY_NAME i windows/CMakeLists.txt og byg igen."
    }
    throw "Build output ikke fundet: $buildDir (kør flutter build windows --release)"
}

$distBase = Join-Path $root "dist\windows"
$folderName = "Alfamons-Windows-$safeVersion"
$outDir = Join-Path $distBase $folderName
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host ">> Kopierer Release til $outDir"
Copy-Item -Path (Join-Path $buildDir "*") -Destination $outDir -Recurse -Force

$zipName = "$folderName.zip"
$zipPath = Join-Path $distBase $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath }

Write-Host ">> Zip: $zipPath"
Compress-Archive -Path $outDir -DestinationPath $zipPath -CompressionLevel Optimal

Write-Host ""
Write-Host "FÆRDIG (Alfamons læringsunivers til Windows). Upload:"
Write-Host "  $zipPath"
Write-Host "Brugere skal udpakke HELE mappen og køre Alfamons.exe (alle .dll og data/ skal ligge ved siden af .exe)."
