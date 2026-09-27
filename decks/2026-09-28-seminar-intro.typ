#import "/template/lib.typ": *

#show: encore-theme.with(
  title: [From Rocq to Metal],
  subtitle: [Firmware and software applications of formal methods],
  institution: [LIRMM Seminar],
  date: datetime(year: 2026, month: 9, day: 28),
  slug: "2026-09-28-seminar-intro",
)

== This afternoon

#let item(n, title, body) = grid(
  columns: (1.2cm, 1fr),
  column-gutter: 0.4em,
  align: (right + top, left + top),
  text(size: 26pt, weight: "bold", fill: rgb("#B5303B"))[#n],
  [
    #text(size: 20pt, weight: "bold")[#title]
    #v(-0.4em)
    #text(size: 15pt, fill: luma(90))[#body]
  ],
)

#v(0.4em)
#stack(
  spacing: 0.9em,
  item("1", [Formal methods, applied], [
    AI puts pressure on keeping invariants constant and securing evolving
    codebases: how we apply formal methods to industrial goals, and how we
    generate proofs
  ]),
  item("2", [Encore: running Rocq programs on microcontrollers], [
    A compiler and bytecode VM for Rocq programs extracted to Scheme, running
    on bare-metal targets with no operating system
  ]),
  item("3", [Zorya: concolic execution of Go binaries], [
    Not a formal method, but the same constraint-solving machinery: exploring
    the paths not taken at `CBranch` breakpoints to find bugs in real binaries
  ]),
)
