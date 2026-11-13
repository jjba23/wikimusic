# Vision

WikiMusic is a music encyclopaedia that anyone may read and the content
management system a community runs it with — both Guile Scheme, both served by
one GNU Artanis process over SQLite. This document is about the second half:
what would have to become true for an instance to be a place where several
musicians accumulate knowledge worth citing, rather than a finished gallery that
one person fills. None of it changes the premise — an instance stays small enough
to read in an afternoon, and every page stays a list.

## Where wikimusic is today

The collection is three entities and the rows that hang off them. A song, an
artist and a genre each carry a description stored as Org and rendered by
`orgwebalchemy` through `org2html`, called in one place (`entity-details`), so
every description is styled by the same components and carries no raw HTML.
Artworks, external sources, comments, opinions, relations and song versions are
separate tables with their own repositories, and a version may carry an ASCII
tab, a PDF and a Guitar Pro 5 file at once.

The tablature is where the project has gone furthest. `(wikimusic guitarpro)`
parses a `.gp5` header — title, artist, tempo, key, measure and track counts —
and stops there, strict about every declared string length, because a file that
does not add up must answer "the header of this tab could not be read" rather
than a guess. Beside it, a reader may ask the page to draw the tab: alphaTab,
Bravura and a SONiVOX SoundFont are vendored under `pub/vendor/alphatab/` (about
two megabytes, refreshed by `maak alphatab`) and are not fetched until the offer
is pressed. A page with an ASCII tab is a page to practise from: auto-scroll, a
chord guide derived from the tab's own chord names (`Am  x02210`), a metronome
synthesised in the browser. `/tuner` is the other half — twenty-two presets as
ordinary addresses (`?preset=`), each string named with its frequency, the
arithmetic pure in `(wikimusic domain tuning)` off A4 = 440 Hz.

Underneath: lists with sort, tile size and search as real addresses that remember
themselves in cookies; light and dark with the choice kept; four locales
(English, Dutch, Spanish, Japanese) with every sentence a literal argument of
`G_`; accounts through `bewaking` sealed tokens with a permission per action and
a per-row ownership rule (`guard-owner`, `may-mutate?`) whose refusals *raise*
rather than emit, so a route cannot half-refuse; no sign-up route; articles in
five kinds (tutorial, video, chord-guide, theory, discussion) whose comments are
open to anyone behind an off-page honeypot field; JSON-LD, Open Graph tags,
`/sitemap.xml` and `/robots.txt` built from the instance's own rows in
`(wikimusic seo)`; and a `/api/v1` whose specification, `openapi/wikimusic.yaml`,
is the source of a generated Scheme tree that is checked in and guarded by
`maak api-check`.

Two honest observations about it. The specification describes 26 creates, 14
updates and 13 deletes with permission-gated handlers and an `api-write-spec`
suite that exercises them, while the manual still calls the API "read-only on
purpose" — a write surface is a promise whether or not it is written down. And
the sitemap names five standing pages plus every song, artist and genre, capped
at 20,000 rows, with a comment saying that an instance which grows past it
"serves a sitemap index instead, which is a change to this controller" — and
articles are in neither list.

The decisions the future has to live with are these. The OpenAPI document is the
source, so an API change begins in YAML and a hand edit to the generated tree
fails a check. Ownership is one `created_by` column and one super grant
(`wikimusic:modify-permissions`) that overrides ownership and nothing else —
there are no roles, no teams and no per-entity moderators to hang a review
workflow on. A description is text rendered by one function, so anything
structured has to become a column rather than markup. The SQL runs through
kracht's builders with `sql-parameterize` as the escape hatch for the statements
they cannot express (`OR`, `COUNT(*)`), which is why search today is
`display_name LIKE ? OR description LIKE ?`. Assets arrive through a `maak` task
and are served by the instance — though the page does load a page-view beacon,
`pub/js/symbanta.js`, whose endpoint no `(wikimusic env)` value can turn off.
Migrations go through `mutastructura` with a SHA256 ledger, and fourteen specs
under `test/veritas/unit`, run with the deployment's own `env.scm`, are the
contract for all of it.

## The vision

1. **A reader can search the way a musician thinks.** A ranked query over names,
   descriptions, artist names and tab bodies, filterable by key, tuning, genre and
   the chords a tab names — so "what can I play with these three chords" is a
   query, not a browsing session, and the same query is a documented operation on
   `/api/v1` with a total that agrees with the page it paginates.

2. **Every edit is attributed and reversible.** An entity's Org body has a
   history — who wrote it, when, what changed — and a revert that costs one press,
   so a contributor can be wrong without the correction being a conversation with
   the instance's owner.

3. **The tablature is data the site owns, not only a file it holds.** Measures,
   notes, tunings and tempo parsed once, so transposition, chord naming, a range
   to loop, a printed sheet and a search over musical content all read the same
   representation — and a file that defeats alphaTab still yields something the
   page can show.

4. **A collection can leave.** One command exports an instance — descriptions,
   artworks, tabs, comments, provenance — as a portable bundle, another imports it
   into a fresh instance, and two instances can mirror an entity's rows with their
   history attached, so a fork is a copy of a community's knowledge rather than of
   an empty demo.

5. **A machine can contribute as a first-class author.** Writes arrive through the
   documented API under the same permission and ownership rules, idempotently and
   with a dry run, and an instance can hold a write for review — so populating an
   instance is a reviewed contribution, not a script with a password.

## Features that are in scope and not built yet

- **Full-text search.** A page and its count are already separated so the two
  agree; the hard part is the index — SQLite FTS5 with a tokeniser that behaves on
  tab lines and chord names, a migration that builds it from existing rows, a
  PostgreSQL path, and one `WHERE` for page and total.
- **A write API the manual admits to.** The handlers and the specification exist;
  the hard part is the contract they do not state — idempotency keys, a
  precondition so two editors cannot silently overwrite each other, and errors
  matching the rules the HTML forms enforce.
- **Revision history.** The hard part is not the table but the diff and the
  revert: whose row is it after a revert, and how a revert avoids resurrecting a
  deleted artwork.
- **A complete chord vocabulary.** The guide derives fingerings from regex-matched
  names; the hard part is covering the chords people actually write, transposing
  with a capo, and saying "I do not know this shape" rather than drawing wrong.

## New features that would be worth having

- **A practice mode built on the score.** Loop a range of measures, ramp the tempo
  a few beats per minute each pass, count the passes — possible only once the
  tablature is data (vision 3), and the one thing a learner would open the site
  for twice a day.
- **A scale and mode page.** Symbanta already reaches the page as a script; a page
  drawing a scale on a fretboard, in the shapes the chord guide uses, would bridge
  theory articles and tablature. Not yet in scope.
- **Bulk import from ChordPro and `.gp` files.** The corpus problem is bigger than
  the code problem: an importer with a dry run, a duplicate check and a report
  would do more for the encyclopaedia than any page.

## Contributions that would move the needle

1. **Write the API contract down.** Fix the manual's "read-only" paragraph, name
   every operation on one page, and add contract tests for the writes that already
   exist. An afternoon; the code is there and the documentation is misleading.
2. **FTS5 search behind the existing repository interface.** A weekend for someone
   comfortable with SQLite and Guile; every reader benefits, and `search-songs` and
   `count-songs` are already shaped for the swap.
3. **Articles into the sitemap, then a sitemap index.** A day, and it is the
   difference between an instance that is findable and one that is not.
4. **A chord table with a spec.** Two days; a published catalogue of shapes and a
   spec asserting the transpositions, and the guide stops guessing.
5. **A task that fails when a `G_` string changed without its catalogs merged.**
   The rule is documented in `(wikimusic prose)` and violated by hand today; a
   day's work stops three translations decaying.

## Compared to related projects

| Project | What it is | Where wikimusic differs |
| --- | --- | --- |
| MusicBrainz | A community-maintained encyclopaedia of music metadata — artists, releases, recordings — with identifiers, edit voting and a JSON/XML service over PostgreSQL. | Metadata and identifiers, where wikimusic is tablature and practice. No release model, no voting, no citable identifiers, one Artanis process instead of a service estate — but its pages are a page a player can play from. |
| Ultimate Guitar | A commercial tablature site: official and user tabs, playback, mobile apps. | The largest corpus in the world and the one to beat on search and duplicates. wikimusic is free software, self-hostable, serves its own assets and carries no ads; it has orders of magnitude less content and a `LIKE` query. |
| Songsterr | A commercial browser tablature player: a JavaScript score renderer with synchronised playback over a large library. | Songsterr is a player with a catalogue; wikimusic is a wiki that happens to play. Both lean on a renderer they did not write, but wikimusic keeps the original `.gp5` downloadable. |
| Genius | Lyrics with per-line annotations and a large editorial community. | Genius models annotation, which wikimusic does not; wikimusic models versions, tunings, tabs and ownership, which Genius does not. Annotation is the idea worth borrowing. |
| Soundslice | A browser notation player with serious practice tools: slow down, loop, transpose, import from Guitar Pro. | The closest thing to vision 3 done commercially. Soundslice reads the whole file; wikimusic reads the header and hands the file to alphaTab, so loop-and-ramp practice waits on data it does not parse. |
| TuxGuitar | A free desktop tablature editor that reads and writes Guitar Pro formats. | TuxGuitar parses what wikimusic only describes, but it is a program, not a community: no accounts, no ownership, no links to the artist, genre and prose around a tab. |
| MediaWiki | The general-purpose wiki: free-form pages, full revision history, watchlists, extensions. | MediaWiki gives anyone a page and remembers every edit; wikimusic gives a row a schema, relations and an owner, and remembers only the latest text. Vision 2 is MediaWiki's strongest idea applied to a stricter model. |
| ChordPro | A plain-text chord-sheet format with a reference renderer and many consumers. | ChordPro solves the portable artefact; wikimusic solves the connected one. An importer and an exporter would cost days and connect the project to decades of song sheets. |

What the others do that wikimusic could still add: revision history with voting
and watchlists (MediaWiki, MusicBrainz), ranked search with facets (Ultimate
Guitar), annotation (Genius), practice tooling on a parsed score (Soundslice), and
a plain-text interchange format (ChordPro). Where wikimusic is ahead and should
stay ahead: one language from route to view, an instance that serves its own type,
glyphs, renderer and SoundFont with no CDN in the path, a Guitar Pro file both
downloadable and drawn in the page, a tuner and metronome on the same page as the
tab, ownership recorded per row, a REST API generated from a checked-in
specification — and the whole application in a tree small enough to read.

## In the long run

The largest bet is vision 3. A tablature that is data unlocks practice tooling,
transposition, search over musical content and any meaningful import or export; a
tablature that stays a file caps all of them at what alphaTab can draw. The second
bet is that attribution and review — not content volume — is what makes a
community encyclopaedia credible, and that a small instance can manage it with one
`created_by` column and a history table if it refuses to grow roles. The third is
portability: export, import and mirroring turn every fork from a demo into a
branch of the same collection. A fourth, explicitly speculative, is federation —
the natural end of portability, and the wrong thing to build before the bundle
exists.

Running under all of them is a wager already made: Scheme all the way down, no
build step, no JavaScript framework, a page assembled from SXML and translated by
gettext at render time. The cost is visible — alphaTab is two megabytes of
JavaScript nobody here wrote, and the responsive shell needs a browser to test.
The benefit is that a contributor can follow a page from route to markup without
leaving the language, which is the property worth defending when a feature asks
for a bundler.

## Using this document

Three items are worth a weekend each and need no permission: the API
documentation, full-text search, and articles in the sitemap. Two are the
project's direction and should be argued over first: the score as data, and
revision history. The rest are bets, and unowned.

*This document describes intent, not commitments.*
