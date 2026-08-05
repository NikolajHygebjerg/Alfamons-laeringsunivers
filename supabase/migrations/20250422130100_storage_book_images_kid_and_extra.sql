-- book-images: granulære policies (valgfri).
--
-- I MANGE PROJEKTER GÆLDER ALLEREDE:
--   policy "Authenticated all book-images"  → cmd ALL, authenticated,
--        (bucket_id = 'book-images')  → fuld adgang for alle loggede brugere til
--        hele bucket, inkl. kid_uploads/... og book_builder_extra/...
--   policy "Public read book-images"        → cmd SELECT, public, book-images
--        → offentlig læsning (fx getPublicUrl i appen)
-- I så fald: bogbygger + admin-ekstrabilleder virker UDEN at køre nedenstående.
-- Kør KUN disse oprettelser hvis I vil FJERNE den brede "Authenticated all book-images"
-- og i stedet begrænse til bestemte stier.
--
-- App-stier (til reference):
--   kid_uploads/<auth_user_id>/...        — lib/services/kid_storybook_service.dart
--   book_builder_extra/<avatar_id>/...   — BookBuilderAlfamonImageService
-- Bucket "book-images" skal findes. Andet navn: søg/erstat.

-- Læs offentligt (typisk når bucket er "public" og I bruger getPublicUrl)
drop policy if exists "book_images_select_public" on storage.objects;
create policy "book_images_select_public"
  on storage.objects for select
  to public
  using (bucket_id = 'book-images');

-- Upload: børn/foreldre — kun egen mappe (segment 1 = kid_uploads, 2 = auth.uid som tekst)
drop policy if exists "book_images_insert_kid_uploads" on storage.objects;
create policy "book_images_insert_kid_uploads"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'kid_uploads'
    and (string_to_array(name, '/'))[2] = (select auth.uid()::text)
  );

drop policy if exists "book_images_update_kid_uploads" on storage.objects;
create policy "book_images_update_kid_uploads"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'kid_uploads'
    and (string_to_array(name, '/'))[2] = (select auth.uid()::text)
  )
  with check (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'kid_uploads'
    and (string_to_array(name, '/'))[2] = (select auth.uid()::text)
  );

drop policy if exists "book_images_delete_kid_uploads" on storage.objects;
create policy "book_images_delete_kid_uploads"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'kid_uploads'
    and (string_to_array(name, '/'))[2] = (select auth.uid()::text)
  );

-- Admin: ekstra Alfamon-billeder under book_builder_extra/<uuid>/
drop policy if exists "book_images_insert_builder_extra" on storage.objects;
create policy "book_images_insert_builder_extra"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'book_builder_extra'
    and (string_to_array(name, '/'))[2] ~ '^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$'
  );

drop policy if exists "book_images_update_builder_extra" on storage.objects;
create policy "book_images_update_builder_extra"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'book_builder_extra'
  )
  with check (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'book_builder_extra'
  );

drop policy if exists "book_images_delete_builder_extra" on storage.objects;
create policy "book_images_delete_builder_extra"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'book-images'
    and (string_to_array(name, '/'))[1] = 'book_builder_extra'
  );
