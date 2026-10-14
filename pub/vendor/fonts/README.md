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
| `lucida.css` | the `@font-face` rules for the three Lucida families, written in this tree, with every address relative | AGPL-3.0-or-later, as part of wikimusic |
| `LSANS.woff`, `LSANSI.woff`, `LSANSD.woff`, `LSANSDI.woff` | Lucida Sans, regular and bold, upright and italic | proprietary — see below |
| `LTYPE.woff`, `LTYPEO.woff`, `LTYPEB.woff`, `LTYPEBO.woff` | Lucida Sans Typewriter, regular and bold, upright and oblique | proprietary — see below |
| `l_10646.woff` | Lucida Sans Unicode | proprietary — see below |
| `google.css` | the stylesheet the two web families are declared by, fetched from Google and rewritten so that every address is the file beside it | SIL OFL 1.1, as the fonts are |
| `intelonemono-*.woff2` | Intel One Mono, in the subsets and slopes the stylesheet names | SIL OFL 1.1 |
| `plusjakartasans-*.woff2` | Plus Jakarta Sans, in the subsets and slopes the stylesheet names | SIL OFL 1.1 |
| `IntelOneMono-OFL.txt` | Intel One Mono's own licence text | SIL OFL 1.1 |
| `PlusJakartaSans-OFL.txt` | Plus Jakarta Sans's own licence text | SIL OFL 1.1 |

## Where they came from

`maak vendor-assets` runs `resources/assets/fetch.scm`, which is the one place
every address is written down:

- the two web families are asked of `fonts.googleapis.com` for the weights and
  slopes the interface uses, and every face in the answer — served from
  `fonts.gstatic.com` — is downloaded and named after the family, the subset of
  Unicode it carries and its slope.  `google.css` is Google's own stylesheet
  with each of those addresses replaced by the file beside it, so nothing in
  this tree points at a host that is not this instance;
- the three Lucida families are fetched, one file each, from the author's own
  static assets, which is where they were published;
- the two licence texts above are fetched from where their authors keep them.

## What the licences ask of us

- **Intel One Mono and Plus Jakarta Sans are SIL OFL 1.1, and they are
  unmodified.**  Their copyright notices and licence texts travel beside them,
  which is what the OFL asks for; the reserved font names are not used by
  anything here, and wikimusic's own stylesheet does not rename them.
- **The Lucida families are proprietary typefaces** originally developed by
  Bigelow & Holmes.  They are bundled pre-installed on many systems, and the
  position the project takes on serving the files — fair use, local
  development and non-commercial use, with users responsible for their own
  compliance — is written out in the manual, under *On Lucida fonts*.
