#import "/template/lib.typ": *

#let site-url = "https://vbergeron.github.io/encore-slides/"
#let encore-url = "https://github.com/vbergeron/encore"
#let benchmarks-url = "https://github.com/vbergeron/encore-benchmarks"

#show: conf.with(
  title: "Encore",
  subtitle: "A bytecode VM and compiler for Rocq-extracted programs",
  author: "Valentin Bergeron",
  date: "LIRMM Seminar · September 28, 2026",
)

#title-slide(
  title: "Encore",
  subtitle: "A bytecode VM and compiler for Rocq-extracted programs",
  author: "Valentin Bergeron",
  date: "LIRMM Seminar · September 28, 2026",
)

#qr-slide(title: "Follow along", footer-title: "Encore", (
  (url: site-url, label: "Slides + links"),
))

#section-slide("Why Encore?", number: "01")

#slide(title: "The problem", footer-title: "Encore")[
  Rocq's extraction mechanism produces correct-by-construction Scheme code —
  but running it anywhere below a full Lisp runtime has historically meant a
  large porting effort.

  #v(1em)
  #callout(title: "Encore fills that gap")[
    A bytecode interpreter with a built-in GC that compiles to a `no_std`
    Rust crate and links into firmware with a fixed heap budget.
  ]
]

#slide(title: "The name", footer-title: "Encore")[
  The name comes from the VM's single calling opcode: `ENCORE`.

  - Every function call sets the callee and continuation registers and jumps
  - There is no call stack
  - In French, #accent[*encore*] means #accent[*again*], #accent[*still*], #accent[*more*]
]

#section-slide("How it works", number: "02")

#slide(title: "Pipeline", footer-title: "Encore")[
  ```
  Rocq proof / program
      │  Extraction (Scheme)
      ▼
  extracted .scm
      │  encore compile scheme
      ▼
    .encr bytecode
      │  encore_vm  (#![no_std])
      ▼
    Value
  ```
]

#slide(title: "encore_vm", footer-title: "Encore")[
  The VM requires only a fixed arena — `#![no_std]`, brings its own GC.

  - Packed 32-bit values: closures, constructors, integers, byte strings
  - 256-register file, bump-allocation heap arena
  - Mark-compact garbage collector
  - Single calling convention: `ENCORE` opcode, set callee and continuation,
    jump without returning
]

#slide(title: "Compiler pipeline", footer-title: "Encore")[
  #two-cols[
    - *DS uncurry* — flattens curried lambdas
    - *DSI resolve* — named binders to de Bruijn indices
    - *CPS transform* — continuation-passing style
  ][
    - *CPS optimizer* — inlining, hoisting, CSE, contification
    - *ASM resolve* — closure conversion, register assignment
    - *ASM peephole* + *ASM emit* — ENCR binary output
  ]
]

#section-slide("Try it", number: "03")

#slide(title: "Quick start", footer-title: "Encore")[
  ```sh
  encore compile scheme extracted.scm --out program.encr
  encore run program.encr
  ```

  #v(1em)
  #callout(title: "Also on the CLI")[
    `encore disasm` for an interactive bytecode inspector,
    `encore compile fleche` for Fleche sources.
  ]
]

#qr-slide(title: "Go further", footer-title: "Encore", (
  (url: encore-url, label: "encore"),
  (url: benchmarks-url, label: "encore-benchmarks"),
))
