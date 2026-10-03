-- Run with psql from the repository root after replacing centres.csv with the
-- verified 88-row directory. This script intentionally fails for a header-only
-- or partial CSV rather than seeding fictional locations.
\set ON_ERROR_STOP on
begin;
truncate table public.centres;
\copy public.centres (name, region, address, phone, latitude, longitude) from 'supabase/seed/centres.csv' with (format csv, header true)
do $$
declare
  centre_count bigint;
begin
  select count(*) into centre_count from public.centres;
  if centre_count <> 88 then
    raise exception 'Expected exactly 88 verified centres, imported %', centre_count;
  end if;
end;
$$;
commit;
