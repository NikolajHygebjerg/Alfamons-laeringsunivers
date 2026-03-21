-- Appen bruger source = 'book' ved TaskCompletionService.awardBookPoints (læst bog).
-- Tidligere check tillod kun task/daily_bonus → 23514 ved bog-point.
alter table public.points_ledger
  drop constraint if exists points_ledger_source_check;

alter table public.points_ledger
  add constraint points_ledger_source_check
  check (
    source = any (
      array[
        'task'::text,
        'daily_bonus'::text,
        'book'::text
      ]
    )
  );

comment on constraint points_ledger_source_check on public.points_ledger is
  'task: opgavefuldførelse, daily_bonus: alle opgaver i dag, book: point for læst bog';
