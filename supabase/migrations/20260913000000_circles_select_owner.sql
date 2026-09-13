-- A Circle Owner may read their own circle even before the owner membership
-- row exists. `.insert().select()` (PostgREST INSERT ... RETURNING) reads the
-- new row back, and the membership-only SELECT policy rejected the just-created
-- circle, surfacing as 42501 "new row violates row-level security policy".

alter policy circles_select on public.circles
using (
    owner_id = (select auth.uid())
    or private.is_circle_member(id, (select auth.uid()))
);
