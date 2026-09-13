-- Remove the social sharing pause feature.
--
-- Redefine the progress privacy helper without the per-membership and
-- per-profile pause checks, then drop the now-unused columns. Access remains
-- gated by shared Circle membership and mutual blocks.

create or replace function private.can_view_progress(p_subject uuid, p_viewer uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select
        p_subject = p_viewer
        or (
            not private.is_blocked_between(p_subject, p_viewer)
            and exists (
                select 1
                from public.circle_memberships subject_membership
                join public.circle_memberships viewer_membership
                  on viewer_membership.circle_id = subject_membership.circle_id
                where subject_membership.user_id = p_subject
                  and viewer_membership.user_id = p_viewer
            )
        );
$$;

alter table public.profiles drop column if exists sharing_paused;
alter table public.circle_memberships drop column if exists sharing_paused;
