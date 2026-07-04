-- =====================================================================
--  The Reading Room — raise club member cap from 4 to 8
-- =====================================================================
--  Run this in Supabase → SQL Editor → New query. Safe to re-run.
--  It recreates the capacity-check trigger function with the new limit.
-- =====================================================================

create or replace function public.enforce_club_capacity()
returns trigger language plpgsql as $$
begin
  if (select count(*) from public.club_members where club_id = new.club_id) >= 8 then
    raise exception 'This club is full (maximum 8 members).';
  end if;
  return new;
end;
$$;

-- The trigger itself already points at this function, so no other change
-- is needed — updating the function updates the rule everywhere.
