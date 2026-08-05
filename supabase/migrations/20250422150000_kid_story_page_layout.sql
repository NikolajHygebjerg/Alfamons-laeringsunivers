-- Frit layout (placering + skalering) for tekst og billede pr. side.
alter table public.kid_story_book_pages
  add column if not exists page_layout jsonb;

comment on column public.kid_story_book_pages.page_layout is 'Bogbygger: {v:1, icx, icy, is, tcx, tcy, ts} — normaliserede 0–1 og skalaer.';
