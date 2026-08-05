-- book_builder_gallery + book_builder_extra_images: børn skal kunne læse rækker selv når
-- PostgREST-sessionen er "anon" (fx uden fuld forældre-login) — ellers 0 rækker pga. RLS,
-- og admin-tildelinger / upload-URL'er vises ikke i bogbyggeren.

drop policy if exists "book_builder_gallery_select" on public.book_builder_gallery;

create policy "book_builder_gallery_select"
  on public.book_builder_gallery
  for select
  to anon, authenticated
  using (true);

drop policy if exists "book_builder_extra_select" on public.book_builder_extra_images;

create policy "book_builder_extra_select"
  on public.book_builder_extra_images
  for select
  to anon, authenticated
  using (true);
