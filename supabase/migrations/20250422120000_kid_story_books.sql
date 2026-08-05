-- Kiddes egne bøger + ekstra Alfamon-billeder til bogbygger.
-- Kør i Supabase SQL Editor. Juster RLS hvis jeres [profiles.auth_user_id] har anden type.

-- Ekstra Alfamon-billeder (udover [avatar_stages]).
create table if not exists public.book_builder_extra_images (
  id uuid primary key default gen_random_uuid(),
  avatar_id uuid not null references public.avatars (id) on delete cascade,
  image_url text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists book_builder_extra_images_avatar_id_idx
  on public.book_builder_extra_images (avatar_id, sort_order);

-- Barnets egne bøger.
create table if not exists public.kid_story_books (
  id uuid primary key default gen_random_uuid(),
  kid_id uuid not null references public.kids (id) on delete cascade,
  parent_id uuid not null references public.profiles (id) on delete cascade,
  title text not null default 'Min bog',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists kid_story_books_kid_id_idx
  on public.kid_story_books (kid_id, updated_at desc);

create table if not exists public.kid_story_book_pages (
  id uuid primary key default gen_random_uuid(),
  book_id uuid not null references public.kid_story_books (id) on delete cascade,
  spread_index int not null,
  left_text text not null default '',
  right_image_url text,
  unique (book_id, spread_index)
);

create index if not exists kid_story_book_pages_book_id_idx
  on public.kid_story_book_pages (book_id, spread_index);

alter table public.book_builder_extra_images enable row level security;
alter table public.kid_story_books enable row level security;
alter table public.kid_story_book_pages enable row level security;

-- Ekstra billeder: autentificerede brugere (forældre-app) kan læse; skrive via admin-UI.
drop policy if exists "book_builder_extra_select" on public.book_builder_extra_images;
create policy "book_builder_extra_select"
  on public.book_builder_extra_images for select
  to authenticated
  using (true);

drop policy if exists "book_builder_extra_insert" on public.book_builder_extra_images;
create policy "book_builder_extra_insert"
  on public.book_builder_extra_images for insert
  to authenticated
  with check (true);

drop policy if exists "book_builder_extra_update" on public.book_builder_extra_images;
create policy "book_builder_extra_update"
  on public.book_builder_extra_images for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "book_builder_extra_delete" on public.book_builder_extra_images;
create policy "book_builder_extra_delete"
  on public.book_builder_extra_images for delete
  to authenticated
  using (true);

-- kid_story: kun børn der tilhører min profil.
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
          where p.auth_user_id = auth.uid()
          limit 1
        )
    )
  );

drop policy if exists "kid_story_books_insert" on public.kid_story_books;
create policy "kid_story_books_insert"
  on public.kid_story_books for insert
  to authenticated
  with check (
    parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
    and exists (
      select 1
      from public.kids k
      where k.id = kid_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
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
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
    )
  )
  with check (
    exists (
      select 1
      from public.kids k
      where k.id = kid_story_books.kid_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
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
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
    )
  );

-- Sider: samme ejerskab som bogen
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
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
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
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
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
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
    )
  )
  with check (
    exists (
      select 1
      from public.kid_story_books b
      join public.kids k on k.id = b.kid_id
      where b.id = kid_story_book_pages.book_id
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
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
        and k.parent_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
    )
  );

-- Efter denne fil: kør også
--   20250422130001_kid_story_rls_auth_user_text_cast.sql  (auth_user_id ::text = auth.uid()::text)
--   20250422130100_storage_book_images_kid_and_extra.sql   (storage.objects for book-images)
-- Diagnose: supabase/diagnostics/verify_kid_story_setup.sql
