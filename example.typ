#import "template/lib.typ": *

#let site-url = "https://vbergeron.github.io/encore-slides/"
#let encore-url = "https://github.com/vbergeron/encore"
#let benchmarks-url = "https://github.com/vbergeron/encore-benchmarks"

#show: conf.with(
  title: "Encore Slides",
  subtitle: "A minimal Typst deck template",
  author: "Valentin Bergeron",
  date: "September 2026",
)

#title-slide(
  title: "Encore Slides",
  subtitle: "A minimal Typst deck template",
  author: "Valentin Bergeron",
  date: "September 2026",
)

#qr-slide(title: "Follow along", footer-title: "Encore Slides", (
  (url: site-url, label: "Slides + links"),
))

#section-slide("Getting started", number: "01")

#slide(title: "What this is", footer-title: "Encore Slides")[
  A small, dependency-free Typst template for building slide decks.

  - Pure Typst — no external packages required
  - 16:9 by default, 4:3 available via `aspect-ratio: "4-3"`
  - Dark theme with a single accent color
  - Title, section, and content slide layouts

  #v(1em)
  #callout(title: "Tip")[
    Run `just watch example.typ` to preview changes live while you edit.
  ]
]

#slide(title: "Two columns", footer-title: "Encore Slides")[
  #two-cols[
    == Left
    Use `two-cols` for side-by-side comparisons, before/after shots, or
    a diagram next to bullet points.
  ][
    == Right
    #accent[Accent text] draws attention to key terms without a full
    callout block.
  ]
]

#slide(title: "Code", footer-title: "Encore Slides")[
  Fenced code blocks use the template's monospace font automatically.

  ```rust
  fn main() {
      println!("hello from encore-slides");
  }
  ```
]

#section-slide("Wrapping up", number: "02")

#slide(title: "Next steps", footer-title: "Encore Slides")[
  + Duplicate `example.typ` for your own deck
  + Adjust the palette in `template/lib.typ`
  + Export with `just build example.typ`
]

#qr-slide(title: "Go further", footer-title: "Encore Slides", (
  (url: encore-url, label: "encore"),
  (url: benchmarks-url, label: "encore-benchmarks"),
))
