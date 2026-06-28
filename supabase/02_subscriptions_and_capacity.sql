-- =====================================================================
--  The Reading Room — Add-on: 4-person cap + Stripe subscription gate
-- =====================================================================
--  Run this AFTER schema.sql, in Supabase → SQL Editor → New query.
--  Safe to re-run: it drops and recreates everything it owns.
-- =====================================================================

-- ---------- 1. Cap every club at 4 members ---------------------------
-- A trigger is the real guard. The app's UI will also hide "Join" when a
-- club is full, but this makes the database itself refuse a 5th member,
-- even if someone bypasses the page.

create or replace function public.enforce_club_capacity()
returns trigger language plpgsql as $$
begin
  if (select count(*) from public.club_members where club_id = new.club_id) >= 4 then
    raise exception 'This club is full (maximum 4 members).';
  end if;
  return new;
end;
$$;

drop trigger if exists club_capacity_check on public.club_members;
create trigger club_capacity_check
  before insert on public.club_members
  for each row execute function public.enforce_club_capacity();


-- ---------- 2. Subscriptions table -----------------------------------
-- Written ONLY by the Stripe webhook (which uses the service-role key and
-- bypasses RLS). The client can read its own row but can never write here,
-- so a user can't grant themselves a subscription.

create table if not exists public.subscriptions (
  user_id                uuid primary key references auth.users on delete cascade,
  stripe_customer_id     text,
  stripe_subscription_id text,
  status                 text not null default 'inactive',  -- 'active' | 'inactive'
  current_period_end     timestamptz,
  updated_at             timestamptz default now()
);

alter table public.subscriptions enable row level security;

drop policy if exists "read own subscription" on public.subscriptions;
create policy "read own subscription" on public.subscriptions
  for select using (user_id = auth.uid());


-- ---------- 3. Helper: is the current user subscribed? ---------------
create or replace function public.has_active_sub()
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.subscriptions
    where user_id = auth.uid() and status = 'active'
  );
$$;


-- ---------- 4. Require an active subscription to create or join -------
-- These REPLACE the matching policies from schema.sql, adding the sub check.
-- Personal library is untouched and stays free.

drop policy if exists "create clubs" on public.clubs;
create policy "create clubs" on public.clubs
  for insert with check (owner_id = auth.uid() and public.has_active_sub());

drop policy if exists "join a club" on public.club_members;
create policy "join a club" on public.club_members
  for insert with check (user_id = auth.uid() and public.has_active_sub());

-- =====================================================================
--  ALTERNATIVE — "owner pays, brings 3 guests free"
--  If you ever want that model instead, replace the "join a club" policy
--  above with the version below (only the club OWNER must be subscribed):
--
--  drop policy if exists "join a club" on public.club_members;
--  create policy "join a club" on public.club_members
--    for insert with check (
--      user_id = auth.uid()
--      and exists (
--        select 1 from public.clubs c
--        join public.subscriptions s on s.user_id = c.owner_id
--        where c.id = club_id and s.status = 'active'
--      )
--    );
-- =====================================================================

-- Done.
