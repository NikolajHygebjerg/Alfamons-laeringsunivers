# Release til Lektiehelte

## 1. Kode på GitHub (`release`-branch)

Efter commit på `main`:

```bash
# Opdatér remote release-branch til at matche main
git push origin main
git push origin main:release
```

Eller brug scriptet:

```bash
./scripts/push_release_lektiehelte.sh
```

**Krav:** Du er logget ind på GitHub (`gh auth login` eller SSH-nøgle).  
Remote `origin` peger på team-repoet (fx `github.com/NikolajHygebjerg/Alfamons_lektiehelte.git`). Til **andet** repo:

```bash
git remote add lektiehelte <URL-til-repo>
git push lektiehelte main:release
```

---

## 2. Flutter-app (iOS) – App Store / TestFlight

1. Åbn `ios/Runner.xcworkspace` i Xcode.
2. Vælg scheme **Runner**, destination **Any iOS Device**.
3. **Product → Archive** (bruger **Release** automatisk).
4. I Organizer: **Distribute App** → App Store Connect → Upload.

Eller fra terminal:

```bash
flutter build ipa
```

(følg [signering](https://docs.flutter.dev/deployment/ios) hvis det fejler.)

---

## 3. Native **Alfamons lektiehelte** (SpriteKit)

1. Åbn `Alfamons lektiehelte/Alfamons lektiehelte.xcodeproj`.
2. Scheme **Alfamons lektiehelte**, **Any iOS Device**.
3. **Product → Archive** → Upload til samme eller andet App ID (`dk.lektiehelte.Alfamons-lektiehelte`).

---

## 4. Android (valgfrit)

```bash
flutter build appbundle
```

Upload `.aab` til Google Play (intern test / produktion).  
Til rigtig release skal `android/app/build.gradle.kts` have **release signing** (ikke debug).

---

## 5. Supabase

Migrationer i `supabase/migrations/` skal køres mod **produktionsprojektet** (Supabase Dashboard → SQL eller `supabase db push` mod linket prod-projekt).
