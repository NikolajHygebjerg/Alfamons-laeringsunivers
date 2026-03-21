-- Én række pr. (barn, opgave, dato) med gentagelser pr. dag
alter table public.task_instances
  add column if not exists required_completions int not null default 1;

alter table public.task_instances
  add column if not exists completions_done int not null default 0;

comment on column public.task_instances.required_completions is 'Hvor mange gange opgaven skal udføres denne dag (fra recurring_tasks.per_day_count).';
comment on column public.task_instances.completions_done is 'Antal gennemførte gange i dag for denne instans.';
