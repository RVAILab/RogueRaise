-- Ashland Daily Help: provider accounts, events and service reports.
-- Extends the shapes in the live site's data.js / core.js:
--   resources  -> resources (adds org ownership + provider confirmation)
--   demoEvents -> events (+ event_series for recurring services)
--   reports    -> report_submissions, with review status
-- One survey for every service: only the unit (meals, sessions, ...) changes, and each event has exactly one.
-- Rule carried over from core.js: unknown is NULL, never 0, and different units are never summed.

create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------- Enums (values match core.js exactly) ----------
-- Three login types: provider (a row in memberships), coordinator and admin (rows in platform_roles).
-- Volunteers never log in; they report through a per-event link (survey_tokens).
create type org_status as enum ('pending', 'approved', 'rejected', 'suspended');
create type platform_role as enum ('coordinator', 'admin');
create type invite_status as enum ('pending', 'accepted', 'revoked');
create type event_status as enum ('scheduled', 'canceled_ahead'); -- canceled before it happened
create type series_freq as enum ('weekly', 'monthly');
create type report_outcome as enum ('completed', 'partial', 'canceled', 'unknown');
create type measure_method as enum ('counted', 'estimated', 'not_recorded');
create type unmet_need as enum ('none_observed', 'observed', 'not_assessed');
create type unmet_reason as enum ('capacity', 'supplies', 'transportation', 'timing', 'requirement', 'other');
create type review_status as enum ('pending', 'approved', 'rejected', 'superseded');

-- ---------- People and organizations ----------
create table users (
  id uuid primary key default gen_random_uuid(),
  email citext unique not null, -- login only (magic link); never published
  display_name text,
  created_at timestamptz not null default now(),
  disabled_at timestamptz
);

create table organizations (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  website text, -- optional: church groups and mutual aid may have none
  phone text,
  service_areas text[] not null default '{}', -- same vocabulary as resources.coverage
  categories text[] not null default '{}', -- what they offer; drives default units in the event form
  about text, -- "how we serve", shown to coordinators during review
  requested_resources text[] not null default '{}', -- existing listings they say they run
  status org_status not null default 'pending',
  applied_by uuid references users(id),
  applied_at timestamptz, -- set when the applicant verifies their email and submits
  reviewed_by uuid references users(id),
  reviewed_at timestamptz,
  review_note text, -- reason sent to the applicant on reject or suspend
  publish_consent boolean not null default false, -- may approved totals appear on Community Pulse?
  created_at timestamptz not null default now(),
  check (status in ('pending') or reviewed_at is not null)
);

-- Every provider login is equal within its org: post events, share report links, invite colleagues.
create table memberships (
  user_id uuid not null references users(id) on delete cascade,
  org_id uuid not null references organizations(id) on delete cascade,
  invited_by uuid references users(id), -- null for the person who applied
  created_at timestamptz not null default now(),
  primary key (user_id, org_id)
);

create table platform_roles (
  user_id uuid not null references users(id) on delete cascade,
  role platform_role not null,
  granted_by uuid references users(id),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

-- One table for both kinds of invite: a provider inviting a colleague to their org (org_id set),
-- or an admin inviting a coordinator/admin (platform_role set).
create table invitations (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  org_id uuid references organizations(id) on delete cascade,
  platform_role platform_role,
  token_hash bytea not null unique, -- store only a hash of the emailed token
  invited_by uuid not null references users(id),
  status invite_status not null default 'pending',
  expires_at timestamptz not null,
  accepted_by uuid references users(id),
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  check ((org_id is null) <> (platform_role is null))
);
create unique index one_open_org_invite on invitations (email, org_id) where status = 'pending' and org_id is not null;
create unique index one_open_role_invite on invitations (email, platform_role) where status = 'pending' and platform_role is not null;

-- ---------- What gets measured ----------
create table units (
  id text primary key, -- 'meals','sessions','encounters','items'
  label text not null, -- 'Meals provided' (dashboard heading)
  noun text not null, -- 'meals'
  question text not null, -- survey question 2 for this unit
  definition text not null -- 'Count meals delivered, not unique people.'
);

-- ---------- Directory (existing resources, now ownable) ----------
create table categories (
  id text primary key, -- 'food','housing','hygiene','health','essentials'
  label text not null,
  icon text not null,
  default_unit text not null references units(id) -- pre-fills events.unit for this kind of service
);

create table resources (
  id text primary key, -- keeps existing ids, e.g. 'ohra-showers'
  org_id uuid references organizations(id), -- null until an org claims the listing
  name text not null,
  provider text not null, -- display name; may differ from org name
  categories text[] not null,
  area text not null,
  coverage text[] not null,
  description text not null,
  address text,
  schedule text,
  access text,
  requirements text,
  cost text,
  phone text,
  source text not null,
  tags text[] not null default '{}',
  capacity text not null default 'Unknown',
  accessibility text,
  conflict boolean not null default false,
  reviewed_date date not null, -- "Source reviewed"
  provider_confirmed_at timestamptz, -- separate step, set by an org_admin of org_id
  provider_confirmed_by uuid references users(id),
  updated_at timestamptz not null default now()
);

-- ---------- Events ----------
-- A series is the recurring service ("Uncle Food's Diner, every Tuesday").
-- Each occurrence is its own event row, because each occurrence gets its own report.
-- category picks the default unit; the event form copies categories.default_unit into unit.
create table event_series (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id),
  resource_id text references resources(id),
  title text not null,
  service text not null, -- 'Community meal'
  category text not null references categories(id),
  unit text not null references units(id),
  -- The two patterns the form offers: "every week on Tue, Thu" or "every month on the 2nd Saturday".
  freq series_freq not null,
  weekdays smallint[] not null, -- 0 = Sunday … 6 = Saturday
  month_week smallint, -- monthly only: 1–4, or -1 for "last"
  local_start time not null,
  local_end time,
  timezone text not null default 'America/Los_Angeles',
  location text,
  is_public boolean not null default true,
  starts_on date not null,
  ends_on date, -- null = until the provider ends it
  created_by uuid not null references users(id),
  created_at timestamptz not null default now(),
  check (cardinality(weekdays) between 1 and 7 and weekdays <@ '{0,1,2,3,4,5,6}'),
  check ((freq = 'monthly') = (month_week is not null)),
  check (month_week is null or month_week in (1, 2, 3, 4, -1)),
  check (freq = 'weekly' or cardinality(weekdays) = 1),
  check (ends_on is null or ends_on >= starts_on),
  check (local_end is null or local_end > local_start)
);

create table events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id),
  series_id uuid references event_series(id) on delete set null,
  resource_id text references resources(id),
  title text not null,
  service text not null,
  category text not null references categories(id),
  unit text not null references units(id), -- the one thing this event reports
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  is_public boolean not null default true, -- show on the public schedule
  status event_status not null default 'scheduled',
  occurrence_date date, -- series only: the date the pattern produced, even if moved
  detached boolean not null default false, -- series only: edited on its own; series changes skip it
  created_by uuid not null references users(id),
  created_at timestamptz not null default now(),
  unique (series_id, occurrence_date),
  check ((series_id is null) = (occurrence_date is null)),
  check (ends_at is null or ends_at > starts_at)
);
create index on events (org_id, starts_at);
create index on events (starts_at) where is_public;

-- Once a report exists, what the event counts is fixed; otherwise old reports would change meaning.
create function lock_unit_after_report() returns trigger language plpgsql as $$
begin
  if (new.unit, new.category) is distinct from (old.unit, old.category)
     and exists (select 1 from report_submissions where event_id = old.id) then
    raise exception 'This event already has a report, so what it counts can''t change. Create a new event instead.';
  end if;
  return new;
end $$;
create trigger events_lock_unit before update on events for each row execute function lock_unit_after_report();

-- Turn a series pattern into event rows up to p_until (a nightly job keeps 8 weeks ahead).
-- Existing occurrences are left alone, so running it twice is harmless.
create function generate_occurrences(p_series uuid, p_until date) returns integer language plpgsql as $$
declare n integer;
begin
  insert into events (org_id, series_id, resource_id, title, service, category, unit, starts_at, ends_at,
                      location, is_public, occurrence_date, created_by)
  select s.org_id, s.id, s.resource_id, s.title, s.service, s.category, s.unit,
         (g.d + s.local_start) at time zone s.timezone,
         case when s.local_end is not null then (g.d + s.local_end) at time zone s.timezone end,
         s.location, s.is_public, g.d, s.created_by
  from event_series s
  cross join lateral (
    select d::date as d
    from generate_series(greatest(s.starts_on, current_date), least(coalesce(s.ends_on, p_until), p_until), interval '1 day') d
  ) g
  where s.id = p_series
    and extract(dow from g.d)::smallint = any (s.weekdays)
    and (s.freq = 'weekly'
         or (s.month_week = -1 and extract(month from g.d + 7) <> extract(month from g.d))
         or (s.month_week = ceil(extract(day from g.d) / 7.0)))
  on conflict (series_id, occurrence_date) do nothing;
  get diagnostics n = row_count;
  return n;
end $$;

-- After a provider edits a series ("all events"): rebuild its future occurrences from the new pattern.
-- Keeps anything that already happened, has a report or link, or was edited or canceled on its own.
create function apply_series_change(p_series uuid, p_until date) returns integer language plpgsql as $$
begin
  delete from events e
  where e.series_id = p_series and e.starts_at > now() and not e.detached
    and not exists (select 1 from report_submissions s where s.event_id = e.id)
    and not exists (select 1 from survey_tokens t where t.event_id = e.id);
  return generate_occurrences(p_series, p_until);
end $$;

-- ---------- Reports and review ----------
-- The same three questions for every service. Every submission is kept; at most one approved
-- submission per event is current, and approving a newer one marks the old one 'superseded'
-- (core.js approveReport replaces, never adds).
create table report_submissions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references events(id) on delete cascade,
  submitted_by uuid references users(id), -- null when sent through a one-time survey link
  via_token_id uuid, -- fk added below
  submitted_at timestamptz not null default now(),
  -- Q1 Did it happen?
  outcome report_outcome not null,
  -- Q2 How many? (in the event's unit)
  method measure_method not null,
  value integer, -- NULL = unknown, never 0
  -- Q3 Was there need you couldn't meet?
  unmet unmet_need not null,
  reasons unmet_reason[] not null default '{}',
  -- Review
  status review_status not null default 'pending',
  reviewed_by uuid references users(id),
  reviewed_at timestamptz,
  review_note text, -- coordinator-only, never published
  check (value is null or value between 0 and 100000),
  check ((method = 'not_recorded') = (value is null)),
  constraint no_amount_when_canceled
    check (outcome in ('completed', 'partial') or value is null),
  check (unmet = 'observed' or cardinality(reasons) = 0),
  check (submitted_by is not null or via_token_id is not null),
  check ((status = 'pending') = (reviewed_at is null)),
  check (status <> 'rejected' or coalesce(review_note, '') <> '') -- "send back" always says why
);
create unique index one_current_report_per_event on report_submissions (event_id) where status = 'approved';
create index review_queue on report_submissions (submitted_at) where status = 'pending';

-- Report link a provider shares with whoever ran the service. Volunteers have no account,
-- and the hub stores nothing about who received the link.
--   event link:  one event, works once, expires ~7 days after it.
--   series link: one per repeating service, bookmarked by the team lead; always opens the most recent
--                occurrence still waiting for a report (within 7 days). Revoke and reissue if it leaks.
create table survey_tokens (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references events(id) on delete cascade,
  series_id uuid references event_series(id) on delete cascade,
  token_hash bytea not null unique, -- store only a hash of the link token
  created_by uuid not null references users(id), -- the provider who shared it
  expires_at timestamptz, -- event links only
  used_at timestamptz, -- event links only: single use
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  check ((event_id is null) <> (series_id is null)),
  check ((event_id is null) = (expires_at is null)),
  check (series_id is null or used_at is null)
);
create unique index one_live_series_link on survey_tokens (series_id) where series_id is not null and revoked_at is null;
alter table report_submissions
  add constraint report_submissions_via_token_fk foreign key (via_token_id) references survey_tokens(id);

-- Which event a link reports on right now, or null with nothing to report.
-- An event "has a report" once any submission that wasn't rejected exists.
create function report_link_target(p_token uuid) returns uuid language sql stable as $$
  select e.id
  from survey_tokens t
  join events e on e.id = t.event_id
               or (e.series_id = t.series_id and e.starts_at >= now() - interval '7 days')
  join organizations o on o.id = e.org_id and o.status = 'approved'
  where t.id = p_token
    and t.revoked_at is null
    and t.used_at is null
    and (t.expires_at is null or t.expires_at > now())
    and e.starts_at <= now()
    and e.status = 'scheduled'
    and not exists (select 1 from report_submissions s where s.event_id = e.id and s.status <> 'rejected')
  order by e.starts_at desc
  limit 1
$$;

-- What happens when a volunteer presses "Send" on a link.
create function submit_link_report(p_token uuid, p_outcome report_outcome, p_method measure_method,
                                   p_value integer, p_unmet unmet_need, p_reasons unmet_reason[])
returns uuid language plpgsql as $$
declare v_event uuid; v_id uuid;
begin
  v_event := report_link_target(p_token);
  if v_event is null then
    if exists (select 1 from survey_tokens t join events e on e.id = t.event_id
               where t.id = p_token and e.starts_at > now()) then
      raise exception 'This event hasn''t started yet. Open the link again once it''s over.';
    end if;
    raise exception 'Thanks, this report is already in (or the link has expired). A provider on your team can correct it.';
  end if;
  insert into report_submissions (event_id, via_token_id, outcome, method, value, unmet, reasons)
  values (v_event, p_token, p_outcome, p_method, p_value, p_unmet, coalesce(p_reasons, '{}'))
  returning id into v_id;
  update survey_tokens set used_at = now() where id = p_token and event_id is not null;
  return v_id;
end $$;

-- ---------- Audit ----------
create table audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references users(id),
  action text not null, -- 'org.approve','report.approve','report.reject',...
  subject text not null, -- 'organizations:<id>', 'report_submissions:<id>'
  detail jsonb not null default '{}',
  at timestamptz not null default now()
);

-- ---------- Organization review ----------
-- p_listings: the subset of requested_resources the coordinator verified the org actually runs.
create function review_organization(p_org uuid, p_reviewer uuid, p_approve boolean, p_listings text[], p_note text)
returns void language plpgsql as $$
begin
  if not exists (select 1 from platform_roles where user_id = p_reviewer and role = 'coordinator') then
    raise exception 'Only coordinators review organizations';
  end if;
  if exists (select 1 from organizations where id = p_org and applied_by = p_reviewer) then
    raise exception 'Coordinators cannot review an application they submitted';
  end if;
  if not exists (select 1 from organizations where id = p_org and status = 'pending' and applied_at is not null) then
    raise exception 'No submitted application for %', p_org;
  end if;
  if not p_approve and coalesce(p_note, '') = '' then
    raise exception 'Say why the application was not approved';
  end if;
  update organizations
  set status = case when p_approve then 'approved' else 'rejected' end::org_status,
      reviewed_by = p_reviewer, reviewed_at = now(), review_note = p_note
  where id = p_org;
  if p_approve then
    if not (coalesce(p_listings, '{}') <@ (select requested_resources from organizations where id = p_org))
      then raise exception 'Can only grant listings the organization requested'; end if;
    if exists (select 1 from resources where id = any (p_listings) and org_id is not null and org_id <> p_org)
      then raise exception 'A requested listing is already claimed by another organization'; end if;
    update resources set org_id = p_org where id = any (p_listings);
  end if;
  insert into audit_log (actor_id, action, subject, detail)
  values (p_reviewer, case when p_approve then 'org.approve' else 'org.reject' end,
          'organizations:' || p_org, jsonb_build_object('listings', p_listings));
end $$;

-- Accepting an invite creates the membership or platform role. The app resolves the token to p_invite.
create function accept_invitation(p_invite uuid, p_user uuid) returns void language plpgsql as $$
declare inv invitations;
begin
  select * into inv from invitations where id = p_invite for update;
  if inv.id is null or inv.status <> 'pending' or inv.expires_at < now() then
    raise exception 'This invitation is no longer valid';
  end if;
  if not exists (select 1 from users where id = p_user and email = inv.email) then
    raise exception 'Sign in with the email address the invitation was sent to';
  end if;
  if inv.org_id is not null then
    insert into memberships (user_id, org_id, invited_by) values (p_user, inv.org_id, inv.invited_by)
    on conflict do nothing;
  else
    insert into platform_roles (user_id, role, granted_by) values (p_user, inv.platform_role, inv.invited_by)
    on conflict do nothing;
  end if;
  update invitations set status = 'accepted', accepted_by = p_user, accepted_at = now() where id = p_invite;
  insert into audit_log (actor_id, action, subject) values (p_user, 'invite.accept', 'invitations:' || p_invite);
end $$;

-- Who may send an invite: any member of an approved org (for that org), or a coordinator recovering
-- an org whose team has left; only admins for platform roles.
create function check_invitation() returns trigger language plpgsql as $$
begin
  if new.org_id is not null then
    if not exists (select 1 from organizations where id = new.org_id and status = 'approved') then
      raise exception 'Invites open once the organization is approved';
    end if;
    if not exists (select 1 from memberships where org_id = new.org_id and user_id = new.invited_by)
       and not exists (select 1 from platform_roles where user_id = new.invited_by and role = 'coordinator') then
      raise exception 'Only members of this organization can invite to it';
    end if;
  elsif not exists (select 1 from platform_roles where user_id = new.invited_by and role = 'admin') then
    raise exception 'Only admins can invite coordinators or admins';
  end if;
  return new;
end $$;
create trigger invitations_check before insert on invitations for each row execute function check_invitation();

-- An approved org always keeps at least one provider login.
create function keep_last_member() returns trigger language plpgsql as $$
begin
  if exists (select 1 from organizations where id = old.org_id and status = 'approved')
     and not exists (select 1 from memberships where org_id = old.org_id and user_id <> old.user_id) then
    raise exception 'An organization needs at least one provider login. Invite a replacement first.';
  end if;
  return old;
end $$;
create trigger memberships_keep_last before delete on memberships for each row execute function keep_last_member();

-- ---------- Approval (mirrors core.js approveReport) ----------
create function approve_report(p_submission uuid, p_reviewer uuid) returns void language plpgsql as $$
declare v_event uuid; v_org uuid;
begin
  select s.event_id, e.org_id into v_event, v_org
  from report_submissions s join events e on e.id = s.event_id
  where s.id = p_submission and s.status = 'pending' for update;
  if v_event is null then raise exception 'No pending report %', p_submission; end if;
  if not exists (select 1 from platform_roles where user_id = p_reviewer and role = 'coordinator') then
    raise exception 'Only coordinators approve reports';
  end if;
  if exists (select 1 from memberships where user_id = p_reviewer and org_id = v_org) then
    raise exception 'Coordinators cannot approve reports for their own organization';
  end if;
  update report_submissions set status = 'superseded'
  where event_id = v_event and status = 'approved';
  update report_submissions set status = 'approved', reviewed_by = p_reviewer, reviewed_at = now()
  where id = p_submission;
  insert into audit_log (actor_id, action, subject) values (p_reviewer, 'report.approve', 'report_submissions:' || p_submission);
end $$;

-- ---------- Read models for Community Pulse ----------
-- One row per event with its current approved amount.
-- Gives the dashboard everything reportSeries() needs: scheduled vs reported vs measured.
create view event_status_view as
select
  e.id as event_id,
  e.org_id,
  o.name as provider,
  e.service,
  e.category,
  e.unit,
  (e.starts_at at time zone 'America/Los_Angeles')::date as local_date,
  s.id as submission_id,
  s.outcome,
  s.method,
  s.value,
  s.unmet,
  s.reasons,
  case
    when s.id is null and e.status = 'canceled_ahead' then 'canceled'
    when s.id is null then 'awaiting_report'
    when s.outcome = 'canceled' then 'canceled'
    when s.value is null then 'not_recorded'
    when s.value = 0 then 'measured_zero'
    else 'amount_reported'
  end as status
from events e
join organizations o on o.id = e.org_id
left join report_submissions s on s.event_id = e.id and s.status = 'approved';

-- Public version: only approved orgs that consented, only past events.
create view public_event_status as
select v.*
from event_status_view v
join organizations o on o.id = v.org_id
join events e on e.id = v.event_id
where o.status = 'approved' and o.publish_consent and e.starts_at < now();

-- Public schedule: a pending org can draft events, but nothing shows until it is approved.
create view public_events as
select e.id, o.name as provider, e.title, e.service, e.category, e.starts_at, e.ends_at, e.location, e.resource_id
from events e
join organizations o on o.id = e.org_id
where o.status = 'approved' and e.is_public and e.status = 'scheduled';

-- ---------- Coordinator review queue ----------
-- Pending reports with the context a coordinator needs, and flags that say where to look twice.
-- "typical" = median approved amount for the same series (or same org + unit for one-offs) over the
-- previous 8 weeks; needs 3+ earlier reports before it flags anything.
create view review_queue_view as
select
  s.id as submission_id,
  s.submitted_at,
  e.id as event_id,
  o.name as provider,
  e.title,
  e.unit,
  (e.starts_at at time zone 'America/Los_Angeles')::date as local_date,
  s.outcome, s.method, s.value, s.unmet, s.reasons,
  (s.via_token_id is not null) as via_link,
  cur.value as replaces_value,
  hist.typical,
  array_remove(array[
    case when cur.id is not null then 'correction' end,
    case when hist.n >= 3 and s.value > 2 * hist.typical then 'higher_than_usual' end,
    case when hist.n >= 3 and s.value < hist.typical / 2 then 'lower_than_usual' end,
    case when cur.id is null and s.submitted_at > e.starts_at + interval '7 days' then 'late' end,
    case when s.outcome = 'partial' and s.value is null then 'partial_without_amount' end
  ], null) as flags
from report_submissions s
join events e on e.id = s.event_id
join organizations o on o.id = e.org_id
left join report_submissions cur on cur.event_id = s.event_id and cur.status = 'approved'
left join lateral (
  select count(*) as n, percentile_cont(0.5) within group (order by p.value) as typical
  from report_submissions p join events pe on pe.id = p.event_id
  where p.status = 'approved' and p.value is not null
    and pe.unit = e.unit and pe.id <> e.id
    and (case when e.series_id is not null then pe.series_id = e.series_id else pe.org_id = e.org_id end)
    and pe.starts_at between e.starts_at - interval '8 weeks' and e.starts_at
) hist on true
where s.status = 'pending';

-- Approve several at once ("Approve all without flags"); each still goes through approve_report's checks.
create function approve_reports(p_submissions uuid[], p_reviewer uuid) returns integer language plpgsql as $$
declare v uuid; n integer := 0;
begin
  foreach v in array p_submissions loop
    perform approve_report(v, p_reviewer);
    n := n + 1;
  end loop;
  return n;
end $$;

-- "Send back": the provider sees the note and can submit again. The current approved amount, if any, stays.
create function send_back_report(p_submission uuid, p_reviewer uuid, p_note text) returns void language plpgsql as $$
begin
  if not exists (select 1 from platform_roles where user_id = p_reviewer and role = 'coordinator') then
    raise exception 'Only coordinators review reports';
  end if;
  if exists (select 1 from report_submissions s join events e on e.id = s.event_id
             join memberships m on m.org_id = e.org_id and m.user_id = p_reviewer
             where s.id = p_submission) then
    raise exception 'Coordinators cannot review reports for their own organization';
  end if;
  update report_submissions set status = 'rejected', reviewed_by = p_reviewer, reviewed_at = now(), review_note = p_note
  where id = p_submission and status = 'pending';
  if not found then raise exception 'No pending report %', p_submission; end if;
  insert into audit_log (actor_id, action, subject, detail)
  values (p_reviewer, 'report.send_back', 'report_submissions:' || p_submission, jsonb_build_object('note', p_note));
end $$;

-- ---------- Weekly publication to Community Pulse ----------
-- Community Pulse shows published weeks only. Each publish freezes a snapshot, so the public numbers never
-- shift under a reader; a correction approved later is published as a new revision of that week.
create table publications (
  id uuid primary key default gen_random_uuid(),
  week_start date not null check (extract(isodow from week_start) = 1), -- Monday, local time
  revision integer not null,
  snapshot jsonb not null, -- exactly what Community Pulse and the CSV show
  note text, -- public, e.g. "Peace House corrected Tuesday's count"
  published_by uuid not null references users(id),
  published_at timestamptz not null default now(),
  unique (week_start, revision)
);

-- The figures for one week, built only from approved reports of approved orgs that consented.
-- Same shape the current site computes in core.js: per unit, per day, counted vs estimated, coverage, unmet need.
create function build_week_snapshot(p_week_start date) returns jsonb language sql stable as $$
  with ev as (
    select v.*
    from event_status_view v
    join organizations o on o.id = v.org_id and o.status = 'approved' and o.publish_consent
    join events e on e.id = v.event_id and e.is_public
    where v.local_date between p_week_start and p_week_start + 6
  ),
  units_in_week as (select distinct unit from ev),
  days as (
    select u.unit, d::date as local_date,
           count(ev.event_id) as scheduled,
           count(ev.event_id) filter (where ev.status = 'awaiting_report') as awaiting,
           count(ev.event_id) filter (where ev.status = 'canceled') as canceled,
           count(ev.value) as measured,
           sum(ev.value) as total,
           coalesce(sum(ev.value) filter (where ev.method = 'counted'), 0) as counted,
           coalesce(sum(ev.value) filter (where ev.method = 'estimated'), 0) as estimated
    from units_in_week u
    cross join generate_series(p_week_start, p_week_start + 6, interval '1 day') d
    left join ev on ev.unit = u.unit and ev.local_date = d::date
    group by u.unit, d
  ),
  day_json as (
    select unit, jsonb_agg(jsonb_build_object(
             'date', local_date, 'scheduled', scheduled, 'total', total,
             'counted', counted, 'estimated', estimated,
             'status', case
               when scheduled = 0 then 'no_event'
               when awaiting = scheduled then 'awaiting_report'
               when canceled = scheduled then 'canceled'
               when measured = 0 then 'not_recorded'
               when measured + canceled < scheduled then 'partial'
               when total = 0 then 'measured_zero'
               else 'amount_reported' end)
           order by local_date) as days
    from days group by unit
  ),
  unit_json as (
    select jsonb_object_agg(u.id, jsonb_build_object(
             'label', u.label, 'noun', u.noun, 'definition', u.definition,
             'total', t.total, 'counted', t.counted, 'estimated', t.estimated,
             'events_scheduled', t.scheduled, 'events_reported', t.scheduled - t.awaiting,
             'days', d.days)) as units
    from (select unit, sum(total) as total, sum(counted) as counted, sum(estimated) as estimated,
                 sum(scheduled) as scheduled, sum(awaiting) as awaiting
          from days group by unit) t
    join units u on u.id = t.unit
    join day_json d on d.unit = t.unit
  ),
  providers as (
    select jsonb_agg(jsonb_build_object('name', provider, 'services', services, 'status',
             case when awaiting = 0 then 'reported' when awaiting = n then 'awaiting_report' else 'partly_reported' end)
           order by provider) as providers
    from (select provider, count(*) as n, count(*) filter (where status = 'awaiting_report') as awaiting,
                 array_agg(distinct service) as services
          from ev group by provider) p
  ),
  unmet as (
    select jsonb_build_object(
             'observed', count(*) filter (where unmet = 'observed'),
             'none_observed', count(*) filter (where unmet = 'none_observed'),
             'not_assessed', count(*) filter (where unmet = 'not_assessed'),
             'reasons', coalesce((select jsonb_object_agg(r, n) from (
               select r, count(*) as n from ev, unnest(ev.reasons) r group by r) x), '{}'::jsonb)
           ) as unmet
    from ev where submission_id is not null
  )
  select jsonb_build_object(
    'week_start', p_week_start, 'week_end', p_week_start + 6,
    'units', coalesce((select units from unit_json), '{}'::jsonb),
    'providers', coalesce((select providers from providers), '[]'::jsonb),
    'unmet', (select unmet from unmet),
    'notes', jsonb_build_array(
      'Service amounts count servings and visits, not unique people.',
      'An unreported amount is unknown, never zero.',
      'Only participating providers who agreed to publish are included.')
  )
$$;

create function publish_week(p_week_start date, p_reviewer uuid, p_note text) returns integer language plpgsql as $$
declare v_rev integer;
begin
  if not exists (select 1 from platform_roles where user_id = p_reviewer and role = 'coordinator') then
    raise exception 'Only coordinators publish';
  end if;
  if p_week_start + 7 > (now() at time zone 'America/Los_Angeles')::date then
    raise exception 'The week of % is not over yet', p_week_start;
  end if;
  if exists (select 1 from report_submissions s join events e on e.id = s.event_id
             where s.status = 'pending'
               and (e.starts_at at time zone 'America/Los_Angeles')::date between p_week_start and p_week_start + 6) then
    raise exception 'Review the pending reports for this week before publishing';
  end if;
  select coalesce(max(revision), 0) + 1 into v_rev from publications where week_start = p_week_start;
  if v_rev > 1 and p_note is null then
    raise exception 'Say what changed since the last version (shown publicly)';
  end if;
  insert into publications (week_start, revision, snapshot, note, published_by)
  values (p_week_start, v_rev, build_week_snapshot(p_week_start), p_note, p_reviewer);
  insert into audit_log (actor_id, action, subject, detail)
  values (p_reviewer, 'week.publish', 'publications:' || p_week_start, jsonb_build_object('revision', v_rev));
  return v_rev;
end $$;

-- What Community Pulse reads: the latest revision of each published week.
create view community_pulse as
select distinct on (week_start) week_start, revision, snapshot, note, published_at
from publications
order by week_start, revision desc;

-- Coordinator to-do: finished weeks never published, or changed since their last publication.
create view weeks_to_publish as
with weeks as (
  select distinct date_trunc('week', local_date)::date as week_start from event_status_view
)
select w.week_start,
       (select count(*) from review_queue_view q where date_trunc('week', q.local_date)::date = w.week_start) as pending_reports,
       p.revision as published_revision,
       case when p.revision is null then 'never_published' else 'changed_since_published' end as reason
from weeks w
left join community_pulse p on p.week_start = w.week_start
where w.week_start + 7 <= (now() at time zone 'America/Los_Angeles')::date
  and (p.revision is null or p.snapshot - 'week_start' is distinct from build_week_snapshot(w.week_start) - 'week_start');

-- ---------- Seed: values from the live site ----------
insert into units (id, label, noun, question, definition) values
  ('meals', 'Meals provided', 'meals', 'How many meals were served?', 'Count meals delivered, not unique people.'),
  ('sessions', 'Shower & laundry sessions', 'sessions', 'How many shower or laundry sessions?', 'Count shower or laundry sessions, not unique people.'),
  ('encounters', 'Navigation encounters', 'conversations', 'How many conversations with a navigator?', 'Count conversations about services or next steps, not unique people.'),
  ('items', 'Items handed out', 'items', 'How many kits or items were handed out?', 'Count kits or items given out (a hygiene kit is one item), not unique people.');

insert into categories (id, label, icon, default_unit) values
  ('food', 'Food & meals', 'food', 'meals'),
  ('housing', 'Shelter & housing', 'home', 'encounters'),
  ('hygiene', 'Showers & laundry', 'water', 'sessions'),
  ('health', 'Health connections', 'heart', 'encounters'),
  ('essentials', 'Everyday essentials', 'sun', 'items');
