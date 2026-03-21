# Alfamons lektiehelte (native Xcode)

SpriteKit-projekt i samme repo som Flutter-appen **alfamon_flutter**.

## Synkronisering med Flutter

Efter du opdaterer app-ikonet i Flutter (`assets/nytikon.png` + `dart run flutter_launcher_icons`), kan du kopiere hele ikon-sættet til dette projekt:

```bash
SRC="ios/Runner/Assets.xcassets/AppIcon.appiconset"
DST="Alfamons lektiehelte/Alfamons lektiehelte/Assets.xcassets/AppIcon.appiconset"
cp "$SRC/Contents.json" "$DST/"
cp "$SRC"/Icon-App-*.png "$DST/"
```

Versionsnummer og visningsnavn er afstemt med `pubspec.yaml` / `Runner/Info.plist` i Xcode build settings (`MARKETING_VERSION`, `INFOPLIST_KEY_*`).
