-- Kladder vs. udgivne bøger i hovedbiblioteket.
-- Eksisterende rækker (NULL) bliver til udgivet; nye rækker får default false.

alter table public.kid_story_books
  add column if not exists published_to_library boolean;

update public.kid_story_books
set published_to_library = true
where published_to_library is null;

alter table public.kid_story_books
  alter column published_to_library set default false;

alter table public.kid_story_books
  alter column published_to_library set not null;

comment on column public.kid_story_books.published_to_library is
  'Synlig i barnets hovedbibliotek; false = kun i bogbygger.';
