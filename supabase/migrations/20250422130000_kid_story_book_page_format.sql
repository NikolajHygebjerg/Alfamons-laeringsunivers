-- Format for barnets egen bog: lodret (portrait), vandret (landscape), kvadratisk (square).
alter table public.kid_story_books
  add column if not exists page_format text not null default 'landscape';

alter table public.kid_story_books
  drop constraint if exists kid_story_books_page_format_check;

alter table public.kid_story_books
  add constraint kid_story_books_page_format_check
  check (page_format in ('portrait', 'landscape', 'square'));

comment on column public.kid_story_books.page_format is
  'Vandret, lodret eller kvadratisk — valgt i bogbyggeren ved ny bog.';
