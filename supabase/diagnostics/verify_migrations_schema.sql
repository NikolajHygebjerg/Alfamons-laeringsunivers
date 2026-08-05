-- Kør i Supabase → SQL (én gang) for at se om de vigtigste objekter fra repo-migrationerne findes.
-- I kan ikke få 100% svar uden forbindelse til jeres project — men denne fil er den rigtige tjek-prøve.
--
-- Bemærk: Hvis I har "manuelt" kørt SQL uden for Supabase CLI, kan
--   supabase_migrations.schema_migrations
-- mangle nogle rækker, selvom skemaet er OK.

-- A) Tabel-eksistens
with expected(name) as (
  values
    ('kid_story_books'),
    ('kid_story_book_pages'),
    ('book_builder_extra_images'),
    ('book_builder_gallery')
)
select
  e.name as table_name,
  (t.table_name is not null) as exists
from expected e
left join information_schema.tables t
  on t.table_schema = 'public' and t.table_name = e.name
order by e.name;

-- B) Kolonner (bogbygger + udgivelse)
select
  c.table_name,
  c.column_name,
  c.data_type
from information_schema.columns c
where c.table_schema = 'public'
  and (
    (c.table_name = 'kid_story_books' and c.column_name in (
      'page_format', 'published_to_library'
    ))
    or (c.table_name = 'kid_story_book_pages' and c.column_name in (
      'text_font_size', 'text_font_key', 'page_layout'
    ))
  )
order by c.table_name, c.column_name;

-- C) (Valgfrit) Migrations-historik — kun hvis I bruger Supabase CLI/linked migrations
-- Fejl = tabellen findes ikke eller ingen adgang; ignorér så.
select version, name
from supabase_migrations.schema_migrations
order by version;

-- D) Sammenlign med disse forventede versioner (filnavne uden .sql) — tjek at C) indeholder dem:
-- 20250422120000  kid_story
-- 20250422130000  (page_format + rls text cast)
-- 20250422140000
-- 20250422150000
-- 20250423120000  book_builder_gallery
-- 20250425120000  published_to_library
-- 20250427120000  RLS: book_builder_gallery + book_builder_extra_images — select for anon
