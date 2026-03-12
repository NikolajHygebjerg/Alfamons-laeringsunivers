# Alfamon Flutter

Flutter-version af Alfamon-appen – en opgavemotiverings-app til børn med Alfamon-avatars, point og spil.

## Funktioner

- **Auth**: Log ind, opret konto, nulstil adgangskode
- **Admin**: Administrer børn, opgaver, avatars og indstillinger
- **Barn**: Vælg barn, se dagens opgaver, færdiggør opgaver, tjene point, udvikle Alfamon-avatars
- **Supabase**: Bruger samme database som Next.js-versionen

## Opsætning

1. **Supabase-credentials**: Opdater `lib/config/supabase_config.dart` med din Supabase URL og anon key, eller brug dart-define:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=din-anon-key
```

2. **Database**: Sørg for at Supabase-migrationerne fra `Dopaminos/dopaminos/supabase/` er kørt.

3. **Kør appen**:

```bash
cd alfamon_flutter
flutter pub get
flutter run
```

## Projektstruktur

```
lib/
├── config/          # Supabase config
├── models/          # Kid, Task, Avatar, etc.
├── providers/       # AuthProvider
├── screens/
│   ├── auth/        # Login, signup
│   ├── home/        # Admin vs Barn valg
│   ├── admin/       # Admin dashboard, kids, tasks, avatars, settings
│   └── kid/         # Barn-valg, dagens opgaver, avatar
├── services/        # Supabase, task completion
└── main.dart
```

## Platforme

- iOS
- Android
- Web
- macOS
