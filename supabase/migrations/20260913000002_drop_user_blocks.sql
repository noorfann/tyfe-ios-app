-- Remove the block/unblock feature.
--
-- Redefine the progress privacy helper and the profiles SELECT policy without
-- the mutual-block guards, then drop the block helper and table. Access remains
-- gated by shared Circle membership.

create or replace function private.can_view_progress(p_subject uuid, p_viewer uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select
        p_subject = p_viewer
        or exists (
            select 1
            from public.circle_memberships subject_membership
            join public.circle_memberships viewer_membership
              on viewer_membership.circle_id = subject_membership.circle_id
            where subject_membership.user_id = p_subject
              and viewer_membership.user_id = p_viewer
        );
$$;

alter policy profiles_select on public.profiles
using (
    id = (select auth.uid())
    or private.shares_circle_with((select auth.uid()), id)
);

drop function if exists private.is_blocked_between(uuid, uuid);
drop table if exists public.user_blocks;
