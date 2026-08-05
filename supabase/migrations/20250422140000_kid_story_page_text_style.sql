-- Valgfri skrifttype/størrelse per side i barnets bog (bogbygger).
alter table public.kid_story_book_pages
  add column if not exists text_font_size real,
  add column if not exists text_font_key text;

comment on column public.kid_story_book_pages.text_font_size is 'Bogbygger: brødtekst størrelse (px-lignende, ca. 16–64). NULL = default.';
comment on column public.kid_story_book_pages.text_font_key is 'Bogbygger: ''sans'' | ''serif'' | ''mono''. NULL = default.';
