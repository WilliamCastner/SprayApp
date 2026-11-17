-- SprayApp v0.5 database changes. Applied 2026-11-16 in the Supabase SQL editor.
-- All changes keep the current (v0.4) app working.
begin;

-- 1. Log a send in one step. The old way (read the ascents array, add the send
--    in the app, write the whole array back) loses a send when two people log
--    the same climb at the same moment. user_id is always the caller, so
--    nobody can log a send as someone else.
create or replace function public.log_ascent(p_climbid uuid, p_ascent jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_ascent jsonb;
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  v_ascent := p_ascent || jsonb_build_object('user_id', auth.uid());
  update climbs
     set ascents = coalesce(ascents, '[]'::jsonb) || jsonb_build_array(v_ascent),
         sends = (
           select count(distinct a->>'user_id')
             from jsonb_array_elements(coalesce(ascents, '[]'::jsonb) || jsonb_build_array(v_ascent)) a
         )
   where climbid = p_climbid;
  if not found then
    raise exception 'climb not found';
  end if;
end;
$$;
revoke execute on function public.log_ascent(uuid, jsonb) from public, anon;
grant execute on function public.log_ascent(uuid, jsonb) to authenticated;

-- 2. Indexes for lookups the app makes on every climb page and profile.
create index if not exists climbs_createdat_idx on public.climbs (createdat desc);
create index if not exists climbs_setter_idx on public.climbs (id);
create index if not exists comments_climbid_idx on public.comments (climbid);
create index if not exists liked_climbs_climbid_idx on public.liked_climbs (climbid);
create index if not exists beta_videos_climbid_idx on public.beta_videos (climbid);

-- 3. Security fixes.
-- a) Climb updates were open to everyone, including people who are not
--    signed in (the app's public key is in the web app). Only signed-in users
--    now. (Signed-in users still update other people's climbs to log sends;
--    once every phone runs v0.5+, this can move to setter-only.)
alter policy "allow update" on public.climbs to authenticated;

-- b) New climbs must be created under your own account.
alter policy "Enable insert for authenticated users only" on public.climbs
  with check ((select auth.uid()) = id);

-- c) beta_videos had no access rules at all (anyone could add or delete rows).
alter table public.beta_videos enable row level security;
drop policy if exists "beta videos readable" on public.beta_videos;
drop policy if exists "beta videos insert own" on public.beta_videos;
drop policy if exists "beta videos delete own or setter" on public.beta_videos;
create policy "beta videos readable" on public.beta_videos
  for select using (true);
create policy "beta videos insert own" on public.beta_videos
  for insert to authenticated with check ((select auth.uid()) = user_id);
-- Same rule as the app: the uploader or the climb's setter can delete.
create policy "beta videos delete own or setter" on public.beta_videos
  for delete to authenticated using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.climbs c
       where c.climbid = beta_videos.climbid and c.id = (select auth.uid())
    )
  );

commit;
