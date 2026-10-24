# Rogue Raise: The Unhoused

A roughly 48-hour community build at [White Rabbit](https://whiterabbitashland.com) in Ashland, Oregon, focused on homelessness in the Rogue Valley.

- **When:** October 23–25, 2026. Kickoff Friday at 4pm; demos Sunday at 3pm.
- **Where:** White Rabbit, 5 North Main Street, #2, Ashland, OR 97520
- **Event page:** <https://whiterabbitashland.com/rogue-raise>
- **Sign up to build:** <https://www.whiterabbitashland.com/event/rogue-raise-the-unhoused-2026-10-23-1700>
- **Discord:** <https://discord.gg/Y9cvDZeFn>
- **Shared resources:** see [RESOURCES.md](RESOURCES.md) for team links, hotlines and the local service directory.

## What Is a Rogue Raise?

A Rogue Raise is White Rabbit's weekend community build, inspired by the old barn raise. Neighbors come together to build working software and practical tools for local problems, with the goal of producing something that lasts beyond the weekend.

## The Problem

The annual January Point-in-Time count is the main source of numbers on homelessness, and it is unreliable. Local advocates need trustworthy, defensible data to make the case for resources.

## What We're Building

Teams will work on three tracks:

1. **Clean the existing data.** De-duplicate records and match the same person across encounters, using confidence-based matching and persistent IDs.
2. **Improve the count.** Offline-capable mobile data collection paired with a web dashboard, rather than fixed kiosks.
3. **Add new data.** Gather signals from sources such as meal programs, syringe exchange, and community reporting, with a volunteer pipeline to collect it ethically.

The foundation is **syndromic surveillance**: a week-over-week public-health method that supports regular trend tracking instead of a once-a-year snapshot.

## Guiding Principles

- **Humanity:** serve the people the community is trying to help. People with lived experience of homelessness will be heard directly at the start of the weekend.
- **Truth:** get as close as possible to what is real.

The work pairs a first-person human story with a credible, defensible count.

## How the Weekend Works

1. **Opening ceremony** with stakeholders, then teams form.
2. **Parallel build** over the weekend.
3. **Presentations,** judged by real users on whether they would actually use the tool.
4. **Ownership:** each project gets a named owner tied to stakeholders so it keeps getting used after the event.

## In This Folder

| Path | What it is | Source |
| --- | --- | --- |
| [`RESOURCES.md`](RESOURCES.md) | Team links, hotlines and a condensed copy of the resource directory | SAT 1pm crew doc and the master spreadsheet |
| [`data/`](data/) | Full CSV export of each tab of the resource spreadsheet | "Ashland Resources for Unhoused People" (Google Sheet) |
| [`notes/`](notes/) | Team Google Docs converted to Markdown | The team's "Rogue Raise WR Oct 24" Drive folder |
| [`provider-tools-design/`](provider-tools-design/README.md) | Design docs and a Postgres schema for provider accounts, service reports and Community Pulse publishing in Ashland Daily Help | The `ashland-daily-help-design` Drive folder |

The provider tools design is copied from the Drive originals as of October 24, 2026. The Drive export dropped leading indentation, so the indentation in `schema.sql` was rebuilt by hand. The file is not byte-identical to the original, but it loads cleanly in PGlite (Postgres 17).

Some Drive files are left out of this public repo because they hold personal information: the raw meeting transcript, and the cleaned NAMI community partners sheet (which lists staff contacts).
