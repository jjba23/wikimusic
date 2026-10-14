# Vendored: the Phosphor icon set

These two files are what the controls of a page wear.  They are *vendored*
rather than linked to: `maak vendor-assets` fetches them once and the site
serves them itself, so a browser reading a page asks this instance for the
glyphs instead of an icon CDN.

| file | what it is | licence |
| --- | --- | --- |
| `phosphor.css` | Phosphor's stylesheet, fetched and pruned to what this tree serves | MIT |
| `Phosphor.woff2` | the regular weight's font | MIT |
| `LICENSE` | Phosphor's licence text | MIT |

## Where they came from

Both files come from the npm package `@phosphor-icons/web`, release **2.1.1** —
the stylesheet from `src/regular/style.css`, the font from `src/regular/`
beside it, both as `cdn.jsdelivr.net` serves them.  `maak vendor-assets` runs
`resources/assets/fetch.scm`, which is where those addresses are written down,
and which does two things to the stylesheet on the way in:

- the `@font-face` rule is left naming one file instead of four.  Phosphor
  publishes the same set as woff2, woff, truetype and svg; only the woff2 is
  fetched, because every browser able to read this interface reads it, and a
  stylesheet that went on naming three files this tree does not have would be a
  stylesheet that does not describe what stands beside it;
- the address it names is made relative, so the pair can be served from this
  instance, a mirror, or a CDN in front of either, without a line of CSS having
  to be told where they went.

`maak vendor-assets` is the only way these files should change: re-fetching is
running it again with the release raised in `fetch.scm`, and reading what moved.
The files are committed, because they are what an instance serves.

## What the licence asks of us

Phosphor Icons is **MIT**, which allows redistribution as long as the copyright
notice and the licence text travel with it: `LICENSE` is that text, and it is
fetched from the project's own repository along with the files.  The glyphs are
unmodified.
