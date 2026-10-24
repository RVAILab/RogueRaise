# Ashland Daily Help: data model and roles

Extends the live site's `data.js` / `core.js`. The full Postgres DDL is in [schema.sql](schema.sql).

## One survey for every service

Every event, whatever the service, gets the same three questions:

1. **Did it happen?** As planned / partly / canceled / not sure
2. **How many [unit]?** A number, marked counted / estimated / not recorded
3. **Was there need you couldn't meet?** Yes (pick reasons) / none observed / didn't check

Only the wording of question 2 changes. It comes from the event's **unit**, and each event has exactly one. When an org creates an event, the form pre-fills the unit from the category's default:

| Category | Default unit | Question 2 |
|---|---|---|
| Food & meals | `meals` | How many meals were served? |
| Showers & laundry | `sessions` | How many shower or laundry sessions? |
| Health connections | `encounters` | How many conversations with a navigator? |
| Shelter & housing | `encounters` | How many conversations with a navigator? |
| Everyday essentials | `items` *(new)* | How many kits or items were handed out? |

The org can change the unit. A pantry listed under Food might count `items` instead of `meals`. If a meal also hands out kits, it either reports meals only or posts a second event. To support a new kind of count later (e.g. `bed_nights` for shelter), add a row to `units` with its question and definition. Never add a new survey.

## Who logs in

The site says: "separate provider, coordinator and technical roles, with documented access and a backup for each responsibility." That gives three login types. Volunteers and the public never log in.

| Login type | Stored as | Who | Does |
|---|---|---|---|
| **Provider** | a row in `memberships` | Staff at OHRA, Peace House, ACCESS, a church meal team… | Applies for the org, posts events, shares report links, corrects reports, invites colleagues, sets publish consent, confirms the org's listing |
| **Coordinator** | `platform_roles.role = 'coordinator'` | The adopting team's hub staff, not part of any one provider | Approves orgs and their listing claims, reviews reports, decides what is published |
| **Admin** | `platform_roles.role = 'admin'` | One or two technical maintainers | Invites coordinators and admins, manages units and categories, releases and backups |

| No login | How they take part |
|---|---|
| **Volunteer** at the meal or trailer | Opens the event's report link, which a provider shares by text. There's no account, and the hub stores nothing about who received the link. |
| **Public** and people seeking help | Directory, public schedule and Community Pulse, as today: "No account needed." |
| **Navigators and funders** | Use the public site; a coordinator can send a CSV. |

All provider logins in an org are equal. There's no "owner", so nobody gets locked out when one person leaves. An approved org must always keep at least one provider (enforced), and two is recommended. Login is by emailed magic link, with no passwords.

## Entities

```
users ──< memberships >── organizations ──< resources (claimed listings)
  │        (providers)          │    ▲
  ├──< platform_roles           │    └── invitations (to an org, or to a platform role)
  │    (coordinator, admin)     ├──< event_series ──< events ──< report_submissions
  │                             │          │            │
  │                             │   categories ─────────┘ └──< survey_tokens (volunteer links)
  │                             │     └─ default_unit ─> units <── events.unit
  │                             │
  │                             └── publications (frozen weekly snapshots for Community Pulse)
  └───────────────────────────────── audit_log (every approve / reject / publish / role change)
```

`survey_tokens` hang off either one event (one-time link) or one `event_series` (team link).

| Table | Purpose | Maps from the live site |
|---|---|---|
| `organizations` | A provider org and its application: `pending` → `approved` / `rejected` (later `suspended`). Holds what the applicant told us (categories, about, listings they run) and the review outcome. `publish_consent` controls whether its totals appear publicly. | `demoEvents[].provider` (a string today) |
| `users` | A person who logs in (magic link). Email is for login only, never shown. | new |
| `memberships` | Provider login: links a user to an org. All members are equal. A user can belong to several orgs. | new |
| `platform_roles` | Coordinator and admin logins. | the "coordinator" step in the provider preview |
| `invitations` | An emailed invite to join an org (sent by any of its providers) or to become a coordinator or admin (sent by an admin). Single use, expires. | new |
| `units` | What can be counted: its dashboard label, the survey's question 2, and a definition. Seeded with meals, sessions, encounters, items. | `event.unit` |
| `categories` | The five directory categories, each with a `default_unit`. | `categories` |
| `resources` | Existing listings, same fields and ids. Adds `org_id` (who claimed it) and `provider_confirmed_at/by`. | `resources` (8 listings) |
| `event_series` | A repeating service: "every week on Tue, Thu" or "every month on the 2nd Saturday" (`freq`, `weekdays`, `month_week`), with local start and end times, category and unit. | new |
| `events` | One occurrence, which gets one report. Has a `category` and a single `unit`; optionally linked to a resource listing. Series dates carry `occurrence_date` and `detached` (edited on its own). | `demoEvents` |
| `report_submissions` | The three answers (outcome, method + value, unmet + reasons) plus review status. Every version is kept. | `reports` / `pending` |
| `survey_tokens` | Report links providers share with volunteers. A **team link** (one per series, revocable) always opens the latest date still needing a report. A **one-time link** (one per event) works once and expires about 7 days after it. Records which provider shared it, nothing about the recipient. Stores only a hash. | new |
| `publications` | One frozen snapshot per published week and revision: exactly what Community Pulse and the CSV show. | the sample week and CSV on `?view=impact` |
| `audit_log` | Who approved, rejected or changed what. | new |

## Permissions

| Can… | Public / volunteer | Provider | Coordinator | Admin |
|---|:-:|:-:|:-:|:-:|
| Browse directory, public events, Community Pulse | ✓ | ✓ | ✓ | ✓ |
| Submit a report through a shared link | ✓ (volunteer) | ✓ | | |
| Apply for an org; edit its profile; set publish consent | | ✓ | | |
| Create, edit and cancel own org's events and series (drafts while pending) | | ✓ | | |
| Share report links; submit and correct own org's reports | | ✓ | | |
| Invite colleagues (once the org is approved) | | ✓ | | |
| Confirm own org's directory listing | | ✓ | | |
| Approve or reject orgs and listing claims | | | ✓ | |
| Review reports; see pending reports and review notes | | | ✓ | ✓ (read) |
| Invite coordinators and admins; manage units and categories | | | | ✓ |

Separation of duties, enforced in the database:

- A coordinator **cannot approve reports for an org they belong to**, and **cannot review an application they submitted**. The adopting team therefore needs at least two coordinators, which also covers the About page's "backup for each responsibility".
- Only admins can grant coordinator or admin roles.

## Rules carried over from the site, now enforced by the database

| Site rule | Where |
|---|---|
| Unknown is never zero: `not_recorded` ⇔ `value IS NULL` | check on `report_submissions` |
| Whole number 0–100,000 | check on `report_submissions` |
| Canceled or unknown events have no amount | check `no_amount_when_canceled` |
| Reasons only when unmet need was `observed` | check on `report_submissions` |
| Only approved reports count; a correction replaces the old amount, never adds to it | `approve_report()` marks the old one `superseded`; a unique index allows one `approved` per event |
| Units are never summed together | aggregate by `unit` in `event_status_view` |
| Unreported events show as "awaiting", not zero | `event_status_view.status` |
| Publication only with provider permission | `public_event_status` filters by `publish_consent` and past events |
| Nothing public until an org is approved | `public_events`, `public_event_status` filter by `status = 'approved'` |

Sign-up and invite rules (details in [SIGNUP_FLOW.md](SIGNUP_FLOW.md)):

| Rule | Where |
|---|---|
| Rejecting an application needs a reason | `review_organization()` |
| A coordinator grants only listings the org asked for, and never one another org already holds | `review_organization()` |
| Only members of an approved org (or a coordinator recovering an org whose team left) can invite to it; only admins invite coordinators and admins | trigger `invitations_check` |
| An invite works once, before it expires, and only for the email it was sent to | `accept_invitation()` |
| An approved org keeps at least one provider | trigger `memberships_keep_last` |

Event and report-link rules (details in [EVENTS_FLOW.md](EVENTS_FLOW.md)):

| Rule | Where |
|---|---|
| Repeat patterns are weekly on chosen days, or monthly on the 1st–4th / last weekday | checks on `event_series`; `generate_occurrences()` |
| Series edits rebuild only future dates with no report or link, and skip dates edited on their own | `apply_series_change()` |
| What an event counts can't change once it has a report | trigger `events_lock_unit` |
| A link reports only on a started event of an approved org, within 7 days, once | `report_link_target()`, `submit_link_report()` |
| One live team link per series | unique index `one_live_series_link` |

Review and publishing rules (details in [REVIEW_AND_PUBLISH.md](REVIEW_AND_PUBLISH.md)):

| Rule | Where |
|---|---|
| Sending a report back needs a reason; the current approved amount stays | check on `report_submissions`; `send_back_report()` |
| Flags for corrections, unusual amounts (vs. 8-week median), late and partial reports | `review_queue_view` |
| Publish only finished weeks with nothing pending; coordinators only | `publish_week()` |
| Public numbers come from approved, consenting orgs and public events only | `build_week_snapshot()` |
| Republishing needs a public note; earlier revisions are kept | `publish_week()`, `publications` |
| Weeks never published or changed since publishing are listed | `weeks_to_publish` |

Tested against Postgres (PGlite) in four suites with 72 checks: reports (9), sign-up and invites (13), events and links (25), and review and publishing (25). Seeding the four sample providers reproduces the site's numbers, both from the live tables and in a published snapshot (220 meals = 124 counted + 96 estimated; 42 sessions; navigation awaiting a report). Corrections replace rather than add, and every rule in the tables above rejects bad input.

## Design choices

1. **One survey, one unit per event.** This is the simplest form for volunteers and gives comparable data across services. The survey's question 2 text lives in `units.question`, so wording changes don't need a code release.
2. **Canceled skips the rest.** When the answer to question 1 is "canceled", the form submits straight away with `not_recorded`.
3. **Each occurrence is its own row.** A nightly job keeps every series filled 8 weeks ahead, so each date can be reported, canceled or moved on its own. "Awaiting report" is just an event with no approved submission. Only two repeat patterns are offered (weekly on chosen days, monthly on the nth weekday), which covers every service in the current directory.
4. **Volunteers report by link, never by account.** A regular service has one team link the lead bookmarks once; a one-off event gets a one-time link. Either way the report goes into the same review queue, and corrections go through a provider login.
5. **No free-text field on reports.** People tend to type names into free text. The only free text is `review_note`, which coordinators write and the public never sees.
6. **No person-level data anywhere.** There are no client records, unique-visitor counts or demographics, which matches the About page's statement that individual service histories are outside the pilot.
7. **Listing claims ride along with the application.** The applicant ticks the existing listings they run. On approval the coordinator grants the ones they verified, which sets `resources.org_id`. A provider then confirms the listing, which sets `provider_confirmed_at` and fills in the "Provider confirmation" step the site currently shows as pending.
8. **Weekly publication with frozen snapshots.** Community Pulse reads `publications`, never the live tables. A coordinator publishes each Monday–Sunday week once nothing is pending; corrections publish as a new revision with a public note. See [REVIEW_AND_PUBLISH.md](REVIEW_AND_PUBLISH.md).
9. **Consent instead of suppression.** Only orgs with `publish_consent` appear, in totals or lanterns. Nothing published counts or describes people, so no small-number suppression is applied.

## Open questions

- Should shelter get its own unit (`bed_nights`) now, or stay on `encounters` for the pilot?
