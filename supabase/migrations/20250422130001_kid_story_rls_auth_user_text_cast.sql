-- Opfølgning: sammenlign auth_user_id med auth.uid() som tekst, så RLS virker
-- både når [profiles.auth_user_id] er uuid og når det er text (gængs i Supabase).
-- Kør efter 20250422120000_kid_story_books og 20250422130000 (page_format). Idempotent: drop + create.

-- Hjælpeudtryk: én stedssand profil for den loggede bruger
-- (samme som: select id from profiles where auth_user_id::text = auth.uid()::text limit 1)

-- kid_story_books
drop policy if exists "kid_story_books_select" on public.kid_story_books;
create policy "kid_story_books_select"
  on public.kid_story_books for select
  to authenticated
  using (
    exists (
      select 1
      from public.kids k
      where k.id = kid_story_books.kid_id
        and k.parent_id = (
          select p.id from public.profiles p
          where p.auth_user_id::text = auth.uid()::text
          limit 1
        )
    )
  );

drop policy if exists "kid_story_books_insert" on public.kid_story_books;
create policy "kid_story_books_insert"
  on public.kid_story_books for insert
  to authenticated
  with check (
    parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    and exists (
      select 1
      from public.kids k
      where k.id = kid_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );

drop policy if exists "kid_story_books_update" on public.kid_story_books;
create policy "kid_story_books_update"
  on public.kid_story_books for update
  to authenticated
  using (
    exists (
      select 1
      from public.kids k
      where k.id = kid_story_books.kid_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  )
  with check (
    exists (
      select 1
      from public.kids k
      where k.id = kid_story_books.kid_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );

drop policy if exists "kid_story_books_delete" on public.kid_story_books;
create policy "kid_story_books_delete"
  on public.kid_story_books for delete
  to authenticated
  using (
    exists (
      select 1
      from public.kids k
      where k.id = kid_story_books.kid_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );

-- kid_story_book_pages
drop policy if exists "kid_story_book_pages_select" on public.kid_story_book_pages;
create policy "kid_story_book_pages_select"
  on public.kid_story_book_pages for select
  to authenticated
  using (
    exists (
      select 1
      from public.kid_story_books b
      join public.kids k on k.id = b.kid_id
      where b.id = kid_story_book_pages.book_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );

drop policy if exists "kid_story_book_pages_insert" on public.kid_story_book_pages;
create policy "kid_story_book_pages_insert"
  on public.kid_story_book_pages for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.kid_story_books b
      join public.kids k on k.id = b.kid_id
      where b.id = book_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );

drop policy if exists "kid_story_book_pages_update" on public.kid_story_book_pages;
create policy "kid_story_book_pages_update"
  on public.kid_story_book_pages for update
  to authenticated
  using (
    exists (
      select 1
      from public.kid_story_books b
      join public.kids k on k.id = b.kid_id
      where b.id = kid_story_book_pages.book_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  )
  with check (
    exists (
      select 1
      from public.kid_story_books b
      join public.kids k on k.id = b.kid_id
      where b.id = kid_story_book_pages.book_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );

drop policy if exists "kid_story_book_pages_delete" on public.kid_story_book_pages;
create policy "kid_story_book_pages_delete"
  on public.kid_story_book_pages for delete
  to authenticated
  using (
    exists (
      select 1
      from public.kid_story_books b
      join public.kids k on k.id = b.kid_id
      where b.id = kid_story_book_pages.book_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id::text = auth.uid()::text limit 1)
    )
  );
