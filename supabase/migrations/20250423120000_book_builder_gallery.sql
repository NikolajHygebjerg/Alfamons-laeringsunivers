-- Tilknytning: lokale app-assets (AssetManifest-sti) -> Alfamon til børne-bogbygger.
-- RLS: læsning: se også 20250427120000 (anon+authenticated). Skriv: kun nikolaj@begejstring.dk.

create table if not exists public.book_builder_gallery (
  id uuid primary key default gen_random_uuid(),
  asset_path text not null,
  avatar_id uuid references public.avatars (id) on delete set null,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (asset_path)
);

create index if not exists book_builder_gallery_avatar_id_idx
  on public.book_builder_gallery (avatar_id, sort_order);

alter table public.book_builder_gallery enable row level security;

drop policy if exists "book_builder_gallery_select" on public.book_builder_gallery;
create policy "book_builder_gallery_select"
  on public.book_builder_gallery for select
  to authenticated
  using (true);

drop policy if exists "book_builder_gallery_insert" on public.book_builder_gallery;
create policy "book_builder_gallery_insert"
  on public.book_builder_gallery for insert
  to authenticated
  with check (
    (select email from auth.users where id = auth.uid() limit 1) = 'nikolaj@begejstring.dk'
  );

drop policy if exists "book_builder_gallery_update" on public.book_builder_gallery;
create policy "book_builder_gallery_update"
  on public.book_builder_gallery for update
  to authenticated
  using (
    (select email from auth.users where id = auth.uid() limit 1) = 'nikolaj@begejstring.dk'
  )
  with check (
    (select email from auth.users where id = auth.uid() limit 1) = 'nikolaj@begejstring.dk'
  );

drop policy if exists "book_builder_gallery_delete" on public.book_builder_gallery;
create policy "book_builder_gallery_delete"
  on public.book_builder_gallery for delete
  to authenticated
  using (
    (select email from auth.users where id = auth.uid() limit 1) = 'nikolaj@begejstring.dk'
  );
