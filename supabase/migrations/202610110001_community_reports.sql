-- Darb optional shared reports, schema version 1.
-- Apply as the database owner on your own Supabase instance. Re-running this
-- migration preserves reports. This file does not configure Auth or deploy a server.
-- Keep darb_private OUT of PostgREST's exposed schemas.
begin;

create schema if not exists darb_private;
revoke all on schema darb_private from public, anon;
grant usage on schema darb_private to authenticated;

create table if not exists darb_private.reports (
  id text primary key check (id ~ '^[A-Za-z0-9_-]{1,96}$'),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('traffic', 'crash', 'hazard', 'police', 'closure', 'construction', 'weather', 'camera')),
  latitude double precision not null check (latitude between 29 and 38),
  longitude double precision not null check (longitude between 38 and 49),
  description text not null default '' check (char_length(description) <= 280),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > created_at and expires_at <= created_at + interval '24 hours')
);

create table if not exists darb_private.report_confirmations (
  report_id text not null references darb_private.reports(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);

create index if not exists darb_reports_region_idx
  on darb_private.reports(latitude, longitude, expires_at);
create index if not exists darb_reports_owner_time_idx
  on darb_private.reports(reporter_id, created_at desc);
create index if not exists darb_confirmations_owner_time_idx
  on darb_private.report_confirmations(user_id, created_at desc);

-- RLS is deny-by-default. Clients have no direct table privilege or policy.
-- The restricted functions below are the sole supported read/write interface.
alter table darb_private.reports enable row level security;
alter table darb_private.report_confirmations enable row level security;
revoke all on table darb_private.reports from public, anon, authenticated;
revoke all on table darb_private.report_confirmations from public, anon, authenticated;

create or replace function darb_private.nearby_reports(
  p_latitude double precision,
  p_longitude double precision
) returns table (
  id text, type text, latitude double precision, longitude double precision,
  description text, created_at timestamptz, expires_at timestamptz, confirmations bigint
)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'DARB_AUTH_REQUIRED' using errcode = '42501';
  end if;
  if p_latitude is null or p_longitude is null
     or not (p_latitude between 29 and 38 and p_longitude between 38 and 49) then
    raise exception 'DARB_INVALID_REGION' using errcode = '22023';
  end if;
  return query
  select r.id, r.type, r.latitude, r.longitude, r.description,
         r.created_at, r.expires_at,
         (select count(*) from darb_private.report_confirmations c where c.report_id = r.id)
  from darb_private.reports r
  where r.expires_at > now()
    -- Index-friendly prefilter and then a fixed 30 km great-circle radius.
    and r.latitude between p_latitude - 0.28 and p_latitude + 0.28
    and r.longitude between p_longitude - 0.36 and p_longitude + 0.36
    and 6371000.0 * 2 * asin(sqrt(least(1.0,
      power(sin(radians(r.latitude - p_latitude) / 2), 2)
      + cos(radians(p_latitude)) * cos(radians(r.latitude))
      * power(sin(radians(r.longitude - p_longitude) / 2), 2)
    ))) <= 30000
  order by r.created_at desc, r.id
  limit 200;
end;
$$;

create or replace function darb_private.submit_report(
  p_id text,
  p_type text,
  p_latitude double precision,
  p_longitude double precision,
  p_description text default ''
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_now timestamptz := now();
  v_ttl interval;
  v_existing_owner uuid;
begin
  if v_user is null then
    raise exception 'DARB_AUTH_REQUIRED' using errcode = '42501';
  end if;
  if p_id is null or p_id !~ '^[A-Za-z0-9_-]{1,96}$'
     or p_type is null or p_type not in ('traffic', 'crash', 'hazard', 'police', 'closure', 'construction', 'weather', 'camera')
     or p_latitude is null or p_longitude is null
     or not (p_latitude between 29 and 38 and p_longitude between 38 and 49)
     or char_length(coalesce(p_description, '')) > 280 then
    raise exception 'DARB_INVALID_REPORT' using errcode = '22023';
  end if;

  -- Serialize writes per authenticated identity so parallel requests cannot race
  -- around per-user limits. API/Auth gateway limits are additionally required.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text, 0));
  select r.reporter_id into v_existing_owner from darb_private.reports r where r.id = p_id;
  if v_existing_owner is not null then
    if v_existing_owner = v_user then return; end if; -- idempotent retry, no update
    raise exception 'DARB_INVALID_REPORT_ID' using errcode = '22023';
  end if;
  if exists (
    select 1 from darb_private.reports r
    where r.reporter_id = v_user and r.created_at > v_now - interval '30 seconds'
  ) or (
    select count(*) from darb_private.reports r
    where r.reporter_id = v_user and r.created_at > v_now - interval '1 hour'
  ) >= 8 or (
    select count(*) from darb_private.reports r
    where r.reporter_id = v_user and r.created_at > v_now - interval '1 day'
  ) >= 30 then
    raise exception 'DARB_RATE_LIMIT_REPORTS' using errcode = 'P0001';
  end if;

  v_ttl := case p_type
    when 'traffic' then interval '1 hour'
    when 'crash' then interval '1 hour'
    when 'police' then interval '30 minutes'
    when 'closure' then interval '6 hours'
    when 'construction' then interval '6 hours'
    when 'camera' then interval '12 hours'
    else interval '2 hours'
  end;
  insert into darb_private.reports
    (id, reporter_id, type, latitude, longitude, description, created_at, expires_at)
  values
    (p_id, v_user, p_type, p_latitude, p_longitude, btrim(coalesce(p_description, '')), v_now, v_now + v_ttl);
end;
$$;

create or replace function darb_private.confirm_report(p_report_id text)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_reporter uuid;
begin
  if v_user is null then
    raise exception 'DARB_AUTH_REQUIRED' using errcode = '42501';
  end if;
  if p_report_id is null or char_length(p_report_id) > 96 then
    raise exception 'DARB_INVALID_REPORT_ID' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_user::text, 0));
  select r.reporter_id into v_reporter from darb_private.reports r
  where r.id = p_report_id and r.expires_at > now();
  if not found then
    raise exception 'DARB_REPORT_UNAVAILABLE' using errcode = 'P0001';
  end if;
  if v_reporter = v_user then
    raise exception 'DARB_OWN_REPORT' using errcode = 'P0001';
  end if;
  if exists (select 1 from darb_private.report_confirmations c
             where c.report_id = p_report_id and c.user_id = v_user) then
    return;
  end if;
  if (select count(*) from darb_private.report_confirmations c
      where c.user_id = v_user and c.created_at > now() - interval '1 hour') >= 60 then
    raise exception 'DARB_RATE_LIMIT_CONFIRMATIONS' using errcode = 'P0001';
  end if;
  insert into darb_private.report_confirmations (report_id, user_id)
  values (p_report_id, v_user) on conflict do nothing;
end;
$$;

-- Public RPC wrappers stay SECURITY INVOKER. The privileged implementations live
-- in a non-exposed schema and validate the caller themselves.
create or replace function public.darb_nearby_reports(
  p_latitude double precision, p_longitude double precision
) returns table (
  id text, type text, latitude double precision, longitude double precision,
  description text, created_at timestamptz, expires_at timestamptz, confirmations bigint
) language sql security invoker set search_path = '' as $$
  select * from darb_private.nearby_reports(p_latitude, p_longitude);
$$;

create or replace function public.darb_submit_report(
  p_id text, p_type text, p_latitude double precision, p_longitude double precision,
  p_description text default ''
) returns void language sql security invoker set search_path = '' as $$
  select darb_private.submit_report(p_id, p_type, p_latitude, p_longitude, p_description);
$$;

create or replace function public.darb_confirm_report(p_report_id text)
returns void language sql security invoker set search_path = '' as $$
  select darb_private.confirm_report(p_report_id);
$$;

-- A PostgreSQL function is otherwise executable by PUBLIC by default.
revoke all on function darb_private.nearby_reports(double precision, double precision) from public, anon, authenticated;
revoke all on function darb_private.submit_report(text, text, double precision, double precision, text) from public, anon, authenticated;
revoke all on function darb_private.confirm_report(text) from public, anon, authenticated;
revoke all on function public.darb_nearby_reports(double precision, double precision) from public, anon, authenticated;
revoke all on function public.darb_submit_report(text, text, double precision, double precision, text) from public, anon, authenticated;
revoke all on function public.darb_confirm_report(text) from public, anon, authenticated;

grant execute on function darb_private.nearby_reports(double precision, double precision) to authenticated;
grant execute on function darb_private.submit_report(text, text, double precision, double precision, text) to authenticated;
grant execute on function darb_private.confirm_report(text) to authenticated;
grant execute on function public.darb_nearby_reports(double precision, double precision) to authenticated;
grant execute on function public.darb_submit_report(text, text, double precision, double precision, text) to authenticated;
grant execute on function public.darb_confirm_report(text) to authenticated;

notify pgrst, 'reload schema';
commit;