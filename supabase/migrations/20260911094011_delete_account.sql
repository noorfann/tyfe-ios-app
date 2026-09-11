-- Account deletion: removes the authenticated user's server identity. Foreign
-- keys cascade to profiles, Circles, memberships, shared progress, Cheers,
-- push devices, and blocks. Local private data is never touched.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception 'authentication required';
    end if;

    delete from auth.users where id = v_user_id;
end;
$$;

revoke all on function public.delete_account() from public;
revoke all on function public.delete_account() from anon;
grant execute on function public.delete_account() to authenticated;
