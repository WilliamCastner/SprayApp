-- Delete everything set on the old wall (before the July 2026 reset).
-- A full backup of the deleted rows is in backups/2026-11-16-old-wall/
-- (kept locally, not in git). Accounts and profiles are not touched.
begin;

create temp table old_climbs on commit drop as
  select climbid from public.climbs
   where coalesce(holds->0->>'wall', '1') <> '2';

delete from public.comments     where climbid in (select climbid from old_climbs);
delete from public.liked_climbs where climbid in (select climbid from old_climbs);
delete from public.saved_climbs where climbid in (select climbid from old_climbs);
delete from public.beta_videos  where climbid in (select climbid from old_climbs);
delete from public.climbs       where climbid in (select climbid from old_climbs);

commit;
