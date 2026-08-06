# Byg Alfamons læringsunivers til Windows (release).
# Kør fra projektroden på en Windows-PC med Flutter + Visual Studio 2022.
#
#   powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
#
# Pak zip til dist\windows\ (til upload på hjemmeside):
#   powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Package
#
# Valgfrit: dart-define til Supabase (hvis du ikke bruger supabase_config_local.dart):
#   powershell -File tool\build_windows.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseAnonKey "eyJ..."

param(
    [string]$SupabaseUrl = "",
    [string]$SupabaseAnonKey = "",
    [switch]$Debug,
    [switch]$Package
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

$ExeNames = @("Alfamons.exe", "alfamon_flutter.exe")

function Get-WindowsExePath {
    param([string]$OutDir)
    foreach ($name in $ExeNames) {
        $path = Join-Path $OutDir $name
        if (Test-Path $path) { return $path }
    }
    return $null
}

Write-Host "== Alfamons Windows build ==" -ForegroundColor Cyan
Write-Host "Projekt: $Root"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter findes ikke i PATH. Installer Flutter og genstart terminalen."
}

Write-Host "`n-- flutter doctor (Windows/desktop) --" -ForegroundColor Yellow
flutter doctor -v | Select-String -Pattern "Windows|Visual Studio|Flutter \(" -Context 0,2

Write-Host "`n-- flutter pub get --" -ForegroundColor Yellow
flutter pub get

$buildArgs = @("build", "windows")
if ($Debug) {
    $buildArgs += "--debug"
} else {
    $buildArgs += "--release"
}

if ($SupabaseUrl -ne "") {
    $buildArgs += "--dart-define=SUPABASE_URL=$SupabaseUrl"
}
if ($SupabaseAnonKey -ne "") {
    $buildArgs += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
}

Write-Host "`n-- flutter $($buildArgs -join ' ') --" -ForegroundColor Yellow
& flutter @buildArgs

$mode = if ($Debug) { "Debug" } else { "Release" }
$outDir = Join-Path $Root "build\windows\x64\runner\$mode"
$exe = Get-WindowsExePath -OutDir $outDir

Write-Host "`n== Færdig ==" -ForegroundColor Green
if ($exe) {
    Write-Host "Exe:       $exe"
    Write-Host "Mappe:     $outDir"
    Write-Host ""
    Write-Host "Kør appen:  & `"$exe`""
    Write-Host "Distribuer: zip HELE mappen $outDir (exe + data/ + *.dll)."
} else {
    Write-Warning "Forventet exe findes ikke i: $outDir"
    Write-Host "Forventede navne: $($ExeNames -join ', ')"
    Write-Host "Tjek build-loggen ovenfor for fejl."
    exit 1
}

if ($Package) {
    if ($Debug) {
        Write-Warning "-Package understøttes kun for release-builds. Kør uden -Debug."
        exit 1
    }

    $pubVersion = $null
    foreach ($line in Get-Content (Join-Path $Root "pubspec.yaml")) {
        if ($line -match '^\s*version:\s*(\S+)') {
            $pubVersion = $Matches[1]
            break
        }
    }
    if (-not $pubVersion) { throw "Kunne ikke læse version fra pubspec.yaml" }
    $safeVersion = $pubVersion -replace '\+', '-'

    $distBase = Join-Path $Root "dist\windows"
    $folderName = "Alfamons-Windows-$safeVersion"
    $packageDir = Join-Path $distBase $folderName
    New-Item -ItemType Directory -Force -Path $packageDir | Out-Null

    Write-Host "`n-- Pakker til $packageDir --" -ForegroundColor Yellow
    Copy-Item -Path (Join-Path $outDir "*") -Destination $packageDir -Recurse -Force

    $zipName = "$folderName.zip"
    $zipPath = Join-Path $distBase $zipName
    if (Test-Path $zipPath) { Remove-Item $zipPath }

    Write-Host "-- Zip: $zipPath --" -ForegroundColor Yellow
    Compress-Archive -Path $packageDir -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host ""
    Write-Host "PAKKE KLAR. Upload:" -ForegroundColor Green
    Write-Host "  $zipPath"
    Write-Host "Brugere skal udpakke HELE mappen og køre Alfamons.exe."
}

Write-Host ""
Write-Host "Bemærk: Lyd via just_audio virker typisk IKKE på Windows endnu." -ForegroundColor DarkYellow
Write-Host "Se docs/flutter-windows-build.md for begrænsninger og fejlsøgning."
