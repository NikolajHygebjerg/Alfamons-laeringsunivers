# Byg Alfamons lektiehelte til Windows (release).
# Kør fra projektroden på en Windows-PC med Flutter + Visual Studio 2022.
#
#   powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1
#
# Valgfrit: dart-define til Supabase (hvis du ikke bruger supabase_config_local.dart):
#   powershell -File tool\build_windows.ps1 -SupabaseUrl "https://xxx.supabase.co" -SupabaseAnonKey "eyJ..."

param(
    [string]$SupabaseUrl = "",
    [string]$SupabaseAnonKey = "",
    [switch]$Debug
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "== Alfamon Windows build ==" -ForegroundColor Cyan
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
$exe = Join-Path $outDir "alfamon_flutter.exe"

Write-Host "`n== Færdig ==" -ForegroundColor Green
if (Test-Path $exe) {
    Write-Host "Exe:       $exe"
    Write-Host "Mappe:     $outDir"
    Write-Host ""
    Write-Host "Kør appen:  & `"$exe`""
    Write-Host "Distribuer: zip HELE mappen $outDir (exe + data/ + *.dll)."
} else {
    Write-Warning "Forventet exe findes ikke endnu: $exe"
    Write-Host "Tjek build-loggen ovenfor for fejl."
}

Write-Host ""
Write-Host "Bemærk: Lyd via just_audio virker typisk IKKE på Windows endnu." -ForegroundColor DarkYellow
Write-Host "Se docs/flutter-windows-build.md for begrænsninger og fejlsøgning."
