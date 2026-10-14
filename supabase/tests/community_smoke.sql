-- Integration smoke tests: run against an ISOLATED LOCAL Supabase database,
-- after the migration, as its database owner. All test data is rolled back.
-- psql --set ON_ERROR_STOP=1 --file supabase/tests/community_smoke.sql "$DATABASE_URL"
-- This file has not been executed against a running Supabase instance here.
begin;
insert into auth.users(id) values
  ('f1000000-0000-4000-8000-000000000001'),
  ('f1000000-0000-4000-8000-000000000002');

set local role anon;
do $$
begin
  if has_function_privilege(current_user, 'public.darb_nearby_reports(double precision,double precision)', 'execute') then
    raise exception 'Unauthenticated role must not execute area RPC';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'f1000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"f1000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true}', true);

do $$
begin
  if has_table_privilege(current_user, 'darb_private.reports', 'select') or
     has_table_privilege(current_user, 'darb_private.reports', 'insert') or
     has_table_privilege(current_user, 'darb_private.report_confirmations', 'update') then
    raise exception 'Direct table privileges must remain denied';
  end if;
  begin
    perform public.darb_submit_report('test-invalid-type', 'invented', 33.31, 44.36, '');
    raise exception 'Invalid report type unexpectedly accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.darb_submit_report('test-invalid-coordinates', 'traffic', 50, 44.36, '');
    raise exception 'Invalid coordinates unexpectedly accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.darb_nearby_reports(null, 44.36);
    raise exception 'Missing area unexpectedly accepted';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

select public.darb_submit_report('smoke-report', 'traffic', 33.31, 44.36, 'Test only');
-- Retrying the same ID is idempotent and cannot change its content.
select public.darb_submit_report('smoke-report', 'closure', 33.31, 44.36, 'Must not overwrite');

do $$
begin
  if (select count(*) from public.darb_nearby_reports(33.31, 44.36) where id = 'smoke-report') <> 1 then
    raise exception 'Nearby area must contain exactly one report';
  end if;
  if (select count(*) from public.darb_nearby_reports(30.5, 47.8) where id = 'smoke-report') <> 0 then
    raise exception 'Distant region must not contain Baghdad report';
  end if;
  begin
    perform public.darb_submit_report('smoke-rate-limit', 'traffic', 33.31, 44.36, '');
    raise exception 'Rate limit unexpectedly bypassed';
  exception when raise_exception then
    if sqlerrm <> 'DARB_RATE_LIMIT_REPORTS' then raise; end if;
  end;
  begin
    perform public.darb_confirm_report('smoke-report');
    raise exception 'Own report unexpectedly confirmed';
  exception when raise_exception then
    if sqlerrm <> 'DARB_OWN_REPORT' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', 'f1000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"f1000000-0000-4000-8000-000000000002","role":"authenticated","is_anonymous":true}', true);
select public.darb_confirm_report('smoke-report');
select public.darb_confirm_report('smoke-report');

do $$
begin
  if (select confirmations from public.darb_nearby_reports(33.31, 44.36) where id = 'smoke-report') <> 1 then
    raise exception 'Duplicate confirmation changed count';
  end if;
  begin
    perform public.darb_submit_report('smoke-report', 'traffic', 33.31, 44.36, 'Spoof');
    raise exception 'Another author reused an existing report ID';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

reset role;
do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'darb_private.reports'::regclass) then
    raise exception 'Reports RLS is disabled';
  end if;
  if not (select relrowsecurity from pg_class where oid = 'darb_private.report_confirmations'::regclass) then
    raise exception 'Confirmation RLS is disabled';
  end if;
  if (select type from darb_private.reports where id = 'smoke-report') <> 'traffic' then
    raise exception 'Idempotent retry overwrote report';
  end if;
  if (select expires_at - created_at from darb_private.reports where id = 'smoke-report') <> interval '1 hour' then
    raise exception 'Server did not assign the expected expiry';
  end if;
end;
$$;
rollback;