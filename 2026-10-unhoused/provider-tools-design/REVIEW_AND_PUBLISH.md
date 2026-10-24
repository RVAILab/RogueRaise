# Coordinator review and publishing to Community Pulse

How reports go from "sent" to the public Community Pulse page. It builds on [DATA_MODEL.md](DATA_MODEL.md), [EVENTS_FLOW.md](EVENTS_FLOW.md) and [schema.sql](schema.sql).

The live site already promises the shape of this: *"A coordinator looks each report over before any number is shared"*, *"Only approved reports reach the dashboard"*, *"Corrections replace earlier amounts only after review"*, and *"Real publication will require provider permission and disclosure review."* This design keeps every one of those promises.

**Goals:** a coordinator clears a normal week in about 10 minutes; the public sees numbers that don't change under them; every correction is visible.

---

## 1. The weekly rhythm

Weeks run **Monday to Sunday**, matching the site's sample week (Oct 19–25).

| When | What happens |
|---|---|
| During the week | Reports arrive from team links, one-time links and provider logins. Each one waits as **pending**. |
| **Monday** | Providers get the reminder digest for anything still unreported. Coordinators get "Last week: 14 reports waiting, 2 services not reported yet." |
| **Mon–Wed** | Coordinators work the queue. |
| **Thursday** | A coordinator publishes last week. Community Pulse updates. |

Publishing once a week, rather than on every approval, gives late reports a chance to arrive, lets a coordinator see the week as a whole before anyone else does, and gives the public a stable "week of…" number.

## 2. The review queue

One screen, sorted by flag and then oldest first. Each row:

> **Peace House · Uncle Food's Diner · Tue, Oct 20**\
> As planned · **58 meals, counted** · Unmet need: supplies\
> `Higher than usual (typical 25)` · via team link

### Flags (computed, never blocking)

| Flag | Means | Usual action |
|---|---|---|
| `correction` | Replaces an approved amount; the old value is shown ("was 124") | Check the change makes sense |
| `higher_than_usual` / `lower_than_usual` | More than double or less than half the median of the same service's approved reports over the last 8 weeks (needs at least 3) | Glance for a typo (4200 vs 42) |
| `late` | First report arrived more than 7 days after the event | Approve; note it if it changes a published week |
| `partial_without_amount` | "Partly" with no number | Fine, but worth a look |

Rows with no flags are normal, so most weeks are a single **Approve all without flags** click (`approve_reports`), then a look at the few flagged rows.

### Actions

| Action | Effect | Provider sees |
|---|---|---|
| **Approve** | Becomes the event's current amount. A correction replaces the old amount and marks it `superseded`. | Nothing, unless it's a correction ("Your correction was accepted") |
| **Send back** (reason required) | Marked `rejected` with the note. Any current approved amount stays. | "A coordinator asked: *Is 4,200 a typo for 42?*" with **Correct the report** |

There's no "edit the number for them". Coordinators never change a provider's figure; they ask. That keeps every number traceable to the provider who sent it.

### Enforced in the database (tested)

- Only coordinators approve, send back or publish.
- A coordinator can't review reports for an org they belong to.
- Sending back needs a reason.
- Each approval writes to `audit_log`.

### Coordinator's other tabs

- **Applications:** org sign-ups (see [SIGNUP_FLOW.md](SIGNUP_FLOW.md)).
- **Not reported:** last week's events with nothing in yet, grouped by provider, with a **Nudge** button that re-sends the provider reminder.
- **All providers:** the full internal picture, including orgs that haven't agreed to publish. Coordinators only.

## 3. Publishing a week

**Weeks to publish** lists every finished week that has never been published, or has changed since it was (`weeks_to_publish`). Opening one shows a **preview of exactly what will go public**: the same Community Pulse page, with "Preview" across it.

**Publish** (`publish_week`) is allowed only when:

- the week is over (Sunday has passed, local time), and
- **no report for that week is still pending**. Unreported events don't block it; they publish as "Awaiting report", which is honest.

Publishing **freezes a snapshot**: one stored copy of every figure on the page. Community Pulse and the CSV read the snapshot, never the live tables, so a number a reader saw on Thursday is still there on Friday.

### What goes into the snapshot

It's built only from **approved reports**, of **approved orgs** that **agreed to publish**, for **public events**. This is the same shape the current site computes in `core.js`, so the existing Community Pulse page can render it almost unchanged:

| Part | Contents |
|---|---|
| Per unit (meals, sessions, encounters, items) | total, counted, estimated, events scheduled vs reported, and a definition ("Count meals delivered, not unique people.") |
| Per day, per unit (all 7 days) | amount and a status: `amount_reported`, `measured_zero`, `partial`, `not_recorded`, `canceled`, `awaiting_report` or `no_event`, which are exactly the site's chart marks |
| Lanterns | each participating provider: `reported`, `partly_reported` or `awaiting_report` |
| Unmet need | number of reports saying observed / none / not assessed, and counts per reason |
| Notes | "Counts servings and visits, not unique people." · "Unreported is unknown, never zero." · "Only participating providers who agreed to publish are included." |

Units are never added together, and an empty day is never shown as zero, as on the current site.

## 4. Corrections after publishing

1. A provider corrects Tuesday's count (124 → 130) or a late report arrives.
2. The coordinator approves it. The **published page does not change yet** (tested).
3. The week reappears in **Weeks to publish** as "changed since published".
4. Republishing creates **revision 2** and **requires a public note**, e.g. *"Sample meal team A corrected Tuesday; navigation report arrived."*
5. Community Pulse shows the latest revision with **"Revised Oct 29"** and the note. Earlier revisions stay stored, and the CSV includes a `revision` column.

This is the site's "a new report replaces it after approval — it never adds to it", applied to publication too.

## 5. Disclosure decisions

These were open questions in the data model. The recommended answers:

- **Provider permission is the control.** An org's numbers and name appear only if it set `publish_consent`. Orgs that haven't agreed are left out of totals *and* lanterns, and the coverage line says "of participating providers".
- **No small-number suppression.** Everything published is a count of servings or visits, never people, and never broken down by anything about people (no age, gender or housing status). With one provider per unit, the total *is* that provider's number, which is exactly what they consented to share. Revisit this if any person-level field is ever added.
- **Unmet need is published as counts of reports**, not people: "1 of 3 reports noted unmet need · Supplies: 1". There is no free text, so nothing identifying can leak through it.
- **The "Fictional sample data" banner** comes off only for weeks built from real published snapshots. The sample week stays available as a labeled demo.

## 6. What the public sees

- **Community Pulse** opens on the latest published week, with ‹ › to browse earlier weeks. If a week isn't published yet: "Last week's numbers are being reviewed. Check back Thursday."
- Each page has a "Published Oct 29 by the Ashland Daily Help coordinators" line, plus "Revised…" when it applies.
- **Download CSV** is generated from the snapshot: one row per unit per day, unknowns blank, plus `week_start` and `revision` columns.

---

## Tested

25 checks against Postgres (PGlite), using the site's own sample week:

**Review queue**

- 4 pending reports appear in the queue
- a provider can't approve
- send back needs a reason
- bulk approve works
- a sent-back report leaves the approved 42 in place
- 80 against a typical 25 is flagged "higher than usual"
- a correction is flagged and shows the old value

**Publishing**

- refused while reports are pending, before the week ends, or by a provider
- the published snapshot shows meals 220 = 124 counted + 96 estimated, sessions 42, and navigation "awaiting"
- a non-consenting org's 500 meals are excluded from totals and lanterns
- 3 of 4 lanterns are lit
- unmet need: 1 observed, 1 none, 1 not assessed, supplies 1
- all 7 days are present

**Corrections**

- the public number stays at 220 while a correction is pending
- the week is flagged as changed after approval
- republishing without a note is refused
- revision 2 shows 226 meals and navigation 17, with 4 of 4 reported
- revision 1 is kept

## Not decided yet

- **The publish day.** Thursday gives three working days for review. The adopting team may prefer Friday.
- **Monthly roll-ups.** Easy to add later from the weekly snapshots, which already sum by unit. Not needed for the pilot.
- **Who sees the "All providers" internal view.** Coordinators only for now. Funders may ask for it, which would be a consent conversation with providers, not a database setting.
