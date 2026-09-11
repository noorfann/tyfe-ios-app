-- Harden the social RLS surface:
--   1. Pin search_path on trigger functions.
--   2. Move privacy helpers into a non-exposed `private` schema so they
--      cannot be called as PostgREST RPCs.
--   3. Restrict function execution to the roles that need it.

-- 1. Trigger functions: immutable search_path

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create or replace function public.enforce_membership_identity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.circle_id <> old.circle_id
       or new.user_id <> old.user_id
       or new.role <> old.role then
        raise exception 'circle membership identity and role are immutable';
    end if;
    return new;
end;
$$;

-- 2. Privacy helpers in a non-exposed schema

create schema if not exists private;

create or replace function private.is_circle_member(p_circle_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (
        select 1
        from public.circle_memberships m
        where m.circle_id = p_circle_id
          and m.user_id = p_user_id
    );
$$;

create or replace function private.is_circle_owner(p_circle_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (
        select 1
        from public.circles c
        where c.id = p_circle_id
          and c.owner_id = p_user_id
    );
$$;

create or replace function private.shares_circle_with(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (
        select 1
        from public.circle_memberships a
        join public.circle_memberships b on b.circle_id = a.circle_id
        where a.user_id = p_a
          and b.user_id = p_b
    );
$$;

create or replace function private.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
    select exists (
        select 1
        from public.user_blocks bl
        where (bl.blocker_id = p_a and bl.blocked_id = p_b)
           or (bl.blocker_id = p_b and bl.blocked_id = p_a)
    );
$$;

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
                join public.profiles subject_profile
                  on subject_profile.id = subject_membership.user_id
                where subject_membership.user_id = p_subject
                  and viewer_membership.user_id = p_viewer
                  and subject_membership.sharing_paused = false
                  and subject_profile.sharing_paused = false
            )
        );
$$;

-- 3. Re-point policies at the private helpers

alter policy profiles_select on public.profiles
using (
    id = auth.uid()
    or (
        private.shares_circle_with(auth.uid(), id)
        and not private.is_blocked_between(auth.uid(), id)
    )
);

alter policy circles_select on public.circles
using (private.is_circle_member(id, auth.uid()));

alter policy circles_update on public.circles
using (private.is_circle_owner(id, auth.uid()))
with check (owner_id = auth.uid());

alter policy circles_delete on public.circles
using (private.is_circle_owner(id, auth.uid()));

alter policy memberships_select on public.circle_memberships
using (private.is_circle_member(circle_id, auth.uid()));

alter policy memberships_insert on public.circle_memberships
with check (private.is_circle_owner(circle_id, auth.uid()));

alter policy memberships_update on public.circle_memberships
using (user_id = auth.uid() or private.is_circle_owner(circle_id, auth.uid()))
with check (user_id = auth.uid() or private.is_circle_owner(circle_id, auth.uid()));

alter policy memberships_delete on public.circle_memberships
using (user_id = auth.uid() or private.is_circle_owner(circle_id, auth.uid()));

alter policy invites_select on public.circle_invites
using (private.is_circle_owner(circle_id, auth.uid()));

alter policy invites_insert on public.circle_invites
with check (private.is_circle_owner(circle_id, auth.uid()) and created_by = auth.uid());

alter policy invites_update on public.circle_invites
using (private.is_circle_owner(circle_id, auth.uid()))
with check (private.is_circle_owner(circle_id, auth.uid()));

alter policy invites_delete on public.circle_invites
using (private.is_circle_owner(circle_id, auth.uid()));

alter policy shared_progress_select on public.shared_progress
using (private.can_view_progress(user_id, auth.uid()));

alter policy cheers_insert on public.cheers
with check (
    sender_id = auth.uid()
    and sender_id <> recipient_id
    and private.can_view_progress(recipient_id, auth.uid())
);

-- 4. Remove the public helper functions now that policies use `private`

drop function if exists public.is_circle_member(uuid, uuid);
drop function if exists public.is_circle_owner(uuid, uuid);
drop function if exists public.shares_circle_with(uuid, uuid);
drop function if exists public.is_blocked_between(uuid, uuid);
drop function if exists public.can_view_progress(uuid, uuid);

-- 5. Restrict execution

revoke all on schema private from public;
revoke all on schema private from anon;
grant usage on schema private to authenticated;
revoke all on all functions in schema private from public;
revoke all on all functions in schema private from anon;
grant execute on all functions in schema private to authenticated;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.enforce_membership_identity() from public, anon, authenticated;
revoke all on function public.handle_new_user() from public, anon, authenticated;

revoke all on function public.accept_circle_invite(text) from public, anon;
grant execute on function public.accept_circle_invite(text) to authenticated;
