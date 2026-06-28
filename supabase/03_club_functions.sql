-- =====================================================================
--  The Reading Room — Add-on 3: club create / join helper functions
-- =====================================================================
--  Run this AFTER schema.sql and 02_subscriptions_and_capacity.sql.
--  Safe to re-run.
--
--  Why these exist:
--   - Your security rules (correctly) stop people from reading a club they
--     haven't joined. That means the app can't look up a club by its code
--     directly, so join-by-code runs through a SECURITY DEFINER function.
--   - create_club makes the club AND adds the owner as the first member in
--     one atomic step, and generates the share code server-side.
--  Both require an active subscription (matching the gate in add-on 2).
-- =====================================================================

-- ---------- Create a club (owner becomes member #1) ------------------
create or replace function public.create_club(
  p_name text,
  p_description text,
  p_current_book text
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
  v_code    text;
begin
  if not public.has_active_sub() then
    raise exception 'A subscription is required to create a club.';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Club name is required.';
  end if;

  -- generate a short, unique, human-friendly join code
  loop
    v_code := upper(substr(md5(random()::text), 1, 6));
    exit when not exists (select 1 from public.clubs where join_code = v_code);
  end loop;

  insert into public.clubs (name, description, current_book, owner_id, join_code)
  values (trim(p_name), nullif(trim(p_description), ''),
          nullif(trim(p_current_book), ''), auth.uid(), v_code)
  returning id into v_club_id;

  insert into public.club_members (club_id, user_id, role)
  values (v_club_id, auth.uid(), 'owner');

  return v_club_id;
end;
$$;

-- ---------- Join a club by its share code ----------------------------
create or replace function public.join_club_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
begin
  if not public.has_active_sub() then
    raise exception 'A subscription is required to join a club.';
  end if;

  select id into v_club_id
  from public.clubs
  where join_code = upper(trim(p_code));

  if v_club_id is null then
    raise exception 'No club found with that code.';
  end if;

  -- The 4-member cap trigger still runs here and will reject a 5th member.
  insert into public.club_members (club_id, user_id, role)
  values (v_club_id, auth.uid(), 'member')
  on conflict (club_id, user_id) do nothing;

  return v_club_id;
end;
$$;

-- Done.
