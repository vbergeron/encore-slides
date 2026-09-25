// encore-slides — a small, dependency-free Typst slide template.

#let colors = (
  background: rgb("#0b0f1a"),
  foreground: rgb("#f5f6f8"),
  muted: rgb("#8b93a7"),
  accent: rgb("#5ee6c8"),
  accent-dim: rgb("#1f5a4f"),
  panel: rgb("#131826"),
)

// Prefer Inter / JetBrains Mono when installed, fall back to fonts that
// ship with most systems so the template renders cleanly out of the box.
#let font-body = ("Inter", "Segoe UI", "Arial")
#let font-heading = font-body
#let font-mono = ("JetBrains Mono", "Consolas", "DejaVu Sans Mono")

// Page counter starts at 1 on the first content slide (title slide is 0).
#let slide-counter = counter("encore-slide")

// ---- document setup --------------------------------------------------

#let conf(
  title: "",
  subtitle: none,
  author: none,
  date: none,
  aspect-ratio: "16-9",
  body,
) = {
  let (w, h) = if aspect-ratio == "4-3" { (10in, 7.5in) } else { (13.333in, 7.5in) }

  set page(
    width: w,
    height: h,
    margin: 0pt,
    fill: colors.background,
  )
  set text(font: font-body, size: 20pt, fill: colors.foreground)
  set par(justify: false, leading: 0.65em)

  show heading: set text(font: font-heading, fill: colors.foreground, weight: "bold")
  show heading.where(level: 1): set text(size: 34pt)
  show heading.where(level: 2): set text(size: 24pt, fill: colors.accent)
  show raw: set text(font: font-mono, size: 0.85em)
  show link: set text(fill: colors.accent)

  set document(title: title, author: if author != none { (author,) } else { () })

  body
}

// ---- footer / page furniture ------------------------------------------

#let footer(title: none, show-number: true) = {
  place(
    bottom + left,
    dx: 0.9in,
    dy: -0.55in,
    text(size: 11pt, fill: colors.muted)[#title],
  )
  if show-number {
    place(
      bottom + right,
      dx: -0.9in,
      dy: -0.55in,
      text(size: 11pt, fill: colors.muted)[#context slide-counter.display()],
    )
  }
  place(
    bottom + left,
    dx: 0.9in,
    dy: -0.4in,
    line(length: 100% - 1.8in, stroke: 0.5pt + colors.accent-dim),
  )
}

// ---- title slide --------------------------------------------------------

#let title-slide(title: "", subtitle: none, author: none, date: none) = {
  set page(fill: gradient.linear(colors.background, colors.panel, angle: 35deg))
  place(
    top + left,
    dx: 0.9in,
    dy: 0.9in,
    rect(width: 0.5in, height: 4pt, fill: colors.accent),
  )
  place(
    center + horizon,
    dx: -0.1in,
    block(width: 100% - 1.8in)[
      #text(size: 44pt, weight: "bold", fill: colors.foreground)[#title]
      #if subtitle != none [
        #v(0.3em)
        #text(size: 22pt, fill: colors.muted)[#subtitle]
      ]
      #v(1em)
      #if author != none or date != none [
        #line(length: 2in, stroke: 0.5pt + colors.accent-dim)
        #v(0.5em)
        #text(size: 14pt, fill: colors.muted)[
          #if author != none [#author]
          #if author != none and date != none [ #sym.dot.c ]
          #if date != none [#date]
        ]
      ]
    ],
  )
  pagebreak(weak: true)
}

// ---- section divider ------------------------------------------------------

#let section-slide(title, number: none) = {
  slide-counter.step()
  set page(fill: colors.panel)
  place(
    center + horizon,
    block(width: 100% - 1.8in)[
      #if number != none [
        #text(size: 16pt, fill: colors.accent, weight: "bold")[#number]
        #v(0.2em)
      ]
      #text(size: 36pt, weight: "bold", fill: colors.foreground)[#title]
    ],
  )
  pagebreak(weak: true)
}

// ---- content slide --------------------------------------------------------

#let slide(title: none, footer-title: none, body) = {
  slide-counter.step()
  block(width: 100%, height: 100%, inset: (x: 0.9in, top: 0.75in, bottom: 0.9in))[
    #if title != none [
      == #title
      #v(0.4em)
    ]
    #body
  ]
  footer(title: footer-title)
  pagebreak(weak: true)
}

// ---- small helpers used inside slide bodies --------------------------------

#let accent(body) = text(fill: colors.accent, body)

#let callout(title: none, body) = block(
  width: 100%,
  inset: 14pt,
  radius: 6pt,
  fill: colors.panel,
  stroke: 0.5pt + colors.accent-dim,
)[
  #if title != none [
    #text(fill: colors.accent, weight: "bold")[#title]
    #v(0.3em)
  ]
  #body
]

#let two-cols(left, right, ratio: 1fr) = grid(
  columns: (ratio, ratio),
  gutter: 32pt,
  left, right,
)
