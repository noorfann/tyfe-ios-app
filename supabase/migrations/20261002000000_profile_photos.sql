-- Profile photo references are additive; existing avatar tokens remain unchanged.
-- Create/configure the private bucket through Storage API before enabling uploads.
alter table public.profiles add column avatar_path text;
alter table public.profiles add constraint profiles_avatar_path_owned check (
    avatar_path is null or avatar_path ~ (
        '^' || id::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
    )
);

create function private.profile_photo_owner(p_path text)
returns uuid
language sql
immutable
set search_path = ''
as $$
    select case when p_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
        then split_part(p_path, '/', 1)::uuid
        else null end;
$$;

create function private.owns_profile_photo(p_path text)
returns boolean
language sql
stable
set search_path = ''
as $$
    select coalesce(private.profile_photo_owner(p_path) = (select auth.uid()), false);
$$;

create function private.can_read_profile_photo(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select (select auth.uid()) is not null and (
        private.owns_profile_photo(p_path)
        or exists (
            select 1 from public.profiles p
            where p.id = private.profile_photo_owner(p_path)
              and p.avatar_path = p_path
              and private.shares_circle_with((select auth.uid()), p.id)
        )
    );
$$;

revoke all on function private.profile_photo_owner(text) from public;
revoke all on function private.owns_profile_photo(text) from public;
revoke all on function private.can_read_profile_photo(text) from public;
grant execute on function private.profile_photo_owner(text), private.owns_profile_photo(text),
    private.can_read_profile_photo(text) to authenticated;

create policy profile_photos_insert on storage.objects
for insert to authenticated with check (
    bucket_id = 'profile-photos' and private.owns_profile_photo(name)
);
create policy profile_photos_select on storage.objects
for select to authenticated using (
    bucket_id = 'profile-photos' and private.can_read_profile_photo(name)
);
create policy profile_photos_delete on storage.objects
for delete to authenticated using (
    bucket_id = 'profile-photos' and private.owns_profile_photo(name)
);
-- No UPDATE policy: fresh UUID paths only; upsert/overwrite/move are forbidden.
-- JPEG and 1 MiB restrictions belong to the Storage bucket configuration/API.

-- Append the new column without renaming/reordering the existing view contract.
create or replace view public.circle_member_progress
with (security_invoker = true)
as
select
    m.circle_id,
    m.user_id,
    p.display_name,
    p.avatar_token,
    (m.role = 'owner') as is_owner,
    latest.local_date as latest_date,
    coalesce(latest.planned_sessions, 0) as today_planned,
    coalesce(latest.completed_sessions, 0) as today_completed,
    coalesce(week.seven_day_completed, 0) as seven_day_completed,
    coalesce(cheer.cheer_count, 0) as cheers_today,
    latest.updated_at as progress_updated_at,
    p.avatar_path
from public.circle_memberships m
join public.profiles p on p.id = m.user_id
left join lateral (
    select sp.* from public.shared_progress sp
    where sp.user_id = m.user_id
    order by sp.local_date desc limit 1
) latest on true
left join lateral (
    select sum(sp.completed_sessions) as seven_day_completed
    from public.shared_progress sp
    where sp.user_id = m.user_id
      and sp.local_date between latest.local_date - 6 and latest.local_date
) week on true
left join lateral (
    select count(*) as cheer_count from public.cheers c
    where c.recipient_id = m.user_id and c.local_date = latest.local_date
) cheer on true;
