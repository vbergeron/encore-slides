// encore-slides — same theme as vbergeron/data-processing-at-scale:
// touying's metropolis theme, coral accent, tiaoma QR codes.

#import "@preview/touying:0.6.3": *
#import themes.metropolis: *
#import "@preview/tiaoma:0.3.0"

#let base-url = "https://vbergeron.github.io/encore-slides/"

#let hero(body) = align(center + horizon, text(size: 28pt, body))

#let qr-card(url, label: none, width: 4cm) = align(center)[
  #tiaoma.qrcode(url, width: width)
  #v(0.4em)
  #if label != none [
    #text(size: 12pt, weight: "bold")[#label]
    #v(0.2em)
  ]
  #text(size: 10pt, fill: luma(120))[#link(url)[#url]]
]

#let encore-theme(
  title: [],
  subtitle: [],
  institution: [Encore],
  date: datetime.today(),
  slug: "",
  links: (),
  body,
) = {
  show: metropolis-theme.with(
    aspect-ratio: "16-9",
    footer: self => self.info.institution,
    config-colors(
      primary: rgb("#B5303B"),
      primary-light: rgb("#d4777e"),
    ),
    config-info(
      title: title,
      subtitle: subtitle,
      date: date,
      institution: institution,
    ),
  )
  title-slide()

  if slug != "" {
    slide[
      #align(center + horizon)[
        #qr-card(base-url, label: "Follow along", width: 5cm)
      ]
    ]
  }

  body

  if links.len() > 0 {
    slide[
      #align(center + horizon)[
        #text(size: 24pt, weight: "bold")[Go further]
        #v(1em)
        #grid(
          columns: links.len() * (1fr,),
          column-gutter: 2cm,
          align: center,
          ..links.map(l => qr-card(l.url, label: l.label))
        )
      ]
    ]
  }
}
