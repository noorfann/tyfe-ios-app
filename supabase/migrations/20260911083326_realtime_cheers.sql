-- Enable Realtime Postgres Changes for Cheers so recipients receive them live
-- (and again after reconnect). Row-Level Security still scopes deliveries to
-- the sender and recipient only.

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'cheers'
    ) then
        alter publication supabase_realtime add table public.cheers;
    end if;
end $$;
