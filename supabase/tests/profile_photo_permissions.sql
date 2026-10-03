-- Run separately against an isolated migrated Supabase database, as postgres.
-- Transaction-local relational fixtures only. Never mutate Storage metadata in SQL.
begin;

insert into auth.users (id, email) values
    ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'photo-owner@example.test'),
    ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'photo-peer@example.test'),
    ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'photo-unrelated@example.test');
update public.profiles set avatar_token = 'sun',
    avatar_path = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg'
where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
insert into public.circles (id, name, owner_id) values (
    'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'Photo permission fixture',
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
);
insert into public.circle_memberships (circle_id, user_id, role) values
    ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'owner'),
    ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'member');

-- Owner can read/delete/upload own correctly shaped keys, including uncommitted uploads.
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
    if not private.owns_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg')
       or not private.can_read_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/22222222-2222-4222-8222-222222222222.jpg') then
        raise exception 'owner must have own-key read/write permission';
    end if;
    if private.owns_profile_photo('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb/11111111-1111-4111-8111-111111111111.jpg')
       or private.owns_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/nested/11111111-1111-4111-8111-111111111111.jpg')
       or private.owns_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.png')
       or private.owns_profile_photo('../11111111-1111-4111-8111-111111111111.jpg') then
        raise exception 'foreign or malformed upload/delete keys must be denied';
    end if;
end $$;
reset role;

-- Current Circle peer may read the committed photo, never write it or read orphan uploads.
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
    if not private.can_read_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg') then
        raise exception 'current Circle peer must read referenced photo';
    end if;
    if private.owns_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg')
       or private.can_read_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/22222222-2222-4222-8222-222222222222.jpg') then
        raise exception 'peer must not write owner keys or read uncommitted photos';
    end if;
end $$;
reset role;

-- Revoked membership immediately prevents issuing another signed URL/read.
delete from public.circle_memberships
where circle_id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  and user_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
set local role authenticated;
do $$
begin
    if private.can_read_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg') then
        raise exception 'revoked peer must no longer read photo';
    end if;
end $$;
reset role;

select set_config('request.jwt.claims', '{"sub":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
    if private.can_read_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg') then
        raise exception 'unrelated account must not read photo';
    end if;
end $$;
reset role;

-- Signed-out requests lack a UID (and anon cannot execute the private helper).
select set_config('request.jwt.claims', '{"role":"anon"}', true);
do $$
begin
    if private.can_read_profile_photo('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa/11111111-1111-4111-8111-111111111111.jpg') then
        raise exception 'signed-out request must not read photo';
    end if;
    if (select avatar_token from public.profiles where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') <> 'sun' then
        raise exception 'photo reference update must preserve avatar token';
    end if;
end $$;
rollback;
