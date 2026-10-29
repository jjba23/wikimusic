# Vendored: alphaTab

These files are what draws and plays back a stored Guitar Pro tab in the
browser.  They are *vendored* rather than linked to: `maak alphatab` fetches
them once and the site serves them itself, so a wikimusic instance reaches no
CDN and works with no network of its own.

`maak alphatab` is the only way these files should change — re-fetching a newer
release is running it again with `alphatab-version` in `maak.scm` raised, and
reading what moved.  The files are committed so that a checkout builds the same
site without a download.

Release **1.8.4**, npm package `@coderline/alphatab`, from
`https://cdn.jsdelivr.net/npm/@coderline/alphatab@1.8.4/dist` (and the project's
`LICENSE` from `https://raw.githubusercontent.com/CoderLine/alphaTab/v1.8.4/LICENSE`).

| file | what it is | licence |
| --- | --- | --- |
| `alphaTab.min.js` | alphaTab's browser build; it also carries the web worker a score is rendered in | MPL-2.0 |
| `font/Bravura.woff2` | Bravura, the music font tablature is drawn with | SIL OFL 1.1 |
| `font/Bravura-OFL.txt` | Bravura's own licence text | SIL OFL 1.1 |
| `soundfont/sonivox.sf2` | the Sonivox SoundFont a tab is synthesised with | Apache-2.0 |
| `soundfont/LICENSE` | the SoundFont's own licence text | Apache-2.0 |
| `LICENSE` | alphaTab's licence text | MPL-2.0 |

## What the licences ask of us

- **alphaTab is MPL-2.0, and it is unmodified.**  Its files keep their notices,
  and the source of the covered code is the upstream project at the pinned tag:
  <https://github.com/CoderLine/alphaTab/tree/v1.8.4>.  Anyone who wants the
  source of what is served here is pointed there rather than being given a
  minified file and nothing else.  MPL-2.0 is compatible with wikimusic's MIT
  licence through MPL section 3.3, which lets a larger work carry terms of its
  own choice.
- **The SoundFont is Apache-2.0**, which allows redistribution: its licence
  text and its Sonic Network Inc. notice travel beside the file.
- **Bravura is SIL OFL 1.1**; its licence text travels beside it.

If a file here is ever patched by hand, say so here and in the file: MPL-2.0
requires a modified file to say that it was modified.
