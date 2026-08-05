-- book_builder_gallery: skriverettigheder slog email op direkte i auth.users,
-- men 'authenticated' har ikke SELECT på auth.users → "permission denied for table users".
-- Vi skifter til auth.jwt() der læser email fra JWT'et i sessionen (ingen tabelopslag),
-- og bruger samme platform-admin-emails som resten af appen
-- (jf. 20260330120000_ensure_platform_admins_by_email.sql).

drop policy if exists "book_builder_gallery_insert" on public.book_builder_gallery;

create policy "book_builder_gallery_insert"
  on public.book_builder_gallery
  for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) in (
      'nikolaj@begejstring.dk',
      'nikolaj@idevaerket.dk'
    )
  );

drop policy if exists "book_builder_gallery_update" on public.book_builder_gallery;

create policy "book_builder_gallery_update"
  on public.book_builder_gallery
  for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) in (
      'nikolaj@begejstring.dk',
      'nikolaj@idevaerket.dk'
    )
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) in (
      'nikolaj@begejstring.dk',
      'nikolaj@idevaerket.dk'
    )
  );

drop policy if exists "book_builder_gallery_delete" on public.book_builder_gallery;

create policy "book_builder_gallery_delete"
  on public.book_builder_gallery
  for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) in (
      'nikolaj@begejstring.dk',
      'nikolaj@idevaerket.dk'
    )
  );
