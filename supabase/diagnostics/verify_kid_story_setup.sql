-- Kør i Supabase → SQL (service role: auth.uid() er NULL; brug disse tjek alligevel)
-- 1) Kolonnetype: [profiles.auth_user_id] — bør være uuid eller text; ::text i RLS dækker begge
select column_name, data_type, udt_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'profiles'
  and column_name = 'auth_user_id';

-- 2) Tabeller til bogbygger findes
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'kid_story_books',
    'kid_story_book_pages',
    'book_builder_extra_images'
  )
order by table_name;

-- 3) RLS er slået til
select c.relname as table_name, c.relrowsecurity as rls_on
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'kid_story_books',
    'kid_story_book_pages',
    'book_builder_extra_images'
  );

-- 4) Policies på nye tabeller
select schemaname, tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'kid_story_books',
    'kid_story_book_pages',
    'book_builder_extra_images'
  )
order by tablename, policyname;

-- 5) Storage: policies for [storage.objects] (alle — filtrer på book-images)
--    Har I allerede "Authenticated all book-images" (ALL) + "Public read book-images" (SELECT),
--    er I dækket til bogbygger uden yderligere storage-migration.
select policyname, cmd,
       substring(qual::text, 1, 200) as using_preview,
       substring(with_check::text, 1, 200) as check_preview
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
order by policyname;

-- 6) (Valgfri) Tæl rækker i kid_story når I har data
-- select count(*) from public.kid_story_books;
-- select count(*) from public.kid_story_book_pages;

-- 7) Test som rigtig bruger: Log ind i app, brug "API" / Edge med JWT — eller test INSERT fra app
--     og tjek at fejlen ikke er 42501/RLS.
