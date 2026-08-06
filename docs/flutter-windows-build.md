# Guide: Byg Alfamons læringsunivers til Windows

Denne guide beskriver, hvordan du bygger og kører Flutter-appen som **Windows desktop-app** (`Alfamons.exe`).

> **Mac/Linux:** `flutter build windows` virker **kun på en Windows-maskine**. På Mac får du fejlen *"build windows only supported on Windows hosts"* — det er forventet. Brug i stedet [GitHub Actions](#8-byg-via-github-actions-uden-windows-pc) (se nedenfor).

---

## 1. Forudsætninger på Windows-PC

### Flutter SDK

1. Download Flutter: https://docs.flutter.dev/get-started/install/windows
2. Tilføj `flutter\bin` til **PATH**
3. Verificér:

```powershell
flutter doctor
```

### Visual Studio 2022

Installer **Visual Studio 2022** (Community er gratis) med workload:

- **Desktop development with C++**

Inkl. disse komponenter (typisk valgt automatisk):

- MSVC v143
- Windows 10/11 SDK
- CMake tools for Windows

Efter installation:

```powershell
flutter doctor -v
```

Du skal se `[✓] Visual Studio` under Windows toolchain.

### Git

Til at klone repoet: https://git-scm.com/download/win

---

## 2. Hent projektet

```powershell
git clone <dit-repo-url> alfamon_flutter
cd alfamon_flutter
```

Eller kopier projektmappen fra Mac (USB, OneDrive, zip osv.).

### Supabase-nøgle

**Lokal udvikling:** Kopiér `lib/config/supabase_config_local_example.dart` til `lib/config/supabase_config_local.dart` og indsæt din anon key (samme som iOS/Android).

**CI / release-build:** Brug dart-define (har forrang over den lokale fil):

```powershell
flutter build windows --release `
  --dart-define=SUPABASE_URL=https://bdsnfnwcnfnszgdqbapo.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=din-anon-key
```

---

## 3. Byg (release)

### Hurtig metode — script (anbefalet)

Fra projektroden i **PowerShell**:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Package
```

Det bygger release og laver `dist\windows\Alfamons-Windows-<version>.zip`.

Debug-build:

```powershell
powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1 -Debug
```

### Manuel metode

```powershell
flutter pub get
flutter build windows --release
```

Første build kan tage **5–15 minutter** (C++ kompilering af plugins).

---

## 4. Kør appen

Efter release-build ligger output her:

```
build\windows\x64\runner\Release\
├── Alfamons.exe             ← start filen
├── flutter_windows.dll
├── *.dll                    ← plugin-biblioteker
└── data\
    └── flutter_assets\      ← ~180 MB assets (bøger, lyd, trace osv.)
```

**Kør:**

```powershell
.\build\windows\x64\runner\Release\Alfamons.exe
```

Eller dobbeltklik på `Alfamons.exe` i Stifinder.

### Udvikling (hot reload)

Med Windows-PC tilsluttet som desktop-enhed:

```powershell
flutter run -d windows
```

---

## 5. Del appen med andre (zip)

Windows-appen er **ikke** én enkelt fil. Du skal pakke **hele** `Release`-mappen (eller bruge `-Package` i build-scriptet):

1. Kør `tool\build_windows.ps1 -Package`, **eller**
2. Højreklik på `build\windows\x64\runner\Release` → **Send til → Komprimeret mappe**

Modtageren udpakker og kører `Alfamons.exe`.

> **SmartScreen:** Uden code signing viser Windows muligvis en advarsel ved første kørsel. Klik "Mere info" → "Kør alligevel", eller underskriv exe'en senere med et certifikat.

---

## 6. Kendte begrænsninger (lyd er IKKE løst)

Følgende er **bevidst eller teknisk begrænset** på Windows i nuværende kodebase. Denne guide løser dem **ikke**.

| Funktion | Status på Windows |
|----------|-------------------|
| **`just_audio`** (boglæser, matematik-tutor, admin-lydbibliotek, trace-musik) | Understøttes **ikke** af plugin på Windows — lyd kan mangle eller fejle |
| **`audioplayers`** | Virker (Windows-plugin er registreret) |
| **Ord-optagelse (mikrofon)** | Kun iOS/Android i UI — viser fejl på desktop |
| **Tale-til-tekst (bogbygger)** | Kun iOS/Android |
| **Push-notifikationer** | Slået fra på Windows |
| **App Store-anmeldelse** | Kun mobil/macOS |
| **Landskab-only** | Appen låser til landscape (som på tablet) |

Resten af appen (login, admin, opgaver, avatars, bibliotek, spil, bogbygger uden STT) bør kunne køre.

---

## 7. Fejlsøgning

### `"build windows" only supported on Windows hosts`

Du er på Mac/Linux. Brug en Windows-PC, VM (Parallels/UTM på Mac) eller GitHub Actions med `windows-latest`.

### Visual Studio / MSVC mangler

```powershell
flutter doctor -v
```

Installer **Desktop development with C++** i Visual Studio Installer og kør `flutter doctor` igen.

### CMake / NuGet fejl

```powershell
flutter clean
flutter pub get
flutter build windows --release
```

### `LNK1104` eller manglende DLL ved kørsel

Kør exe'en **fra** `Release`-mappen, eller kopier hele mappen — ikke kun `.exe`.

### Auth / email-bekræftelse (deeplink)

Native redirect er `alfamon://login-callback` (se `lib/config/supabase_config.dart`).

Til fuld email-bekræftelse på Windows skal URL-scheme registreres (plugin `app_links`). Det er ikke fuldt testet endnu — log ind med adgangskode virker; magic links kan kræve ekstra opsætning.

### Appen crasher ved start

Kør fra PowerShell for at se fejl:

```powershell
cd build\windows\x64\runner\Release
.\Alfamons.exe
```

Tjek også `%LOCALAPPDATA%\alfamon_flutter\` for logs, hvis relevant.

---

## 8. Byg via GitHub Actions (uden Windows-PC)

Repoet har workflow **Windows build** (`.github/workflows/windows-build.yml`).

1. Tilføj GitHub secret `SUPABASE_ANON_KEY` (Settings → Secrets and variables → Actions).
2. Gå til **Actions** → **Windows build** → **Run workflow** (eller push til `main` / `release`).
3. Når build er færdigt: download artifact **Alfamons-Windows** (zip med hele Release-mappen).

Build tager typisk 10–20 minutter.

---

## 9. Checkliste efter første build

- [ ] Appen starter uden crash
- [ ] Login med email/adgangskode
- [ ] Barn-valg og dagens opgaver
- [ ] Alfamon / trace (uden forventning om al lyd)
- [ ] Admin-dashboard (hvis forælder-login)
- [ ] Accepter at `just_audio`-steder kan være stille

---

## Relaterede filer

| Fil | Formål |
|-----|--------|
| `tool/build_windows.ps1` | Automatiseret Windows-build og zip (`-Package`) |
| `scripts/windows_udgivelse_til_hjemmeside.txt` | Kort checkliste til hjemmeside-upload |
| `.github/workflows/windows-build.yml` | CI-build uden Windows-PC |
| `windows/` | Flutter desktop-runner (CMake) |
| `pubspec.yaml` | Fuld app inkl. assets (~180 MB+) |
| `pubspec_web.yaml` | Kun web-admin (bruges **ikke** til Windows) |
