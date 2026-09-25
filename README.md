# encore-slides

Talks and slide decks about [Encore](https://github.com/vbergeron/encore), a
bytecode VM and compiler for running Rocq-extracted programs on
resource-constrained targets. Built with a small Typst template; published
to GitHub Pages.

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
   subdirectory).
2. Add a matching entry to the Slides list in `site/index.html`, in
   `DATE — NAME` format, linking to `decks/YYYY-MM-DD-name.pdf`.

A deck typically opens with `title-slide` and a `qr-slide` pointing back to
this site, and closes with a `qr-slide` pointing to `encore` and
`encore-benchmarks`. See `decks/2026-09-28-lirmm-seminar.typ` for a full
example, including `slide`, `section-slide`, `two-cols`, and `callout`.

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

Edit the `colors`, `font-body`, and `font-mono` values at the top of
`template/lib.typ` to change the theme. `conf` accepts
`aspect-ratio: "16-9"` (default) or `"4-3"`.
