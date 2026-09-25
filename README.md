# encore-slides

Talks and slide decks about [Encore](https://github.com/vbergeron/encore), a
bytecode VM and compiler for running Rocq-extracted programs on
resource-constrained targets. Built with [Touying](https://typst-doc-cn.github.io/typst-touying-doc/)'s
`metropolis` theme (same coral theme as
[data-processing-at-scale](https://github.com/vbergeron/data-processing-at-scale));
published to GitHub Pages.

**Site:** https://vbergeron.github.io/encore-slides/

## Layout

```
template/lib.typ    the template: theme, page setup, slide + QR functions
decks/               one dated .typ file per talk
site/index.html      the GitHub Pages site listing every deck
```

## Adding a talk

1. Add `decks/YYYY-MM-DD-name.typ`, importing the template with
   `#import "/template/lib.typ": *` (root-absolute, since decks live in a
   subdirectory), then `#show: encore-theme.with(title: [...], subtitle: [...],
   slug: "YYYY-MM-DD-name", links: ((url: "...", label: "..."), ..))`.
2. Write slides as plain Touying content — each `== Heading` starts a new
   slide.
3. Add a matching entry to the Slides list in `site/index.html`, in
   `DATE — NAME` format, linking to `decks/YYYY-MM-DD-name.pdf`.

`encore-theme` opens with a title slide and (if `slug` is set) a QR code
back to this site, and closes with a QR-code slide for each entry in
`links`. See `decks/2026-09-28-lirmm-seminar.typ` for a full example.

Avoid putting an em dash directly in front of a raw/code span (`` — `#foo` ``)
— Touying misreads it as a pause marker and silently splits the slide.

### Building

With [Typst](https://typst.app) and [just](https://github.com/casey/just)
installed:

```sh
just build                          # compile the default deck
just build decks/some-other.typ     # compile a specific deck
just watch                          # live preview while editing
just build-all                      # compile every deck into site/decks/
```

Or plain Typst — decks import the template with a root-absolute path, so
`--root .` is required:

```sh
typst compile --root . decks/2026-09-28-lirmm-seminar.typ out.pdf
```

## Publishing

On every push to `main`, GitHub Actions compiles every deck under `decks/`
into `site/decks/*.pdf` and deploys `site/` to GitHub Pages.

## Customizing

`template/lib.typ` configures the `metropolis` theme's colors
(`primary`/`primary-light`) and `base-url`. See the
[Touying docs](https://typst-doc-cn.github.io/typst-touying-doc/) for the
full theming API.
