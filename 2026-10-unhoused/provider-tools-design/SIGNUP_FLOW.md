# Org sign-up and invite flow

How a provider organization gets onto Ashland Daily Help, and how its people, the coordinators and the admins get access. It builds on [DATA_MODEL.md](DATA_MODEL.md) and [schema.sql](schema.sql).

**Goals:** a church meal team with no website can apply from a phone in under 5 minutes; nobody can pose as OHRA and take over its listing; nothing public changes until a coordinator says yes.

---

## 1. Provider applies

The entry point is the existing **"Try the provider preview"** link and a new **"Join as a provider"** button on `?view=providers`.

| Step | Screen | What's stored |
|---|---|---|
| 1 | **Your email.** "We'll send a sign-in link. No password." | nothing yet |
| 2 | Applicant taps the emailed link; the email is now verified | `users` row |
| 3 | **About your group** (one screen): name · website *(optional)* · public phone · areas served (Ashland / Medford / Jackson County) · what you offer (the 5 category chips from the home page) · "How do you serve people?" (2–3 sentences) | `organizations` row, `status = pending`; `memberships` row for the applicant |
| 4 | **Do you run any of these?** The 8 existing listings, filtered to their categories, as checkboxes, plus "None of these / we're new" | `requested_resources` |
| 5 | **Before you send.** A short list of what reporting means: "Counts only, never names. Reports are reviewed before anything is shared. You choose whether your totals are public." One checkbox: "We agree." | `applied_at = now()` |
| 6 | **Thanks, we'll be in touch.** The status page shows "Waiting for a coordinator (usually 2 working days)" | an email goes to all coordinators |

Why verify the email first: it keeps bots out without a CAPTCHA, and an application always has a reachable person behind it.

**While pending, the applicant can:** sign in, see the status, edit the application, and draft events. Drafts are saved but not shown (`public_events` hides orgs that aren't approved). **They can't:** invite colleagues, share report links, or appear anywhere public.

## 2. Coordinator reviews

The coordinator queue shows each application with what the applicant entered and a short checklist:

- [ ] **Real group:** website or public listing matches the name, or someone known in the community vouches for it
- [ ] **Call-back:** phone the org on a number from its *public* website or listing, not the number in the form, and confirm this applicant works or volunteers there
- [ ] **Listings:** for each requested listing, the call-back confirmed they run it
- [ ] **Fits the hub:** offers one of the five kinds of help in the area

Then one of:

| Action | Result | Email to applicant |
|---|---|---|
| **Approve** (tick which listings to grant) | `status = approved`; granted listings get `org_id`; events become public | "You're in. Here's how to post your first event." |
| **Ask for more** | stays `pending`; the coordinator's question goes out by email | "One quick question…" |
| **Not approved** (reason required) | `status = rejected`, reason in `review_note` | the reason, plus "Reply if we got this wrong." |

Enforced in the database (`review_organization`): only coordinators can review; a coordinator can't review an application they submitted; a rejection needs a reason; only requested listings can be granted; and a listing another org already holds can't be granted. The coordinator resolves that case by phone first.

**Groups with no website** (church meals, mutual aid, a group of neighbors) are welcome. The call-back or a vouch from a known partner replaces the website check. This matters here: much of the street-level help in Ashland is informal.

**Suspending an org later** (`status = suspended`, with a reason) hides its events and totals, keeps its history, and stops new link reports. Approval can be restored.

## 3. Provider invites colleagues

Available once the org is approved. On **Your team**, any provider can:

1. **Invite:** enter an email → `invitations` row (expires in 7 days) → email "Sam from Peace House added you to Ashland Daily Help."
2. The invitee taps the link, signs in with **that** email, and is now a provider for the org (`accept_invitation`).
3. **Remove** a colleague, or leave. The last provider of an approved org can't be removed ("Invite a replacement first"), and the screen nudges toward two.

There's no owner and no admin-vs-member split: every provider can do everything for their org. If the whole team leaves anyway, a coordinator re-verifies by call-back and sends a fresh invite (see section 6).

**One person, several orgs.** A volunteer who coordinates for both Peace House and a church meal gets invited to both and picks the org at the top of their dashboard.

## 4. Volunteers report by link (no invite, no account)

On each past event, a provider taps **Share report link**. That gives them a link to paste into a text or group chat. Whoever opens it sees the 3 questions for that event and nothing else.

- The link works once, then shows "Thanks, this event's report is in. A provider on your team can correct it."
- It expires about 7 days after the event.
- The hub records who *shared* the link, never who received it.

## 5. Coordinators and admins

They don't apply; they're invited.

- **The first admin** is created by hand at launch (one row in `platform_roles`), then invites a second admin as backup.
- **Admins invite coordinators** from an admin screen (`invitations.platform_role = 'coordinator'`). Only admins can do this (enforced).
- **Coordinators should not be providers** for orgs they review. The database blocks approving reports for, or reviewing the application of, their own org. Start with **at least two coordinators** so each can cover the other.

## 6. Edge cases

| Situation | What happens |
|---|---|
| The org already exists (a colleague applied) | Step 3 searches names as you type: "Peace House is already here. Ask someone there to invite you, or contact a coordinator." Coordinators merge rare duplicates. |
| Someone claims a listing that isn't theirs | The call-back fails → coordinator approves without that listing, or rejects. |
| The magic link opens on a different device | Fine. The link signs in whichever device opens it; links expire in 15 minutes and work once. |
| Applicant's email bounces or they change jobs | A colleague invites the replacement; old logins are removed from **Your team**. |
| The whole team left | A coordinator calls the org's public number, then sends a new invite from the coordinator screen. This is the only time a coordinator invites to an org. |

## 7. Emails

All plain text, short, and in the site's voice:

1. Sign-in link (every sign-in)
2. Application received → applicant
3. New application → coordinators
4. Approved / one quick question / not approved → applicant
5. Team invite → invitee
6. Coordinator or admin invite → invitee

No marketing email and no tracking pixels, consistent with the About page ("No accounts, trackers…" becomes "accounts for providers only, still no trackers").

---

## Tested

These rules run against Postgres (PGlite) in the test suite, and each one rejected bad input:

- coordinator tries to invite a coordinator
- pending org invites a colleague
- provider tries to review their own org
- rejection with no reason
- granting a listing that wasn't requested
- reviewing the same application twice
- claiming a listing another org owns
- accepting an invite with a different email
- accepting an invite twice
- non-member invites to the org
- accepting an expired invite
- removing the last provider

The suite also checked the expected path: drafts stay hidden until approval and then appear, and a volunteer's link report enters the queue as pending with no user account.

## Not decided yet

- Review time promise ("usually 2 working days"): the adopting team should set this.
- Whether an org can choose a "primary contact" for coordinator calls, or coordinators just use the public number (current design).
- Sign-in provider: email magic links via the auth library the app is built on. Pick that when the stack is chosen.
