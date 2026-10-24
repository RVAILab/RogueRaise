# Posting events and sharing the report link

The provider side of Ashland Daily Help: putting services on the public schedule, handling weeks that change, and getting a count back afterwards. It builds on [DATA_MODEL.md](DATA_MODEL.md), [SIGNUP_FLOW.md](SIGNUP_FLOW.md) and [schema.sql](schema.sql).

**Goals:** a weekly meal is set up once, in about a minute, and never touched again unless something changes. After each service, whoever ran it reports from the link they already have. A volunteer never needs an account.

---

## 1. The provider's home screen

After sign-in a provider sees one page with three short lists. On phones the order is what needs doing, then what's coming, then the series.

| Section | Shows | Main action |
|---|---|---|
| **Needs a report** | Past events (last 7 days) with no report yet: "Tue, Oct 20 · Uncle Food's Diner" | **Report now** (3 questions, right here) or **Share report link** |
| **Coming up** | The next 2 weeks of events, canceled ones crossed out | Tap to edit, cancel or move one date |
| **Your regular services** | Each repeating series as one line: "Every Tue · 5–7pm · Trinity Parish Hall" | Edit, end, or **Copy team link** |

A big **+ Add a service** button sits at the top.

Pending orgs see the same screen with a banner: "Your events are saved but won't show publicly until a coordinator approves Peace House." Report links are hidden until approval.

## 2. Adding a service (one form)

| Field | Notes |
|---|---|
| **Which listing is this?** | The org's claimed listings, plus "Something else". Picking one pre-fills the name, place and category. |
| **Name** | "Uncle Food's Diner". Public. |
| **Kind of help** | The 5 category chips from the home page. Under it, in small text: *After each one we'll ask: "How many meals were served?"* with a **Count something else** link that offers the other units. |
| **Where** | Pre-filled from the listing. Public. Free text, so "alley entrance behind the church" works. |
| **When** | Date · start time · end time *(optional)* |
| **Does it repeat?** | **No** · **Every week on** [M T W T F S S] · **Every month on the** [1st / 2nd / 3rd / 4th / last] [weekday] |
| **Until** | "Until I stop it" (default) or a date. Only shown if it repeats. |
| **Show on the public schedule** | On by default. Turn off for events that shouldn't be advertised; they still get reports. |

**Save** → "Added. Uncle Food's Diner, every Tuesday 5–7pm. Next one: Tue, Oct 27." For a series, the next screen offers the team link (see section 4).

Those two repeat patterns cover the services in the current directory: OHRA showers are "every week on Tue, Thu", Uncle Food's is "every week on Tue", and a monthly pantry is "the 2nd Saturday". Anything odder (every other week, or "first and third Friday") is posted as separate events or two series. A pattern builder would be the most confusing screen in the app.

### What happens underneath

- A **series** stores the pattern (`event_series.freq`, `weekdays`, `month_week`, local times, `timezone`).
- A nightly job runs `generate_occurrences(series, today + 8 weeks)`, which creates one `events` row per date. Running it twice adds nothing.
- Times are stored as local wall-clock times, so "5pm" stays 5pm across daylight saving (tested across Nov 1, 2026).
- A one-time event is just an `events` row with no series.

## 3. When the week changes

The schedule matters most to people traveling on foot to a meal, so changes must be quick and honest.

| Provider does | How | Public sees | Report needed? |
|---|---|---|---|
| **Cancel one date** | Tap the date → **Cancel this one** | "Canceled" on that date | No. It counts as canceled, not as zero. |
| **Move one date** | Tap the date → change time or place | The new time, with a "Changed" tag | Yes, as normal |
| **Change every date** (new time, new hall) | Edit the series → **Save for all upcoming dates** | Updated future dates | Yes |
| **Stop the service** | Edit the series → **End after** [date] | Dates after that disappear | Past dates still need reports |
| **Something else changed** | Edit the event or series | — | — |

The rules, all enforced and tested:

- Editing a date on its own marks it `detached`, so later series edits **skip it**. A canceled or moved date stays as the provider left it.
- A series edit rebuilds only **future** dates that have **no report and no link** (`apply_series_change`). History is never rewritten.
- Once an event has a report, **what it counts (unit and category) is locked**: "This event already has a report, so what it counts can't change. Create a new event instead." Time, place and name can still be fixed.
- Times must end after they start. A monthly pattern is one weekday on one week of the month.

"This and all following" (e.g. the meal moves halls from November on) is done by ending the old series the day before and starting a new one. The edit screen offers it as **From [date] on…** and does both steps.

## 4. Getting the count back: two kinds of report link

Most services are run by the same few people every week, so the simplest thing is **one link per regular service that never changes**.

### Team link (one per series), the default

- Shown after creating a series, and on **Your regular services → Copy team link**.
- The team lead saves it to their home screen or group chat once. The provider can also **Print QR** to tape inside the serving cart or shower trailer.
- Opening it always shows the **most recent date that still needs a report**, within the last 7 days: "Report for Tue, Oct 20 · Uncle Food's Diner". If nothing is waiting: "All caught up. See you next time."
- One live team link per series (enforced). **Get a new link** revokes the old one, for example if it was posted somewhere public.

### One-time link (one per event), for one-off events

- On a past one-off event: **Share report link** → the phone's share sheet (text, WhatsApp, email), or **Copy**.
- Works once and expires 7 days after the event.

### What the volunteer sees

Opening either link shows a mobile page with the three questions only, worded for the event's unit:

> **Tue, Oct 20 · Uncle Food's Diner**
>
> 1. Did it happen? **As planned · Partly · Canceled · Not sure**
> 2. How many meals were served? [ 58 ] **Counted · Estimated · Not recorded**
> 3. Was there need you couldn't meet? **Yes · None seen · Didn't check**
>
> **Send** · *Please don't include names or details about anyone.*

- "Canceled" or "Not sure" hides question 2 and sends straight away. No amount is recorded, never zero.
- The page has no login, no tracking, and no "who are you" field. The hub knows only which provider created the link.
- If the link has nothing to report: "Thanks, this report is already in. A provider on your team can correct it." If the event hasn't started yet: "This event hasn't started yet. Open the link again once it's over."
- If the org is suspended, its links stop working.

Every link report lands in the coordinator queue as **pending**, the same as a provider's own report.

## 5. Reminders

- **Day after**, if an event still has no report: one email to the org's providers, "How did Tuesday's meal go?", with the team link or a fresh one-time link. Sent once.
- **Weekly digest** (Monday): "2 services still need a report from last week." Providers can turn it off.
- No texts from the hub, because it doesn't hold volunteers' numbers.

## 6. Corrections

A provider opens a past event → **Correct the report** → the same three questions, pre-filled. The correction goes to the coordinator, and once approved it **replaces** the old numbers (the earlier one is marked `superseded`), as the provider preview promises. A volunteer link can't correct; it says to ask the provider.

## 7. What the public sees

- Each directory listing gets **Next times**: "Tue, Oct 27 · 5–7pm · Trinity Parish Hall". Canceled dates show "Canceled", and moved ones show "Changed".
- A new **This week** view lists every public event by day, with category filters. It is printable, like the existing directory.
- Events from orgs that aren't approved never appear (`public_events`).
- Every listing still carries "Confirm before traveling." Posted events are the provider's own word, so the source line reads "Posted by Peace House", not "Source reviewed".

---

## Tested

25 checks against Postgres (PGlite):

**Series generation**

- weekly Tue/Thu creates 16 dates in 8 weeks, only on Tuesdays and Thursdays, and running it again adds nothing
- 5–7pm is kept, including across the Nov 1 daylight-saving change
- 2nd Saturday always falls on day 8–14
- last Friday is never followed by another Friday in the same month
- bad patterns are rejected

**Edits**

- a series time change moves the untouched dates and leaves canceled and moved dates alone
- ending a series removes later dates
- the unit can't change after a report, but the place can

**Links**

- the team link opens the latest unreported date
- the team link rejects a second report for that date
- only one live team link per series, and reissue after revoke works
- a one-time link works once
- a link can't report before the event starts
- a suspended org's links stop working

## Not decided yet

- Should "Needs a report" go back further than 7 days? Late reports are useful but less reliable. The current design shows older ones only to coordinators.
- Do providers want text-message reminders badly enough to store a team lead's number? The current design says no, for privacy.
- The "This week" view could replace the home page hero on phones. That needs a design pass with the site's original team.
