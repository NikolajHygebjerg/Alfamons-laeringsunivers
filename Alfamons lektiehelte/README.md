# Alfamons lektiehelte (native Xcode)

SpriteKit-projekt i samme repo som Flutter-appen **alfamon_flutter**.

## Hvor finder jeg det? (der er ikke noget `lektiehelte.xcworkspace`)

Projektet ligger **inde i Flutter-mappen** under et navn med **mellemrum** og forstavelsen **Alfamons**:

| Hvad du leder efter | Sti fra repo-roden `alfamon_flutter/` |
|---------------------|----------------------------------------|
| **Åbn i Xcode**     | `Alfamons lektiehelte/Alfamons lektiehelte.xcodeproj` |

- Det er et **`.xcodeproj`** (ikke et separat `.xcworkspace` som Flutter’s `ios/Runner.xcworkspace`).
- Xcode åbner automatisk det indbyggede workspace inde i `.xcodeproj`.

**Finder (fuld sti på din Mac):**  
`Alfamon/alfamon_flutter/Alfamons lektiehelte/Alfamons lektiehelte.xcodeproj`

**Fra Terminal:**

```bash
cd "/Users/nikolajhygebjerg/Alfamon/alfamon_flutter"
open "Alfamons lektiehelte/Alfamons lektiehelte.xcodeproj"
```

**I Cursor:** Åbn mapperoden `alfamon_flutter` – under **Explorer** ligger mappen **`Alfamons lektiehelte`** (søg evt. efter `lektiehelte` i filtræet).

**Flutter iOS** (anden app) åbnes med: `ios/Runner.xcworkspace` – det er **ikke** det samme som Alfamons lektiehelte.

## Synkronisering med Flutter

Efter du opdaterer app-ikonet i Flutter (`assets/nytikon.png` + `dart run flutter_launcher_icons`), kan du kopiere hele ikon-sættet til dette projekt:

```bash
SRC="ios/Runner/Assets.xcassets/AppIcon.appiconset"
DST="Alfamons lektiehelte/Alfamons lektiehelte/Assets.xcassets/AppIcon.appiconset"
cp "$SRC/Contents.json" "$DST/"
cp "$SRC"/Icon-App-*.png "$DST/"
```

Versionsnummer og visningsnavn er afstemt med `pubspec.yaml` / `Runner/Info.plist` i Xcode build settings (`MARKETING_VERSION`, `INFOPLIST_KEY_*`).
