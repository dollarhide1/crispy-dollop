-- =====================================================================
--  The Reading Room — Book Club schema for Supabase
-- =====================================================================
--  This sets up the SHARED book club. Your personal library (books,
--  quotes, habits, goal) stays in each person's browser and is NOT
--  touched by any of this.
--
--  HOW TO APPLY:
--    1. Open your Supabase project → SQL Editor → New query
--    2. Paste this whole file in and click "Run"
--    3. (Auth) Enable an email sign-in method under Authentication → Providers
--
--  This script is safe to re-run: it drops and recreates the objects.
-- =====================================================================

-- ---------- Tables ---------------------------------------------------

-- Display names tied to each signed-in user
create table if not exists public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text,
  created_at   timestamptz default now()
);

-- A book club
create table if not exists public.clubs (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  description   text,
  current_book  text,
  owner_id      uuid not null references auth.users on delete cascade,
  join_code     text unique not null,        -- share this so people can join
  created_at    timestamptz default now()
);

-- Who belongs to which club
create table if not exists public.club_members (
  club_id   uuid references public.clubs on delete cascade,
  user_id   uuid references auth.users on delete cascade,
  role      text not null default 'member', -- 'owner' | 'member'
  joined_at timestamptz default now(),
  primary key (club_id, user_id)
);

-- Scheduled meetings
create table if not exists public.meetings (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid references public.clubs on delete cascade,
  meeting_date date,
  book         text,
  notes        text,
  created_by   uuid references auth.users,
  created_at   timestamptz default now()
);

-- Discussion thread posts
create table if not exists public.discussions (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid references public.clubs on delete cascade,
  user_id    uuid references auth.users,
  text       text not null,
  created_at timestamptz default now()
);

-- ---------- Membership helper ---------------------------------------
-- A SECURITY DEFINER function avoids the classic "policy on a table that
-- queries itself" recursion when checking club membership.

create or replace function public.is_member(c uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_members
    where club_id = c and user_id = auth.uid()
  );
$$;

-- ---------- Row Level Security --------------------------------------

alter table public.profiles      enable row level security;
alter table public.clubs         enable row level security;
alter table public.club_members  enable row level security;
alter table public.meetings      enable row level security;
alter table public.discussions   enable row level security;

-- profiles: a person manages their own row; club-mates can read names
drop policy if exists "read own or clubmate profiles" on public.profiles;
create policy "read own or clubmate profiles" on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1 from public.club_members m1
      join public.club_members m2 on m1.club_id = m2.club_id
      where m1.user_id = auth.uid() and m2.user_id = profiles.id
    )
  );
drop policy if exists "upsert own profile" on public.profiles;
create policy "upsert own profile" on public.profiles
  for insert with check (id = auth.uid());
drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update using (id = auth.uid());

-- clubs: members can read; anyone signed in can create; owner can edit/delete
drop policy if exists "members read clubs" on public.clubs;
create policy "members read clubs" on public.clubs
  for select using (is_member(id) or owner_id = auth.uid());
drop policy if exists "create clubs" on public.clubs;
create policy "create clubs" on public.clubs
  for insert with check (owner_id = auth.uid());
drop policy if exists "owner updates club" on public.clubs;
create policy "owner updates club" on public.clubs
  for update using (owner_id = auth.uid());
drop policy if exists "owner deletes club" on public.clubs;
create policy "owner deletes club" on public.clubs
  for delete using (owner_id = auth.uid());

-- club_members: members can see the roster; you can add yourself (join by code,
-- enforced in the app); you can remove yourself; owner can remove anyone
drop policy if exists "members read roster" on public.club_members;
create policy "members read roster" on public.club_members
  for select using (is_member(club_id));
drop policy if exists "join a club" on public.club_members;
create policy "join a club" on public.club_members
  for insert with check (user_id = auth.uid());
drop policy if exists "leave a club" on public.club_members;
create policy "leave a club" on public.club_members
  for delete using (
    user_id = auth.uid()
    or exists (select 1 from public.clubs where id = club_id and owner_id = auth.uid())
  );

-- meetings: members read and write
drop policy if exists "members read meetings" on public.meetings;
create policy "members read meetings" on public.meetings
  for select using (is_member(club_id));
drop policy if exists "members add meetings" on public.meetings;
create policy "members add meetings" on public.meetings
  for insert with check (is_member(club_id));
drop policy if exists "members edit meetings" on public.meetings;
create policy "members edit meetings" on public.meetings
  for update using (is_member(club_id));
drop policy if exists "members delete meetings" on public.meetings;
create policy "members delete meetings" on public.meetings
  for delete using (is_member(club_id));

-- discussions: members read and post; you can delete your own post
drop policy if exists "members read discussions" on public.discussions;
create policy "members read discussions" on public.discussions
  for select using (is_member(club_id));
drop policy if exists "members post discussions" on public.discussions;
create policy "members post discussions" on public.discussions
  for insert with check (is_member(club_id) and user_id = auth.uid());
drop policy if exists "delete own post" on public.discussions;
create policy "delete own post" on public.discussions
  for delete using (
    user_id = auth.uid()
    or exists (select 1 from public.clubs where id = club_id and owner_id = auth.uid())
  );

-- ---------- Realtime (optional, for live discussion updates) ---------
-- Adds these tables to the realtime publication so the app can subscribe
-- and show new posts/meetings without a refresh.

alter publication supabase_realtime add table public.discussions;
alter publication supabase_realtime add table public.meetings;
alter publication supabase_realtime add table public.club_members;

-- Done.
