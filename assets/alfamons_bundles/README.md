# Alfamon- og bogmedier (lokale kopier)

Denne mappe er tænkt som **valgfri** samling af illustrationer, så I kan finde dem ét sted ved design, markedsføring eller nye features.

## `trace/`

**Kilde:** `packages/alfamon_trace/Assets/` (Alfamon Trace / bogstav-spillet).  
Rå mappen er ~90+ MB og indeholder bl.a. lyde, SVG-strokes og PNG/JPG.

**Synkronisér et udvalg** (topniveau PNG/JPG) til `assets/alfamons_bundles/trace/`:

```bash
./tool/sync_alfamon_trace_illustrations.sh
```

Appen **bruger stadig** Trace-assets via `@alfamon_trace`-pakken (`pubspec`-`assets` der). Denne kopi er kun til oversigt i hovedprojektet — den skal **ikke** være nødvendig for build, medmindre I bevidst refererer til filerne i `pubspec.yaml`.

## `books/`

**Kilde:** De fleste butiksbøger og Læs-let-sider ligger som **URL’er i Supabase** (`shop_book_pages.right_image_url`, `avatar_stages.image_url`, osv.), ikke som faste filer i repo.

Læg evt. **eksporterede** omslag eller referencer her (fx efter download fra Storage), så designere kan browse uden at åbne databasen.
