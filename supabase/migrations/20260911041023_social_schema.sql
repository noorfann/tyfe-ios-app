-- Tyfe social schema: identity, circles, memberships, invites, daily shared
-- progress, cheers, push devices, and blocks.
--
-- This schema holds social data only. Private Activities, Focus Sessions,
-- Reward Credits, Rewards, Reward Claims, and detailed local history never
-- leave the device (ADR-0004, ADR-0005). Coarse Focus Status is delivered
-- through Realtime Presence and is intentionally not stored here.

-- Enums

do $$ begin
    create type public.membership_role as enum ('owner', 'member');
exception when duplicate_object then null;
end $$;

do $$ begin
    create type public.cheer_kind as enum ('clap', 'heart', 'fire', 'star');
exception when duplicate_object then null;
end $$;

do $$ begin
    create type public.push_environment as enum ('development', 'production');
exception when duplicate_object then null;
end $$;

-- Shared updated_at trigger

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

-- profiles

create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null check (char_length(trim(display_name)) between 1 and 60),
    avatar_token text,
    sharing_paused boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- circles

create table if not exists public.circles (
    id uuid primary key default gen_random_uuid(),
    name text not null check (char_length(trim(name)) between 1 and 80),
    owner_id uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create trigger circles_set_updated_at
before update on public.circles
for each row execute function public.set_updated_at();

-- circle_memberships

create table if not exists public.circle_memberships (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.circles (id) on delete cascade,
    user_id uuid not null references public.profiles (id) on delete cascade,
    role public.membership_role not null default 'member',
    sharing_paused boolean not null default false,
    joined_at timestamptz not null default now(),
    unique (circle_id, user_id)
);

-- circle_invites (one-time)

create table if not exists public.circle_invites (
    id uuid primary key default gen_random_uuid(),
    circle_id uuid not null references public.circles (id) on delete cascade,
    created_by uuid not null references public.profiles (id) on delete cascade,
    code text not null unique check (char_length(code) between 6 and 64),
    expires_at timestamptz not null,
    accepted_by uuid references public.profiles (id) on delete set null,
    accepted_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz not null default now(),
    check (accepted_at is null or accepted_by is not null)
);

-- shared_progress (one aggregated snapshot per user per local day)

create table if not exists public.shared_progress (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    local_date date not null,
    planned_sessions integer not null default 0 check (planned_sessions >= 0),
    completed_sessions integer not null default 0 check (completed_sessions >= 0),
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, local_date)
);

create trigger shared_progress_set_updated_at
before update on public.shared_progress
for each row execute function public.set_updated_at();

-- cheers (global per sender/recipient/day/kind)

create table if not exists public.cheers (
    id uuid primary key default gen_random_uuid(),
    sender_id uuid not null references public.profiles (id) on delete cascade,
    recipient_id uuid not null references public.profiles (id) on delete cascade,
    local_date date not null,
    kind public.cheer_kind not null,
    created_at timestamptz not null default now(),
    check (sender_id <> recipient_id),
    unique (sender_id, recipient_id, local_date, kind)
);

-- push_devices

create table if not exists public.push_devices (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.profiles (id) on delete cascade,
    device_token text not null,
    environment public.push_environment not null,
    platform text not null default 'ios',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, device_token)
);

create trigger push_devices_set_updated_at
before update on public.push_devices
for each row execute function public.set_updated_at();

-- user_blocks

create table if not exists public.user_blocks (
    blocker_id uuid not null references public.profiles (id) on delete cascade,
    blocked_id uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    check (blocker_id <> blocked_id)
);

-- Indexes

create index if not exists circles_owner_id_idx on public.circles (owner_id);
create index if not exists circle_memberships_user_id_idx on public.circle_memberships (user_id);
create index if not exists circle_memberships_circle_id_idx on public.circle_memberships (circle_id);
create index if not exists circle_invites_circle_id_idx on public.circle_invites (circle_id);
create index if not exists shared_progress_user_date_idx on public.shared_progress (user_id, local_date desc);
create index if not exists cheers_recipient_date_idx on public.cheers (recipient_id, local_date);
create index if not exists cheers_sender_date_idx on public.cheers (sender_id, local_date);
create index if not exists push_devices_user_id_idx on public.push_devices (user_id);

-- Profile bootstrap when an auth user is created

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, display_name)
    values (
        new.id,
        coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'Friend')
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();
