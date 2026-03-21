-- Emoji til opgaver (vises stort på barnets skærm).
alter table public.tasks
  add column if not exists emoji text;

comment on column public.tasks.emoji is 'Valgfri emoji (ét tegn/grafem) vist på barnets opgavekort.';
