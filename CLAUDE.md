# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A documentation repo for [Rogue Raise](https://whiterabbitashland.com/rogue-raise), White Rabbit's weekend community builds in Ashland, Oregon. It holds Markdown, CSV and design files: event summaries, shared links, resource snapshots, converted meeting notes and design docs, including one Postgres schema. Nothing here is built or run, and there is no test suite. Software built at an event lives in its own repo.

## Layout

- `README.md`: what a Rogue Raise is, plus an index of events. Add a row to its Events table for every new event folder.
- `<YYYY-MM>-<slug>/`: one folder per event, named for the month it starts.
  - `README.md`: the event summary (dates, place, links, problem, tracks, format), drawn from the White Rabbit event page.
  - `RESOURCES.md`: team links, hotlines and a dated, condensed snapshot of the local resource directory.
  - `data/`: full CSV exports, one per tab of the source spreadsheet, with every column. Keep `RESOURCES.md` in step with them.
  - `notes/`: team Google Docs converted to Markdown, named `<YYYY-MM-DD>-<slug>.md`. Each starts by naming the doc it came from.
  - Other folders hold design work copied from the team's Drive, such as `provider-tools-design/`. List each one in the event README's "In This Folder" table.

## Sibling repos

Repos built for an event are checked out next to this one under `../`:

- `2026-10-unhoused`: `../ashlanddailyhelp` ([RVAILab/ashlanddailyhelp](https://github.com/RVAILab/ashlanddailyhelp), public). A static, offline-capable PWA listing community resources for Ashland and Jackson County, with a provider "pulse" view. It has its own `CLAUDE.md`; read that before working there.

Keep the two in step: when the resource directory changes in one, check whether the other needs the same change.

## Content rules

This material may be used to refer real people to real services, so accuracy beats completeness:

- State only what a source says, and link the source. Note when a listing comes from web research rather than a call to the provider.
- Date every snapshot ("as of October 24, 2026") and name the source document it was copied from.
- Mark conflicting or secondhand details as needing confirmation instead of picking one.
- Never present fictional or demo data (such as the ashlanddailyhelp pulse numbers) as real service statistics.
- **Never commit private or personal information.** This repo and `ashlanddailyhelp` are both public. That rules out:
  - names of unhoused people, participants, staff or volunteers
  - personal emails and phone numbers
  - contact lists and raw transcripts

  Organization phone numbers and shared organization mailboxes are fine. When converting notes, write "a participant" instead of a speaker's name. When unsure, leave it out and ask.

## Formatting

- Put blank lines before and after every heading.
- End every file with a newline.
- Use `<https://…>` for bare URLs and Markdown tables for link collections, matching the existing files.
