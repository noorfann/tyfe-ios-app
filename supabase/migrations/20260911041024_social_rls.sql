-- Row-Level Security for the Tyfe social schema.
--
-- Privacy model: a member sees only their own rows plus the allowed Shared
-- Progress of people they share a Circle with, when that person has not paused
-- sharing and neither side has blocked the other. Cheers are global per pair.

-- Helper functions (security definer, pinned search_path, bypass RLS)

create or replace function public.is_circle_member(p_circle_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.circle_memberships m
        where m.circle_id = p_circle_id
          and m.user_id = p_user_id
    );
$$;

create or replace function public.is_circle_owner(p_circle_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.circles c
        where c.id = p_circle_id
          and c.owner_id = p_user_id
    );
$$;

create or replace function public.shares_circle_with(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = public
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

create or replace function public.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select exists (
        select 1
        from public.user_blocks bl
        where (bl.blocker_id = p_a and bl.blocked_id = p_b)
           or (bl.blocker_id = p_b and bl.blocked_id = p_a)
    );
$$;

create or replace function public.can_view_progress(p_subject uuid, p_viewer uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
    select
        p_subject = p_viewer
        or (
            not public.is_blocked_between(p_subject, p_viewer)
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

-- Membership identity and role are immutable after insert

create or replace function public.enforce_membership_identity()
returns trigger
language plpgsql
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

create trigger circle_memberships_protect_identity
before update on public.circle_memberships
for each row execute function public.enforce_membership_identity();

-- Enable RLS

alter table public.profiles enable row level security;
alter table public.circles enable row level security;
alter table public.circle_memberships enable row level security;
alter table public.circle_invites enable row level security;
alter table public.shared_progress enable row level security;
alter table public.cheers enable row level security;
alter table public.push_devices enable row level security;
alter table public.user_blocks enable row level security;

-- profiles

create policy profiles_select on public.profiles
for select to authenticated
using (
    id = auth.uid()
    or (
        public.shares_circle_with(auth.uid(), id)
        and not public.is_blocked_between(auth.uid(), id)
    )
);

create policy profiles_insert on public.profiles
for insert to authenticated
with check (id = auth.uid());

create policy profiles_update on public.profiles
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- circles

create policy circles_select on public.circles
for select to authenticated
using (public.is_circle_member(id, auth.uid()));

create policy circles_insert on public.circles
for insert to authenticated
with check (owner_id = auth.uid());

create policy circles_update on public.circles
for update to authenticated
using (public.is_circle_owner(id, auth.uid()))
with check (owner_id = auth.uid());

create policy circles_delete on public.circles
for delete to authenticated
using (public.is_circle_owner(id, auth.uid()));

-- circle_memberships

create policy memberships_select on public.circle_memberships
for select to authenticated
using (public.is_circle_member(circle_id, auth.uid()));

create policy memberships_insert on public.circle_memberships
for insert to authenticated
with check (public.is_circle_owner(circle_id, auth.uid()));

create policy memberships_update on public.circle_memberships
for update to authenticated
using (user_id = auth.uid() or public.is_circle_owner(circle_id, auth.uid()))
with check (user_id = auth.uid() or public.is_circle_owner(circle_id, auth.uid()));

create policy memberships_delete on public.circle_memberships
for delete to authenticated
using (user_id = auth.uid() or public.is_circle_owner(circle_id, auth.uid()));

-- circle_invites

create policy invites_select on public.circle_invites
for select to authenticated
using (public.is_circle_owner(circle_id, auth.uid()));

create policy invites_insert on public.circle_invites
for insert to authenticated
with check (public.is_circle_owner(circle_id, auth.uid()) and created_by = auth.uid());

create policy invites_update on public.circle_invites
for update to authenticated
using (public.is_circle_owner(circle_id, auth.uid()))
with check (public.is_circle_owner(circle_id, auth.uid()));

create policy invites_delete on public.circle_invites
for delete to authenticated
using (public.is_circle_owner(circle_id, auth.uid()));

-- shared_progress

create policy shared_progress_select on public.shared_progress
for select to authenticated
using (public.can_view_progress(user_id, auth.uid()));

create policy shared_progress_insert on public.shared_progress
for insert to authenticated
with check (user_id = auth.uid());

create policy shared_progress_update on public.shared_progress
for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- cheers

create policy cheers_select on public.cheers
for select to authenticated
using (sender_id = auth.uid() or recipient_id = auth.uid());

create policy cheers_insert on public.cheers
for insert to authenticated
with check (
    sender_id = auth.uid()
    and sender_id <> recipient_id
    and public.can_view_progress(recipient_id, auth.uid())
);

-- push_devices

create policy push_devices_all on public.push_devices
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- user_blocks

create policy user_blocks_select on public.user_blocks
for select to authenticated
using (blocker_id = auth.uid());

create policy user_blocks_insert on public.user_blocks
for insert to authenticated
with check (blocker_id = auth.uid());

create policy user_blocks_delete on public.user_blocks
for delete to authenticated
using (blocker_id = auth.uid());

-- Join a Circle through a one-time invite code

create or replace function public.accept_circle_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    v_invite public.circle_invites%rowtype;
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'authentication required';
    end if;

    select *
    into v_invite
    from public.circle_invites
    where code = p_code
    for update;

    if not found then
        raise exception 'invite not found';
    end if;
    if v_invite.revoked_at is not null then
        raise exception 'invite revoked';
    end if;
    if v_invite.accepted_by is not null then
        raise exception 'invite already used';
    end if;
    if v_invite.expires_at <= now() then
        raise exception 'invite expired';
    end if;

    insert into public.circle_memberships (circle_id, user_id, role)
    values (v_invite.circle_id, v_user_id, 'member')
    on conflict (circle_id, user_id) do nothing;

    update public.circle_invites
    set accepted_by = v_user_id,
        accepted_at = now()
    where id = v_invite.id;

    return v_invite.circle_id;
end;
$$;

-- Circle-scoped aggregate: today's snapshot, seven-day completed total, and
-- today's Cheer count per member. security_invoker keeps underlying RLS.

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
    latest.updated_at as progress_updated_at
from public.circle_memberships m
join public.profiles p on p.id = m.user_id
left join lateral (
    select sp.*
    from public.shared_progress sp
    where sp.user_id = m.user_id
    order by sp.local_date desc
    limit 1
) latest on true
left join lateral (
    select sum(sp.completed_sessions) as seven_day_completed
    from public.shared_progress sp
    where sp.user_id = m.user_id
      and sp.local_date between latest.local_date - 6 and latest.local_date
) week on true
left join lateral (
    select count(*) as cheer_count
    from public.cheers c
    where c.recipient_id = m.user_id
      and c.local_date = latest.local_date
) cheer on true;

-- Grants

grant usage on schema public to authenticated;

grant select, insert, update, delete on
    public.profiles,
    public.circles,
    public.circle_memberships,
    public.circle_invites,
    public.shared_progress,
    public.cheers,
    public.push_devices,
    public.user_blocks
to authenticated;

grant select on public.circle_member_progress to authenticated;

revoke all on function public.accept_circle_invite(text) from public;
grant execute on function public.accept_circle_invite(text) to authenticated;

revoke all on function public.is_circle_member(uuid, uuid) from public;
revoke all on function public.is_circle_owner(uuid, uuid) from public;
revoke all on function public.shares_circle_with(uuid, uuid) from public;
revoke all on function public.is_blocked_between(uuid, uuid) from public;
revoke all on function public.can_view_progress(uuid, uuid) from public;
grant execute on function public.is_circle_member(uuid, uuid) to authenticated;
grant execute on function public.is_circle_owner(uuid, uuid) to authenticated;
grant execute on function public.shares_circle_with(uuid, uuid) to authenticated;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
grant execute on function public.can_view_progress(uuid, uuid) to authenticated;
