#import "/template/lib.typ": *
#import "/template/bench.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#show: encore-theme.with(
  title: [Encore],
  subtitle: [From Rocq to Metal: formally verified microcontroller firmware],
  institution: [Encore — LIRMM Seminar],
  date: datetime(year: 2026, month: 9, day: 28),
  slug: "2026-09-28-lirmm-seminar",
  links: (
    (url: "https://github.com/vbergeron/encore", label: "encore"),
    (url: "https://github.com/vbergeron/encore-benchmarks", label: "encore-benchmarks"),
  ),
)

#let simple-table(columns, size: 15pt, ..cells) = {
  set text(size: size)
  show table.cell.where(y: 0): set text(weight: "bold")
  table(
    columns: columns,
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 8pt, y: 6pt),
    ..cells,
  )
}

#let logo(file, height: 2cm) = image("/assets/logos/" + file, height: height)
// An alternative's slide: its logo in the top-right corner, then the points.
#let logo-slide(file, body, height: 1.6cm) = {
  place(top + right, dy: -0.4cm, logo(file, height: height))
  block(width: 78%, body)
}

= Introduction

== Why verify firmware logic

- Generated code is getting cheap: *more code to review*, same assurance level
- seL4 showed machine-checked correctness at the systems level; firmware
  wants the same rigour
- Formal specifications scale: a generated implementation is checked against
  theorem statements
- But extracted code needs a runtime, and the usual answer is to *translate
  the specification by hand* into the host language, weakening the link to
  the proof

= Making firmware provable

== Firmware as a state transition

#text(size: 18pt)[Push the pure frontier as far as it goes: *maximise the part Rocq can prove*.]
#v(0.2em)
#align(center, text(size: 22pt)[`step : State × Event → State × list Effect`])
#v(0.3em)
- *State*: the application's; *Event*: from the device (APDU, button);
  *Effect*: a description of what to do, interpreted by the host
- Copy instead of mutate, describe effects instead of performing them
- The *event poller* and *effect interpreter* are the unverified boundary:
  its size does not grow with the application
- Hashes, CRCs, field arithmetic: admitted as axioms, provided as host callbacks

== What is proved, what is trusted

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  [
    *Proved in Rocq*
    - the `step` function and its lemmas
    - grows with the application
  ],
  [
    *Trusted*
    - Rocq kernel and extraction
    - the compiler and VM that run it
    - the Rust compiler
    - host callbacks for admitted axioms
    - event poller and effect interpreter
  ],
)
#v(0.5em)
#text(size: 17pt, fill: muted)[The trusted boundary changes only when new hardware actions, externs or primitives are added. \ Left to find: a way to run the proved `step` on a 50 KB chip.]

= Why did we build Encore?

== The target: ST33 secure elements

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  simple-table((auto, 1fr, 1fr),
    [], [ST33K1M5], [ST33J2M0],
    [ISA], [ARM + Thumb-2], [ARM + Thumb-2],
    [Flash], [1.5 MB], [2 MB],
    [RAM], [64 KB], [*50 KB*],
    [Clock], [70 MHz], [60 MHz],
    [Cache], [2 KB], [none],
  ),
  [
    - *50 KB of RAM* is the binding constraint
    - No libc, no libm, no Rust `std`
    - Applications often ship with *no runtime at all*
  ],
)

== Extraction paths

#simple-table((auto, 1fr, auto, auto, auto),
  [Path], [Runtime needs], [`no_std`], [Cortex-M], [Verified compilation],
  [*Lean 4*], [C++ library, ref-counting + cycle GC, tasks, hosted IO], [no], [no], [no],
  [*Rocq → OCaml*], [generational GC, libc/libm], [no], [no], [no],
  [*CertiRocq*], [GC-aware heap; Peano `nat`, no machine arithmetic], [partial], [partial], [Gallina → Clight, largely],
  [*Rocq → Scheme*], [a small runtime, to find or to build], [yes], [yes], [no],
)
#v(0.3em)
#text(size: 15pt, fill: muted)[
  Every path but CertiRocq trusts its extraction and compiler: the proof
  covers the Gallina, not the code that runs. Verified compilers (CompCert,
  CakeML) show the stronger story is possible.
]

== Lean 4

#logo-slide("lean.png", height: 2.2cm)[
  - Mature native code generation, active proof ecosystem
  - Its runtime assumes a *C++ library*, *reference counting with cycle
    collection*, tasks and hosted IO
  - Targets smaller than a Raspberry Pi need substantial runtime work; the
    ESP32-C3 port needed a patched libc++/picolibc, on *384 KB of RAM*
  - Bare metal is not on the Lean FRO roadmap
]

== Rocq extraction to OCaml

#logo-slide("ocaml.svg")[
  - Rocq's most mature extraction target
  - The OCaml runtime needs a *generational GC*, *libc and libm*, and
    native-code conventions that do not match Cortex-M object formats
  - A native OCaml port to a microcontroller needed assembly patching, a
    custom linker script and standard-library stubs, on a larger target
  - *OMicroB*, an OCaml VM for microcontrollers, supports AVR and PIC32; its
    Cortex-M0 port is unmerged, and the ST33 needs full Thumb-2
]

== CertiRocq

#logo-slide("certirocq.svg")[
  - The most principled path: Gallina to Clight through a *largely verified*
    compiler chain, then C
  - Generated code allocates, and correctness is stated against a GC-aware
    heap: a new runtime means *proving a new collector*, or bounded allocation
  - No standard `nat` to machine integer mapping: arithmetic stays in *Peano*
  - To run on the target at all, the paper patches its runtime: static
    nursery, and a collection *aborts the program*
]

== Rocq extraction to Scheme

#logo-slide("scheme.png", height: 2cm)[
  - Less mature than OCaml extraction, but Scheme has *compact semantics* and
    *no mandatory hosted runtime*
  - Small Scheme systems fit microcontrollers: PICOBIT, Ribbit (a VM,
    compiler and REPL in 4 KB)
  - The extracted code is a narrow subset: curried definitions and
    applications, constructor matching, from Rocq's `macros_extr.scm`
  - Candidates on the target: *Chibi*, *Ribbit*, then our own
]

== From Rocq to Scheme

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.8cm,
  align: top,
  [
    #text(size: 14pt, fill: muted)[Gallina]
    #v(-0.3em)
    #text(size: 14pt)[
```coq
Fixpoint digits_eqb (a b : list nat) : bool :=
  match a, b with
  | [], [] => true
  | x :: a', y :: b' =>
      if x =? y then digits_eqb a' b'
      else false
  | _, _ => false
  end.
```
    ]
  ],
  [
    #text(size: 14pt, fill: muted)[Extracted Scheme]
    #v(-0.3em)
    #text(size: 14pt)[
```scheme
(define digits_eqb (lambdas (a b)
  (match a
     ((Nil) (match b
               ((Nil) `(True))
               ((Cons _ _) `(False))))
     ((Cons x a~)
       (match b
          ((Nil) `(False))
          ((Cons y b~)
            (match (@ eqb x y)
               ((True) (@ digits_eqb a~ b~))
               ((False) `(False)))))))))
```
    ]
  ],
)
#v(0.2em)
#text(size: 15pt)[
  Curried functions (`lambdas`, `@`), constructors as tagged lists (#raw("`(Cons ,x ,l)")),
  `match` on the tag. Even `bool` is a constructor: #raw("`(True)").
]

== macros_extr.scm

Extracted code starts with `(load "macros_extr.scm")`: three macros, shipped with Rocq's Scheme extraction.

#grid(
  columns: (1.1fr, 1fr),
  column-gutter: 0.8cm,
  align: top,
  text(size: 13pt)[
    #text(size: 13pt, fill: muted, font: "Libertinus Serif")[In essence (simplified):]
```scheme
(define-syntax lambdas
  (syntax-rules ()
    ((lambdas () e) e)
    ((lambdas (x) e) (lambda (x) e))
    ((lambdas (x y ...) e)
     (lambda (x) (lambdas (y ...) e)))))

(define-syntax @
  (syntax-rules ()
    ((@ e) e)
    ((@ f e) (f e))
    ((@ f e1 e2 ...) (@ (f e1) e2 ...))))

;; match: compare the tag (car) of a
;; tagged list, bind its fields
```
  ],
  [
    #set text(size: 16pt)
    - `lambdas`: a curried multi-argument function
    - `@`: curried application, one argument at a time
    - `match`: dispatch on a constructor's tag
    - Constructors are plain quasiquoted lists
    #v(0.3em)
    *Encore makes them core primitives* instead of supporting `define-syntax`:
    `@` becomes a saturated call after uncurrying, `match` the `MATCH` opcode,
    a constructor the `PACK` opcode. Its only addition: `extern`, for host functions.
  ],
)

== Chibi Scheme

#logo-slide("chibi.png", height: 2.2cm)[
  - A small, embeddable *interpreter* written in C
  - On the target: the C runtime, about 50 files, cross-compiled with custom
    POSIX stubs
  - The extracted Scheme is embedded as a C string literal, *loaded and
    evaluated on every boot*
  - #text(fill: accent, weight: "bold")[✗ The binary exceeds the 256 KB flash budget]
]

== Ribbit

#logo-slide("ribbit.png", height: 1.4cm)[
  - A compact Scheme *VM*: the compiler `rsc.scm` emits bytecode and a minimal VM in C
  - On the target: generated from `build.rs`, patched for a static heap and a
    semihosting shim, cross-compiled for Cortex-M35P
  - #text(fill: rgb("#2e7d32"), weight: "bold")[✓ The binary fits]
  - #text(fill: accent, weight: "bold")[✗ No `quasiquote`: it cannot compile the extracted code.]
    The test ran hand-written Scheme: the verified logic never ran on the device
]

== The key insight: CPS

Rocq-extracted Scheme is *heavily curried* and already close to CPS form.

- The CPS rewrite removes the call stack *semantically*; a register VM
  removes it *physically*: no hidden control flow, no frames
- Every intermediate value is named: register allocation is natural
- GC roots are trivial: every live register is a root, and CPS keeps them
  contiguous, so no stack scanning

= Encore: compiler and VM

== The VM

The VM requires only a fixed arena: `#![no_std]`, brings its own GC.

- Packed 32-bit values: closures, constructors, integers, byte strings
- 256-register file, bump-allocation heap arena
- Mark-compact garbage collector
- Single calling convention: `ENCORE` opcode, set callee and continuation,
  jump without returning

== VM architecture

// A row of labelled cells, for the register file and the arena.
#let strip(..cells) = grid(
  columns: cells.pos().map(c => c.at(1)),
  stroke: 0.6pt + luma(90),
  inset: (x: 5pt, y: 7pt),
  align: center + horizon,
  ..cells.pos().map(c => grid.cell(fill: c.at(2, default: none), c.at(0))),
)
#let part(title, body, note: none) = block[
  #text(size: 16pt, weight: "bold")[#title]
  #v(-0.5em)
  #body
  #if note != none { v(-0.5em); text(size: 13pt, fill: muted, note) }
]
#let op(body) = text(size: 13pt, raw(body))

#align(center + horizon, text(size: 15pt, diagram(
  spacing: (2.2cm, 0.9cm),
  node-stroke: 0.8pt + luma(60),
  node-inset: 8pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  node((0, 1), name: <code>, part([Bytecode (flash)], [code · arity table], note: [read-only, `u16` code pointers])),
  node((1, 0), name: <regs>, part([Register file: 256 values], strip(
    ([`SELF`], auto, accent.lighten(80%)),
    ([`CONT`], auto, accent.lighten(80%)),
    ([`A1`–`A8`], auto),
    ([`X01` …], 2.2cm),
    ([`NULL`], auto, luma(230)),
  ), note: [no stack, no frames])),
  node((1, 1), name: <vm>, fill: accent, stroke: none, inset: 12pt,
    text(fill: white)[#text(size: 20pt, weight: "bold")[Encore VM] \ #text(size: 13pt)[fetch · decode · dispatch]]),
  node((2, 1), name: <host>, part([Rust host], [`extern_fns[32]` \ `fn(Value) -> Value`])),
  node((1, 2), name: <arena>, part([Arena: one fixed `&mut [Value]` (RAM)], strip(
    ([heap #h(1fr) `hp` →], 4.4cm, accent.lighten(80%)),
    ([free], 3cm),
    ([globals], auto, luma(230)),
  ), note: [bump allocation, no `malloc`])),
  node((2, 2), name: <gc>, part([Mark-compact GC], [roots: registers + globals], note: [in place, on allocation failure])),

  edge(<code>, <vm>, "-|>", label: text(size: 13pt)[load], label-side: left),
  edge(<vm>, <regs>, "<|-|>", label: op("MOV · ENCORE"), label-side: right),
  edge(<vm>, <host>, "<|-|>", label: op("EXTERN"), label-side: left),
  edge(<vm>, <arena>, "-|>", label: op("PACK · CLOSURE"), label-side: left, shift: 0.35cm),
  edge(<arena>, <vm>, "-|>", label: op("FIELD · CAPTURE · GLOBAL"), label-side: left, shift: 0.35cm),
  edge(<vm>, <gc>, "-|>", label: text(size: 13pt)[heap full], label-side: left),
  edge(<gc>, <arena>, "-|>", label: text(size: 13pt)[compacts], label-side: right),
)))
#v(0.6em)
#align(center, text(size: 16pt, fill: muted)[
  All VM state is 256 registers and one arena the host hands over: no stack, no `malloc`, no OS.
])

== Value representation

// A 32-bit word as a strip of fields: (body, bits, fill).
#let bit-w = 0.4cm
#let heap-c = accent.lighten(80%)
#let code-c = rgb("#dce8f4")
#let num-c = rgb("#f6eed3")
#let typ-c = luma(225)
#let bits(..fields) = grid(
  columns: fields.pos().map(f => f.at(1) * bit-w),
  stroke: 0.6pt + luma(90),
  inset: (x: 3pt, y: 5pt),
  align: center + horizon,
  ..fields.pos().map(f => grid.cell(fill: f.at(2, default: none), text(size: 12pt, f.at(0)))),
)
#let typ(n) = ([#raw(n)], 8, typ-c)
#let none-f = (text(fill: muted)[unused], 8)
#let group(body) = grid.cell(colspan: 2, align: left, inset: (top: 6pt, bottom: 1pt), text(size: 13pt, weight: "bold", fill: accent, body))

#align(center, text(size: 15pt, grid(
  columns: (auto, 32 * bit-w),
  column-gutter: 0.5cm,
  row-gutter: 5pt,
  align: (right + horizon, center + horizon),
  [], grid(
    columns: (bit-w,) * 32,
    stroke: 0.4pt + luma(190),
    fill: luma(242),
    inset: (x: 0pt, y: 4pt),
    align: center + horizon,
    ..range(31, -1, step: -1).map(i => text(size: 8pt, fill: muted, str(i))),
  ),

  group[Values: registers, globals, fields],
  [Integer], bits(([signed integer, 24 bits], 24, num-c), typ("0x04")),
  [Function], bits(([code address], 16, code-c), none-f, typ("0x05")),
  [Closure], bits(([heap address], 16, heap-c), none-f, typ("0x00")),
  [Constructor], bits(([heap address · `NULL` if nullary], 16, heap-c), ([tag], 8), typ("0x01")),
  [Bytes], bits(([heap address], 16, heap-c), none-f, typ("0x06")),

  group[Headers: first words of a heap object],
  [GC header], bits(([forwarding address], 16, heap-c), ([mark · size:7], 8, num-c), typ("0x03")),
  [Closure header], bits(([code address], 16, code-c), ([env_len], 8, num-c), typ("0x02")),
  [Bytes header], bits(([byte length, 24 bits], 24, num-c), typ("0x07")),
)))
#v(0.2em)
#align(center, text(size: 14pt, fill: muted)[
  Integers, functions and nullary constructors never allocate. \ Heap addresses are 16-bit word indices: at most 64 Ki words of arena.
])

== Heap objects

// One heap word: address, raw hex, decoded meaning.
#let word(pos, addr, hex, val, fill: none) = node(pos, name: label("w" + addr),
  width: 2.5cm, height: 1.65cm, inset: 3pt, corner-radius: 0pt, fill: fill,
  stack(spacing: 5pt,
    text(size: 9pt, fill: muted, raw(addr)),
    text(size: 10pt, raw(hex)),
    text(size: 12pt, val),
  ),
)
// The value that refers to an object, as held in a register.
#let root(y, name, reg, hex, val) = node((0, y), name: label("v" + str(y)), stroke: none, inset: 4pt,
  align(right, stack(spacing: 4pt,
    text(size: 15pt, weight: "bold", name),
    text(size: 11pt)[#raw(reg) = #raw(hex)],
    text(size: 11pt, fill: muted, val),
  )),
)
#let o1 = rgb("#dce8f4")
#let o2 = accent.lighten(85%)

#align(center, diagram(
  spacing: (0pt, 1.3cm),
  node-stroke: 0.6pt + luma(90),
  edge-stroke: 0.8pt + accent,
  mark-scale: 80%,

  root(0, [pair `(3, 4)`], "A1", "0x0020_0201", [Ctor · tag 2 · `@0020`]),
  word((2, 0), "0020", "0x0000_0303", [GC hdr · 3], fill: o1),
  word((3, 0), "0021", "0x0000_0304", [Int 3], fill: o1),
  word((4, 0), "0022", "0x0000_0404", [Int 4], fill: o1),

  root(1, [list `[1; 2]`], "A2", "0x0026_0101", [Cons · tag 1 · `@0026`]),
  word((2, 1), "0023", "0x0000_0303", [GC hdr · 3], fill: o1),
  word((3, 1), "0024", "0x0000_0204", [Int 2], fill: o1),
  word((4, 1), "0025", "0xFFFF_0001", [Nil · `NULL`], fill: o1),
  word((5, 1), "0026", "0x0000_0303", [GC hdr · 3], fill: o2),
  word((6, 1), "0027", "0x0000_0104", [Int 1], fill: o2),
  word((7, 1), "0028", "0x0023_0101", [Cons `@0023`], fill: o2),

  node((8, 1), stroke: none, inset: 10pt, align(left, text(size: 12pt, fill: accent)[
    Pointers only go *down*: \ no mutation, so a field \ always holds an older object
  ])),

  root(2, [bytes `"hello"`], "A3", "0x0029_0006", [Bytes · `@0029`]),
  word((2, 2), "0029", "0x0000_0403", [GC hdr · 4], fill: o1),
  word((3, 2), "002A", "0x0000_0507", [Bytes hdr · 5], fill: o1),
  word((4, 2), "002B", "0x6C6C_6568", [`h e l l`], fill: o1),
  word((5, 2), "002C", "0x0000_006F", [`o` + pad], fill: o1),

  node((1, 0), width: 0.6cm, stroke: none),
  edge(<v0>, <w0020>, "-|>"),
  edge(<v1>, (1, 1), (1, 0.5), (5, 0.5), <w0026>, "-|>", corner-radius: 6pt),
  edge((7, 1.28), (2, 1.28), "-|>", bend: 22deg),
  edge(<v2>, <w0029>, "-|>"),
))
#v(0.2em)
#align(center, text(size: 14pt, fill: muted)[
  A value points at its object's GC header; `FIELD i` reads word `addr + 1 + i`.
  Byte strings pack 4 bytes per word, little-endian. Addresses and tags are illustrative.
])

== Opcodes

#let opgroup(body) = table.cell(colspan: 2, inset: (top: 7pt, bottom: 2pt, x: 0pt),
  text(size: 15pt, weight: "bold", fill: accent, body))
#let opc(name, args) = [#raw(name) #text(size: 12pt, fill: muted, raw(args))]

#align(center + horizon, box({
  set text(size: 16pt)
  set align(left)
  table(
      columns: (auto, auto),
      stroke: none,
      inset: (x: 6pt, y: 4pt),
      opgroup[Control],
      opc("ENCORE", "rf rk"), [`SELF ← rf`, `CONT ← rk`, jump: *the only call*],
      opc("FIN", "rs"), [halt, hand `rs` back to the host],
      opgroup[Data movement],
      opc("MOV", "rd rs"), [copy; stages arguments in `A1`–`A8`],
      opc("GLOBAL · CAPTURE", ""), [read a global, or a slot of `SELF`],
      opgroup[Allocation],
      opc("PACK", "rd tag f…"), [build a constructor (nullary: no allocation)],
      opc("CLOSURE", "rd @code c…"), [capture registers into a heap closure],
      opgroup[Destructuring],
      opc("BRANCH · MATCH", ""), [jump on a constructor tag],
      opc("UNPACK", "rd tag rs"), [fields into consecutive registers],
      opgroup[Primitives and host],
      opc("ADD · EQ · LT …", ""), [24-bit integers; overflow traps],
      opc("BYTES_*", ""), [length, get, concat, slice, equal],
      opc("EXTERN", "rd ra slot"), [call a host function],
    )
}))

== Fleche: a test language

#grid(
  columns: (1.2fr, 1fr),
  column-gutter: 0.8cm,
  align: horizon,
  block(fill: luma(242), inset: 10pt, radius: 3pt, width: 100%, text(size: 13pt)[
```
data Leaf | Node(l, v, r)

let rec insert x = t ->
  match t
  | Leaf -> Node(Leaf, x, Leaf)
  | Node(l, v, r) ->
    let less = builtin lt x v in
    match less
    | True -> Node(insert x l, v, r)
    | _    -> Node(l, v, insert x r)
    end
  end

let rec sum t =
  if Node(l, v, r) = t
  then builtin add v (builtin add (sum l) (sum r))
  else 0

let main = sum (insert 8 (insert 2 (insert 5 Leaf)))
```
  ]),
  [
    #set text(size: 16pt)
    A small direct-style language, parsed straight to DS:
    - `data` declarations: constructors and arities
    - Curried lambdas `x -> e`, `let rec`, application
    - Exhaustive `match`, `_` wildcard, `if` on a pattern
    - `builtin` primitives, string literals, `let extern` host calls
    #v(0.4em)
    #text(fill: muted)[
      Not a language for users: no types, no modules. It exists to
      write compiler and VM tests by hand, without going through Rocq.
    ]
  ],
)

== Compiler pipeline

// An intermediate representation: its acronym and what it stands for.
#let ir(name, sub) = grid(
  columns: (1.6cm, 4.4cm),
  column-gutter: 0.3cm,
  align: left + horizon,
  text(size: 18pt, weight: "bold", fill: accent)[#name],
  text(size: 13pt, fill: muted)[#sub],
)
#let pass(body) = text(size: 12pt, body)
// What an IR holds, and any pass that rewrites it in place, beside its box.
#let aside(pos, body, note: none) = node(pos, stroke: none, inset: 4pt, block(width: 9.4cm,
  align(left, {
    set par(leading: 0.45em)
    text(size: 13pt, body)
    if note != none { linebreak(); text(size: 12pt, fill: muted, style: "italic", note) }
  })))

#align(center + horizon, diagram(
  spacing: (1.2cm, 0.75cm),
  node-stroke: 0.8pt + luma(60),
  node-inset: 7pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  node((1, 0), name: <src>, stroke: none, inset: 2pt, text(size: 14pt)[Scheme (Rocq) · Fleche]),
  node((1, 1), name: <ds>, ir([DS], [direct style])),
  aside((2, 1), [named binders, lambdas, applications, `match`],
    note: [then uncurried: n-ary lambdas, saturated calls]),
  node((1, 2), name: <dsi>, ir([DSI], [de Bruijn indexed])),
  aside((2, 2), [variables are indices, capture-safe]),
  node((1, 3), name: <cps>, ir([CPS], [continuation-passing])),
  aside((2, 3), [only tail calls, `encore f(x) -> k`]),
  node((0, 3), name: <opt>, inset: 6pt, align(center, text(size: 13pt)[
    #text(weight: "bold")[CPS optimizer] \
    #text(size: 11pt, fill: muted)[simplify, rewrite \ to a fixpoint]])),
  node((1, 4), name: <asm>, ir([ASM], [registers])),
  aside((2, 4), [`SELF`, `CONT`, `A1`–`A8`, `X01`…; captures, globals],
    note: [then peephole-optimized]),
  node((1, 5), name: <bin>, fill: accent, stroke: none, inset: 8pt,
    text(size: 15pt, fill: white, weight: "bold")[ENCR bytecode]),

  edge(<src>, <ds>, "-|>", label: pass[parse, desugar], label-side: left),
  edge(<ds>, <dsi>, "-|>", label: pass[resolve], label-side: left),
  edge(<dsi>, <cps>, "-|>", label: pass[CPS transform], label-side: left),
  edge(<cps>, <opt>, "-|>", shift: 0.12cm),
  edge(<opt>, <cps>, "-|>", shift: 0.12cm),
  edge(<cps>, <asm>, "-|>", label: pass[closure conversion, \ register allocation], label-side: left),
  edge(<asm>, <bin>, "-|>", label: pass[emit], label-side: left),
))
#v(0.2em)
#align(center, text(size: 15pt, fill: muted)[
  Each step makes one thing explicit: arities, binding structure, control flow, machine registers.
])

// A code panel for the IR walkthrough, in the style of the bytecode slide.
#let ir-code(body, size: 11pt) = block(fill: luma(242), inset: 10pt, radius: 3pt, width: 100%, text(size: size, body))
#let ir-slide(code, body, size: 11pt) = grid(
  columns: (1.2fr, 1fr),
  column-gutter: 0.8cm,
  align: horizon,
  ir-code(code, size: size),
  { set text(size: 16pt); body },
)

== DS: direct style

#ir-slide(size: 13pt)[
```
(λ (a) (λ (b)
  (match a
    [()      (match b [() (True)] [(_ _) (False)])]
    [(x a~)  (match b
               [()     (False)]
               [(y b~) (match ((eqb x) y)
                         [() (False)]
                         [() ((digits_eqb a~) b~)])])])))
```
#v(0.3em)
#text(fill: muted)[after `uncurry`:]
```
(λ (a b)
  ... (match (eqb x y) ...
        [() (digits_eqb a~ b~)]) ...)
```
][
  `digits_eqb` as the Scheme frontend produces it.
  - A small λ-calculus: `Lambda`, `Apply`, `Let`, `Letrec`, `Ctor`, `Field`, `Match`, primitives
  - Constructors are a *tag* and fields; `match` binds the fields
  - `uncurry` turns `λa.λb` into `λ(a b)` and saturates calls: one `ENCORE`, not two
]

== DSI: de Bruijn indices

#ir-slide(size: 13pt)[
```
(λ2
  (match #1                            ; a
    [0 (match #0 [0 (True)] [2 (False)])]
    [2 (match #2                       ; b
         [0 (False)]
         [2 (match (eqb #3 #1)         ; x y
              [0 (False)]
              [0 (digits_eqb #2 #0)])])])) ; a~ b~
```
][
  - Names become *indices*: `#0` is the innermost binder
  - A case binds as many slots as it has fields: only the *arity* is left
  - Globals sit at the bottom of the same environment
  - No renaming or capture can go wrong in later passes
]

== CPS: explicit continuations

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.6cm,
  align: top,
  [
    #text(size: 14pt, fill: muted)[after the transform (`Cons`/`Cons` branch)]
    #ir-code[
```
let k25 = cont(r) => encore k18(r)
let k28 = cont(r) =>
  match r
  | False => let c = ctor(0)
             encore k25(c)
  | True  => let k32 = cont(r) =>
               encore k25(r)
             encore digits_eqb(a~, b~) -> k32
encore eqb(x, y) -> k28
```
    ]
    #text(size: 15pt)[
      - Every intermediate value is named
      - `encore f(args) -> k`: jump, never return
    ]
  ],
  [
    #text(size: 14pt, fill: muted)[after the optimizer]
    #ir-code[
```
letrec f(a, b) -> k =
  match a
  | Nil => match b
    | Nil  => let c = ctor(1)
              encore k(c)
    | Cons => let c = ctor(0)
              encore k(c)
  | Cons x a~ => match b
    | Nil => let c = ctor(0)
             encore k(c)
    | Cons y b~ =>
      let e = int.eq(x, y)
      match e
      | False => let c = ctor(0)
                 encore k(c)
      | True  =>
        encore digits_eqb(a~, b~) -> k
fin f
```
    ]
  ],
)
#text(size: 14pt, fill: muted)[
  `eqb` inlined to `int.eq`; administrative continuations η-reduced: the recursive call reuses `k`, so it is a loop.
]

== CPS optimizer

// A rewrite pass of the optimizer, boxed like an IR in the pipeline diagram.
#let step(name) = block(width: 4.4cm, align(center, text(size: 15pt, weight: "bold", name)))

#align(center + horizon, diagram(
  spacing: (1.6cm, 0.6cm),
  node-stroke: 0.8pt + luma(60),
  node-inset: 6pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  node((1, 0), name: <in>, stroke: none, inset: 2pt, text(size: 14pt)[CPS, from the transform]),
  node((1, 1), name: <glob>, step[Global inlining]),
  aside((2, 1), [small non-recursive globals, once: `eqb` → `int.eq`]),
  node((1, 2), name: <inl>, step[Inlining]),
  aside((2, 2), [local functions under 8 nodes, never recursive]),
  node((1, 3), name: <hoist>, step[Hoisting]),
  aside((2, 3), [loop-invariant values out of recursive functions]),
  node((1, 4), name: <cse>, step[CSE]),
  aside((2, 4), [a value computed twice reuses the first name]),
  node((1, 5), name: <contif>, step[Contification]),
  aside((2, 5), [a function with one continuation becomes a jump]),
  node((1, 6), name: <out>, fill: accent, stroke: none, inset: 7pt,
    text(size: 15pt, fill: white, weight: "bold")[Optimized CPS]),

  // Zero-size content: the box takes its height from the rows it encloses,
  // without stretching the middle row.
  node((0, 3), name: <simp>, enclose: ((0, 1), (0, 5)), inset: 8pt, width: 3cm,
    box(width: 0pt, height: 0pt, place(center + horizon,
      text(size: 15pt, weight: "bold")[Simplify]))),

  edge(<in>, <glob>, "-|>"),
  edge(<glob>, <inl>, "-|>"),
  edge(<inl>, <hoist>, "-|>"),
  edge(<hoist>, <cse>, "-|>"),
  edge(<cse>, <contif>, "-|>"),
  edge(<contif>, <out>, "-|>"),
  edge(<contif>, (1.36, 5), (1.36, 2), <inl>, "-|>"),
  ..(1, 2, 3, 4, 5).map(y => edge((1, y), (0, y), "<|-|>", snap-to: (auto, <simp>))),
))
#v(0.2em)
#align(center, text(size: 15pt, fill: muted)[
  The rewrites loop while anything changes, within one fuel budget (100). \ Rewrites expose redexes; simplify removes them.
])

== Simplify

#align(center + horizon, diagram(
  spacing: (1.6cm, 0.6cm),
  node-stroke: 0.8pt + luma(60),
  node-inset: 6pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  node((1, 0), name: <in>, stroke: none, inset: 2pt, text(size: 14pt)[CPS, after a rewrite]),
  node((1, 1), name: <dce>, step[Dead code]),
  aside((2, 1), [drop a binding its body never uses]),
  node((1, 2), name: <copy>, step[Copy propagation]),
  aside((2, 2), [`let y = x`: every `y` becomes `x`]),
  node((1, 3), name: <fold>, step[Constant folding]),
  aside((2, 3), [arithmetic, fields and matches on known values]),
  node((1, 4), name: <beta>, step[β-contraction]),
  aside((2, 4), [a continuation called once is inlined at its call]),
  node((1, 5), name: <eta>, step[η-reduction]),
  aside((2, 5), [`cont(x) => encore k(x)` becomes `k`]),
  node((1, 6), name: <out>, fill: accent, stroke: none, inset: 7pt,
    text(size: 15pt, fill: white, weight: "bold")[Simplified CPS]),

  edge(<in>, <dce>, "-|>"),
  edge(<dce>, <copy>, "-|>"),
  edge(<copy>, <fold>, "-|>"),
  edge(<fold>, <beta>, "-|>"),
  edge(<beta>, <eta>, "-|>"),
  edge(<eta>, <out>, "-|>"),
  edge(<eta>, (1.36, 5), (1.36, 1), <dce>, "-|>"),
))
#v(0.2em)
#align(center, text(size: 15pt, fill: muted)[
  The steps loop while anything changes. None of them grows the code.
])

== ASM: registers

#ir-slide[
```
let X01 = global 13
letrec X02 = fun [] =                 ; no captures
  let X01 = A1                        ; a
  let X02 = A2                        ; b
  let X03 = global 13                 ; digits_eqb
  match X01
  | Nil       => match X02
    | Nil       => let A1 = ctor(1)   ; True
                   encore CONT(A1) -> NULL
    | Cons @X04 => let A1 = ctor(0)   ; False
                   encore CONT(A1) -> NULL
  | Cons @X04 => match X02            ; x a~
    | Nil       => let A1 = ctor(0)
                   encore CONT(A1) -> NULL
    | Cons @X06 =>                    ; y b~
      let X08 = int.eq(X04, X06)
      match X08
      | False => let A1 = ctor(0)
                 encore CONT(A1) -> NULL
      | True  => encore X03(X05, X07) -> CONT
fin X02
```
][
  - Names become *registers*: `SELF`, `CONT`, arguments `A1`–`A8`, locals `X01`…
  - Free variables become *captures*, top-level names *globals*
  - A case says where its fields land: `@X04` unpacks to `X04`, `X05`
  - Returning is `encore CONT(A1) -> NULL`
  - One step from bytecode: the emitter maps each node to an opcode
]

== Bytecode: `digits_eqb`

#grid(
  columns: (1.25fr, 1fr),
  column-gutter: 0.8cm,
  align: horizon,
  block(fill: luma(242), inset: 10pt, radius: 3pt, width: 100%, text(size: 11pt)[
```
01dc  MOV     X01, A1            ; a
01df  MOV     X02, A2            ; b
01e2  GLOBAL  X03, g13           ; digits_eqb
01e5  BRANCH  X01, @01ec, @0203  ; a: Nil | Cons
01ec  BRANCH  X02, @01f3, @01f9  ; b: Nil | Cons
01f3  PACK    A1, tag=1          ; True
01f6  ENCORE  CONT, NULL         ; return
01f9  UNPACK  X04, tag=3, X02
01fd  PACK    A1, tag=0          ; False
0200  ENCORE  CONT, NULL         ; return
0203  UNPACK  X04, tag=3, X01    ; x, a~
0207  BRANCH  X02, @020e, @0214  ; b: Nil | Cons
020e  PACK    A1, tag=0          ; False
0211  ENCORE  CONT, NULL         ; return
0214  UNPACK  X06, tag=3, X02    ; y, b~
0218  EQ      X08, X04, X06      ; eqb x y
021c  BRANCH  X08, @0223, @0229  ; False | True
0223  PACK    A1, tag=0          ; False
0226  ENCORE  CONT, NULL         ; return
0229  MOV     A1, X05            ; a~
022c  MOV     A2, X07            ; b~
022f  ENCORE  X03, CONT          ; tail call
```
  ]),
  [
    #set text(size: 16pt)
    `digits_eqb a b` checks that two lists of digits are equal, element by element. As `encore disasm` prints it:
    - *Uncurried*: both arguments arrive in `A1`, `A2`
    - *`eqb` inlined* into a single `EQ`
    - Each `match` is a `BRANCH` on the tag; `UNPACK` spills the fields
    - `True` / `False` are `PACK`s with no fields: *no allocation*
    - Return: `ENCORE CONT, NULL`
    - Recursion: `ENCORE X03, CONT` passes its own continuation: *no stack growth*
  ],
)

// A code listing on a light panel, with an optional caption above it.
#let codebox(caption: none, size: 12pt, body) = {
  if caption != none { block(below: 5pt, text(size: 13pt, weight: "bold", fill: accent, caption)) }
  block(above: 5pt, fill: luma(242), inset: 9pt, radius: 3pt, width: 100%, text(size: size, body))
}

== Host → VM: calling the program

The VM is a library inside a Rust application that keeps control of memory and I/O.

#grid(
  columns: (0.9fr, 1.1fr),
  column-gutter: 0.8cm,
  align: top,
  [
    #codebox(caption: [Fleche])[
```
data Inc | Dec | Reset
data Print(val) | Beep
data Nil | Cons(head, tail)
data Pair(fst, snd)

# step : State -> Event
#        -> Pair(State, List Effect)
let step = state -> event -> ...
```
    ]
  ],
  [
    #codebox(caption: [Rust host])[
```rust
encore_heap!(HEAP, 40_000);  // static arena
let mut vm = boot(HEAP())?;

// funcs::STEP : (i32, Event) -> StepResult
//   uncurried: both arguments in one call
let r: StepResult =
    vm.call_global(funcs::STEP, (state, Event::Inc))?;

// closures returned by the program: same shape
let y: i32 = vm.call_closure(&k, (x,))?;
```
    ]
    #text(size: 15pt)[Arguments are encoded, the result decoded: \ a type error comes back as `Err`, not a trap.]
  ],
)

== VM → host: externs

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.8cm,
  row-gutter: 5pt,
  align: top,
  codebox(caption: [Fleche: `let extern`])[
```
# bind the host function in slot 0
let extern read_adc 0
let sample = read_adc 3
```
    ],
  codebox(caption: [Scheme / Rocq: `(extern (slot N) args…)`])[
```scheme
;; Extract Constant read_adc =>
;;   "(extern (slot 0) ch)".
(define read_adc (extern (slot 0) ch))
```
    ],
  codebox[
```rust
fn read_adc(vm: &mut Vm, ch: i32)
    -> Result<i32, ExternError> {
    Ok(adc::read(ch))
}
vm.register_extern(0, extern_fn!(read_adc));
```
    ],
  codebox[
```rust
// args arrive packed in one constructor
#[derive(ValueDecode)]
#[ctor(ctors::__FFI0)]
struct AdcArgs(i32);

fn read_adc(vm: &mut Vm, AdcArgs(ch): AdcArgs)
    -> Result<i32, ExternError> {
    Ok(adc::read(ch))
}
vm.register_extern(0, extern_fn!(read_adc));
```
    ],
)
#v(0.2em)
#align(center, text(size: 15pt)[Up to 32 slots of `fn(Value) -> Value`: the only way the program touches the outside.])

== `build.rs`: one source of truth

#grid(
  columns: (1.1fr, 1fr),
  column-gutter: 0.8cm,
  align: top,
  [
    #codebox(caption: [`build.rs` runs the compiler at `cargo build`])[
```rust
let src = fs::read_to_string("fsm.fleche")?;
let (module, ctors) =
    encore_fleche::parse_with_metadata(&src);
pipeline::compile_to_dir_with_ctors(
    &module, Some(OptimizeConfig::default()),
    true,       // also emit bindings.rs
    out_dir, &ctors)?;
```
    ]
    #v(4pt)
    #codebox(caption: [`main.rs` embeds both outputs])[
```rust
encore_vm::encore_program!(env!("OUT_DIR"));
// include_bytes!("bytecode.bin")
// mod bindings { include!("bindings.rs") }
// use bindings::{ctors, funcs}; fn boot(..)
```
    ]
  ],
  [
    #codebox(caption: [Generated `bindings.rs`])[
```rust
pub mod funcs {
  pub const INIT: GlobalAddress = GlobalAddress::new(0);
  pub const STEP: GlobalAddress = GlobalAddress::new(1);
}
pub mod ctors {
  pub const NIL: u8 = 2;   pub const CONS: u8 = 3;
  pub const PAIR: u8 = 4;  pub const INC: u8 = 5;
  pub const DEC: u8 = 6;   pub const RESET: u8 = 7;
  pub const PRINT: u8 = 8; pub const BEEP: u8 = 9;
}
```
    ]
    #v(4pt)
    #text(size: 15pt)[
      Globals and tags are numbered by the compiler. The host only uses names:
      rename `Inc` in `fsm.fleche` and `ctors::INC` *stops compiling*.
      Host and bytecode cannot drift apart.
    ]
  ],
)

== Typed values: `#[derive(ValueEncode, ValueDecode)]`

#grid(
  columns: (0.8fr, 1.2fr),
  column-gutter: 0.8cm,
  align: top,
  [
    #codebox(caption: [Fleche], size: 12pt)[
```
data Inc | Dec | Reset
data Print(val) | Beep
data Nil | Cons(head, tail)
data Pair(fst, snd)

let step = state -> event -> ...
```
    ]
    #v(4pt)
    #text(size: 15pt)[
      - Enum: one variant per constructor
      - Struct: a single constructor
      - Fields in declaration order
      - Decode checks the tag: a mismatch is `DecodeError::TypeMismatch`
    ]
  ],
  [
    #codebox(caption: [Rust host], size: 12pt)[
```rust
#[derive(ValueEncode)]           // Rust → VM
enum Event {
    #[ctor(ctors::INC)]   Inc,
    #[ctor(ctors::DEC)]   Dec,
    #[ctor(ctors::RESET)] Reset,
}

#[derive(ValueDecode)]           // VM → Rust
enum Effect {
    #[ctor(ctors::BEEP)]  Beep,
    #[ctor(ctors::PRINT)] Print(i32),
}

#[derive(ValueDecode)]
#[ctor(ctors::PAIR)]
struct StepResult { state: i32, effects: VmList<Effect> }
```
    ]
  ],
)

== Lists and bytes: `VmList<T>`, `VmBytes`

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.8cm,
  align: top,
  [
    #codebox(caption: [`VmList<T>`: a handle to `Nil | Cons`])[
```rust
// lazy: decode one cell at a time, no copy
let mut l = effects;
while let Some((e, rest)) = l.next(&vm) {
    handle(e);
    l = rest;
}

// bounded: copy into a caller buffer
let mut buf = [Effect::Beep; 4];
let effs: &[Effect] =
    effects.materialize(&vm, &mut buf)?;

// in: a Rust slice, encoded on the call
vm.call_global(funcs::SORT,
               (VmList::view(&[3, 1, 2]),))?;
```
    ]
  ],
  [
    #codebox(caption: [`VmBytes`: a handle to a heap byte string])[
```rust
let msg: VmBytes = vm.call_global(
    funcs::HASH, (VmBytes::view(b"hello"),))?;

let n  = msg.len(&vm);
let b0 = msg.get(&vm, 0);

let mut buf = [0u8; 32];
let out: &[u8] = msg.materialize(&vm, &mut buf)?;
```
    ]
    #v(4pt)
    #text(size: 15pt)[
      - A handle is one `Value`: `Copy`, no allocation on the host side
      - Copies land in *caller-owned buffers*; too short is an `Err`, never an overflow
      - No `alloc`: fits `#![no_std]` hosts
    ]
  ],
)

== Scheme runtimes on the target

#simple-table((1fr, auto, auto, auto),
  [], [Chibi], [Ribbit], [Encore],
  [Runtime model], [interpreter], [VM], [VM],
  [Runs Rocq-extracted Scheme], [✓], [✗ no quasiquote], [✓],
  [Fits 256 KB flash], [✗], [✓], [✓],
  [Pipeline complexity], [high], [medium], [low],
  [Working bare-metal], [✗], [✓], [✓],
)
#v(0.3em)
#text(size: 16pt)[
  Chibi evaluates the source on every boot and is too big; Ribbit fits but runs
  hand-written Scheme, not the extracted code. *Encore is the only one that does all four.*
]

= Experiment plan

== Three ways to ship the same logic

// The same five stages on every variant slide, so the three read side by side.
#let pipe-stages = ([Source], [Compiler], [Output], [Runtime], [Memory])
#let pipe(..steps) = {
  let rows = pipe-stages.zip(steps.pos()).map(((stage, step)) => (
    align(right + horizon, text(size: 12pt, fill: muted, stage)),
    align(center + horizon, text(size: 15pt, step)),
  ))
  grid(
    columns: (auto, 1fr),
    column-gutter: 10pt,
    row-gutter: 12pt,
    ..rows.flatten(),
  )
}
#let variant-card(name, role) = block(
  width: 100%, inset: 14pt, radius: 4pt, stroke: 0.5pt + luma(200),
)[
  #align(center)[
    #text(size: 26pt, weight: "bold", fill: accent)[#name] \
    #text(size: 14pt, fill: muted)[#role]
  ]
]
// One slide per variant: its pipeline on the left, then the same three points
// (source, execution, trusted) on the right, and the shared setup underneath.
#let variant-slide(pipeline, body, logo-file: none) = {
  if logo-file != none { place(top + right, dy: -0.4cm, logo(logo-file, height: 1.4cm)) }
  v(1fr)
  grid(
    columns: (1fr, 1fr),
    column-gutter: 1cm,
    block(width: 100%, inset: 14pt, radius: 4pt, stroke: 0.5pt + luma(200), pipeline),
    align(horizon, { set text(size: 17pt); body }),
  )
  v(1fr)
  align(center, text(size: 14pt, fill: muted)[
    Linked into the same Rust driver and harness · QEMU Cortex-M3, 50 KiB RAM
  ])
}

#v(1fr)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 0.8cm,
  variant-card([Encore], [system under study]),
  variant-card([CertiRocq], [closest verified competitor]),
  variant-card([Rust no_std], [performance ceiling, output oracle]),
)
#v(1fr)
#align(center, text(size: 14pt, fill: muted)[
  Same inputs, same Rust driver and harness, every output checked against Rust ·
  QEMU Cortex-M3, 50 KiB RAM budget · instructions counted per run
])

== Encore

#variant-slide(pipe(
  [Gallina],
  [Rocq extraction → Scheme, \ `encore compile`],
  [bytecode],
  [`encore_vm`, `no_std` Rust],
  [32 KiB heap, mark-compact GC],
))[
  - *Source*: the proved Gallina; `ExtrEncore.v` maps `nat` to a 24-bit VM
    integer and arithmetic to VM primitives
  - *Execution*: CPS optimizer on; the heap is kept across runs and collected
    only when full
  - *Trusted*: extraction, the compiler, the VM and the `nat` mapping
]

== CertiRocq

#variant-slide(logo-file: "certirocq.svg", pipe(
  [Gallina],
  [CertiRocq v0.9.1 → Clight, \ `gcc -Os`],
  [Thumb-2 code],
  [CertiRocq runtime, C],
  [20 KiB arena, generational GC],
))[
  - *Source*: the same Gallina; `nat` mapped to 31-bit machine integers, the
    same unproven assumption as Encore
  - *Execution*: fresh arena per run, recursion on the C stack; a case
    that does not fit fails: ✗~arena or ✗~stack
  - *Trusted*: gcc, the runtime and the `nat` mapping; the compiler is largely
    verified down to Clight
]

== Rust no_std

#variant-slide(logo-file: "rust.svg", pipe(
  [hand-written Rust],
  [`rustc`, `opt-level = "s"`, LTO],
  [Thumb-2 code],
  [none, bare metal],
  [static buffers, no allocator],
))[
  - *Source*: idiomatic firmware Rust, not derived from the Gallina and not a
    copy of its functional structure
  - *Execution*: the performance ceiling, and the output oracle: every Encore
    and CertiRocq output is hashed and compared with Rust's
  - *Trusted*: everything; memory-safe, but nothing is proved
]

== Eight firmware workloads

#text(size: 16pt)[Each is a `step` function whose bug would be a security hole or a field failure, with one property proved in Rocq and a size N to scale it.]
#v(0.3em)
#{
  set text(size: 15pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  table(
    columns: (auto, auto, 1fr, auto),
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 8pt, y: 5pt),
    table.header([], [Workload], [Where it runs], [N]),
    [W1], [APDU + BER-TLV parser], [secure element, first thing done with a command], [APDU 5 → 261 B],
    [W2], [Ethereum RLP decoder], [hardware wallet, what the screen shows before signing], [calldata 0 → 260 B],
    [W3], [BIP32 path policy], [hardware wallet, sign or refuse a request], [1 → 64 rules],
    [W4], [PIN state machine], [secure element, ISO 7816 VERIFY and PUK], [1 → 1000 APDUs],
    [W5], [A/B firmware update], [bootloader, anti-rollback under power cuts], [10 → 1000 events],
    [W6], [COBS framing], [serial link, encode then decode a frame], [16 → 1024 B],
    [W7], [FIDO credential store], [authenticator, persistent red-black tree], [10 → 500 entries],
    [W8], [CRC-16 and CRC-32], [every frame and image; worst case for a VM], [16 → 1024 B],
  )
}

= Conclusion

== Across workloads

#recap-table((
  ([W1], "w1_apdu", [APDU + BER-TLV parser]),
  ([W2], "w2_rlp", [Ethereum RLP decoder]),
  ([W3], "w3_policy", [BIP32 path policy]),
  ([W4], "w4_pin", [PIN state machine]),
  ([W5], "w5_update", [A/B firmware update]),
  ([W6], "w6_cobs", [COBS framing]),
  ([W7], "w7_store", [FIDO credential store]),
  ([W8], "w8_crc", [CRC-16 and CRC-32]),
))
#v(0.3em)
#text(size: 16pt)[
  Encore runs every size of every workload within the 50 KiB budget, including
  the 10 where CertiRocq runs out of arena or stack. The price is instructions:
  2–10× CertiRocq and 10–2,000× hand-written Rust, the worst on pure arithmetic (W8).
]

== Takeaways

- *Proved logic runs on bare metal*: extracted to Scheme, compiled by Encore,
  deployed on a Ledger Flex, and within 50 KiB on all eight workloads, where
  CertiRocq runs out of memory on 10 cases
- *The price is instructions*: 2–10× CertiRocq, 10–2,000× hand-written Rust,
  the worst on arithmetic
- *The architecture scales*: the proved `step` grows with the application,
  the trusted boundary does not

== Next steps

- *Prove the optimizer*: port the nine CPS passes and prove them
  semantics-preserving, CompCert style
- *Ahead-of-time Thumb-2 backend*: no interpreter dispatch; separates the cost
  of interpretation from the CPS and GC model
- *Verify the VM* with `rocq-of-rust`: a simulation between the CPS semantics
  and the Rust interpreter, GC and `ENCORE` dispatch first
- *Measure the rest*: cycles on real boards, GC pauses, proof effort

== Quick start

```sh
encore compile scheme extracted.scm --out program.encr
encore run program.encr
```

- `encore disasm` for an interactive bytecode inspector
- `encore compile fleche` for Fleche sources
