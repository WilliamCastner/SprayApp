-- SprayApp account fixes (2026-11-16).
begin;

-- 1. Renaming: update the name everywhere it is stored, in one step.
--    Before, only the profile changed, so the climber's old climbs, sends,
--    comments and leaderboard rows kept the old name and their profile page
--    showed 0 climbs under the new one.
create or replace function public.rename_user(new_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  old_name text;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  if new_name !~ '^[a-zA-Z0-9_-]{3,20}$' then
    raise exception 'invalid display name';
  end if;
  select display_name into old_name from profiles where id = uid;
  -- The unique constraint on profiles.display_name rejects taken names.
  update profiles set display_name = new_name, updated_at = now() where id = uid;
  update climbs set displayname = new_name where id = uid;
  update climbs
     set ascents = (
       select jsonb_agg(
                case when a->>'user_id' = uid::text
                     then jsonb_set(a, '{username}', to_jsonb(new_name))
                     else a end)
         from jsonb_array_elements(ascents) a)
   where ascents @> jsonb_build_array(jsonb_build_object('user_id', uid::text));
  update comments set username = new_name where user_id = uid;
  update beta_videos set username = new_name where user_id = uid;
  if old_name is not null then
    update liked_climbs set setter_name = new_name
     where setter_name = old_name
       and climbid in (select climbid from climbs where id = uid);
  end if;
end;
$$;
revoke execute on function public.rename_user(text) from public, anon;
grant execute on function public.rename_user(text) to authenticated;

-- 2. Deleting an account: remove everything that belongs to the climber.
--    Before, their sends (name included) stayed inside other people's
--    climbs, and their comments, likes, saves and video rows were left behind.
--    (The app removes the video files from storage before calling this.)
create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;
  update climbs
     set ascents = coalesce((
           select jsonb_agg(a) from jsonb_array_elements(ascents) a
            where a->>'user_id' is distinct from uid::text), '[]'::jsonb),
         sends = (
           select count(distinct a->>'user_id') from jsonb_array_elements(ascents) a
            where a->>'user_id' is distinct from uid::text)
   where ascents @> jsonb_build_array(jsonb_build_object('user_id', uid::text));
  delete from comments where user_id = uid;
  delete from liked_climbs where user_id = uid;
  delete from saved_climbs where user_id = uid;
  delete from beta_videos where user_id = uid;
  delete from profiles where id = uid;
  delete from climbs where id = uid;
  delete from auth.users where id = uid;
end;
$$;
revoke execute on function public.delete_user() from public, anon;
grant execute on function public.delete_user() to authenticated;

-- 3. Pin the search path of the trigger functions that run with owner
--    rights (stops a crafted object in another schema hijacking them).
alter function public.handle_new_user() set search_path = public;
alter function public.handle_user_delete() set search_path = public;

commit;
