# Vendored: the typefaces the interface is set in

These files are what a page of wikimusic is set in.  They are *vendored* rather
than linked to: `maak vendor-assets` fetches them once and the site serves them
itself, so a browser reading a page asks this instance for the type and nobody
else — no third-party request to be told about, nothing to break when a font
host is down or renamed, and pages that render the same on a machine with no
way out to the network at all.

`maak vendor-assets` is the only way these files should change: re-fetching is
running it again, and reading what moved.  The files are committed, because
they are what an instance serves.

| file | what it is | licence |
| --- | --- | --- |
| `juliamono.css` | the `@font-face` rules for JuliaMono, written in this tree, with every address relative | MIT, as part of wikimusic |
| `juliamono-normal-latin.woff2`, `juliamono-bold-latin.woff2` | JuliaMono, regular and bold, in the latin subset | SIL OFL 1.1 |
| `google.css` | the stylesheet the two web families are declared by, fetched from Google and rewritten so that every address is the file beside it | SIL OFL 1.1, as the fonts are |
| `worksans-*.woff2` | Work Sans, in the subsets and slopes the stylesheet names | SIL OFL 1.1 |
| `sourceserif4-*.woff2` | Source Serif 4, in the subsets and slopes the stylesheet names | SIL OFL 1.1 |
| `JuliaMono-OFL.txt` | JuliaMono's own licence text | SIL OFL 1.1 |
| `WorkSans-OFL.txt` | Work Sans's own licence text | SIL OFL 1.1 |
| `SourceSerif4-OFL.txt` | Source Serif 4's own licence text | SIL OFL 1.1 |

The three families cover the three roles the interface needs: Work Sans for
prose, Source Serif 4 for long-form reading in an article's body, and JuliaMono
for a tablature, a chord chart or a snippet of code.

## Where they came from

`maak vendor-assets` runs `resources/assets/fetch.scm`, which is the one place
every address is written down:

- the two web families are asked of `fonts.googleapis.com` for the weights and
  slopes the interface uses, and every face in the answer — served from
  `fonts.gstatic.com` — is downloaded and named after the family, the subset of
  Unicode it carries and its slope.  `google.css` is Google's own stylesheet
  with each of those addresses replaced by the file beside it, so nothing in
  this tree points at a host that is not this instance;
- JuliaMono is not in the Google Fonts catalogue, so it is taken from its own
  project instead, at a release tag rather than a branch: the script names the
  tag it was built against, and the two latin faces the interface sets code in
  are the files it keeps;
- the three licence texts above are fetched from where their authors keep them.

## What is not here

Nothing proprietary: every file above is under the SIL Open Font License 1.1,
and no family is served from a host this instance does not run. The tree used to
carry two faces that were neither -- one proprietary, copied from the author's
static assets, and one fetched from Google -- and neither is fetched, served or
named anywhere now.
