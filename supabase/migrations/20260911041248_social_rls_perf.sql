-- Performance fixes for the social RLS surface:
--   1. Cover the remaining foreign keys with indexes.
--   2. Hoist auth.uid() into an InitPlan with (select auth.uid()) so it is
--      evaluated once per statement instead of once per row.

-- 1. Foreign-key indexes

create index if not exists circle_invites_accepted_by_idx on public.circle_invites (accepted_by);
create index if not exists circle_invites_created_by_idx on public.circle_invites (created_by);
create index if not exists user_blocks_blocked_id_idx on public.user_blocks (blocked_id);

-- 2. Policies: cache auth.uid()

alter policy profiles_select on public.profiles
using (
    id = (select auth.uid())
    or (
        private.shares_circle_with((select auth.uid()), id)
        and not private.is_blocked_between((select auth.uid()), id)
    )
);

alter policy profiles_insert on public.profiles
with check (id = (select auth.uid()));

alter policy profiles_update on public.profiles
using (id = (select auth.uid()))
with check (id = (select auth.uid()));

alter policy circles_select on public.circles
using (private.is_circle_member(id, (select auth.uid())));

alter policy circles_insert on public.circles
with check (owner_id = (select auth.uid()));

alter policy circles_update on public.circles
using (private.is_circle_owner(id, (select auth.uid())))
with check (owner_id = (select auth.uid()));

alter policy circles_delete on public.circles
using (private.is_circle_owner(id, (select auth.uid())));

alter policy memberships_select on public.circle_memberships
using (private.is_circle_member(circle_id, (select auth.uid())));

alter policy memberships_insert on public.circle_memberships
with check (private.is_circle_owner(circle_id, (select auth.uid())));

alter policy memberships_update on public.circle_memberships
using (user_id = (select auth.uid()) or private.is_circle_owner(circle_id, (select auth.uid())))
with check (user_id = (select auth.uid()) or private.is_circle_owner(circle_id, (select auth.uid())));

alter policy memberships_delete on public.circle_memberships
using (user_id = (select auth.uid()) or private.is_circle_owner(circle_id, (select auth.uid())));

alter policy invites_select on public.circle_invites
using (private.is_circle_owner(circle_id, (select auth.uid())));

alter policy invites_insert on public.circle_invites
with check (
    private.is_circle_owner(circle_id, (select auth.uid()))
    and created_by = (select auth.uid())
);

alter policy invites_update on public.circle_invites
using (private.is_circle_owner(circle_id, (select auth.uid())))
with check (private.is_circle_owner(circle_id, (select auth.uid())));

alter policy invites_delete on public.circle_invites
using (private.is_circle_owner(circle_id, (select auth.uid())));

alter policy shared_progress_select on public.shared_progress
using (private.can_view_progress(user_id, (select auth.uid())));

alter policy shared_progress_insert on public.shared_progress
with check (user_id = (select auth.uid()));

alter policy shared_progress_update on public.shared_progress
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

alter policy cheers_select on public.cheers
using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));

alter policy cheers_insert on public.cheers
with check (
    sender_id = (select auth.uid())
    and sender_id <> recipient_id
    and private.can_view_progress(recipient_id, (select auth.uid()))
);

alter policy push_devices_all on public.push_devices
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

alter policy user_blocks_select on public.user_blocks
using (blocker_id = (select auth.uid()));

alter policy user_blocks_insert on public.user_blocks
with check (blocker_id = (select auth.uid()));

alter policy user_blocks_delete on public.user_blocks
using (blocker_id = (select auth.uid()));
