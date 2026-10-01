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


= Introduction

== Why verify firmware logic

- Generated code is getting cheap: *more code to review*, same assurance level
- seL4, a proved OS kernel, showed machine-checked correctness at the systems level; firmware
  wants the same rigour
- Formal specifications scale: a generated implementation is checked against
  theorem statements
- But extracted code needs a runtime, and the usual answer is to *translate
  the specification by hand* into the host language, weakening the link to
  the proof

= Making firmware provable

== Maximise the pure core

#text(size: 18pt)[Push the pure frontier as far as it goes: *maximise the part Rocq can prove*.]
#v(0.2em)
#align(center, text(size: 22pt)[`step : State × Event → State × list Effect`])
#v(0.3em)
- The whole application is one pure function: a state and an event in, the
  next state and a list of effects out
- Copy instead of mutate, describe effects instead of performing them
- Parsing, policy, state machines, storage layout: all Gallina, all under `step`
- Proofs are stated over `step`: an invariant that holds before an event
  holds after it

== Admitted pure functions

#text(size: 18pt)[Some functions are pure but not worth proving, or too slow in a VM: *axiomatise them*.]
#v(0.2em)
#text(size: 15pt)[
```coq
Parameter sha256 : bytes -> bytes.
Axiom sha256_len : forall b, bytes_len (sha256 b) = 32.
Extract Constant sha256 => "(extern (slot 3) b)".
```
]
#v(0.2em)
- Hashes, CRCs, MACs, signatures: still functions, so `step` stays pure
- A `Parameter` for the function, an `Axiom` for each property the proofs use
- Realised by an Encore extern, a host callback (often a hardware
  accelerator), *trusted* to satisfy the axioms

== A formal SDK

#text(size: 18pt)[The contract between the proved code and the device, *written once in Rocq*.]
#v(0.4em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  {
    set text(size: 19pt)
    [*In Rocq: the SDK*]
    [
      - `Event`: card command (APDU), button, timer
      - `Effect`: send, write flash
      - Axioms for admitted functions
      - Extraction directives
    ]
  },
  {
    set text(size: 19pt)
    [*On the host: its Rust side*]
    [
      - Event poller → `Event`
      - `Effect` → device action
      - Externs realising the axioms
      - VM and driver loop around `step`
    ]
  },
)
#v(0.5em)
#text(size: 17pt, fill: muted)[An application is a `State` and a `step`; the SDK and its host side are reused unchanged.]

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

== Running Rocq on the target: the options

#{
  set text(size: 13pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  let no = text(fill: accent, weight: "bold")[✗]
  let yes = text(fill: rgb("#2e7d32"), weight: "bold")[✓]
  let part = text(fill: rgb("#b26a00"), weight: "bold")[◐]
  let name(file, body, height: 0.75cm) = grid(columns: (0.9cm, auto), column-gutter: 6pt, align: horizon,
    image("/assets/logos/" + file, height: height), text(weight: "bold", body))
  table(
    columns: (auto, 1fr, 1fr, auto),
    align: (col, row) => if col == 3 { center + horizon } else { left + horizon },
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 7pt, y: 6pt),
    table.header([Path], [What its runtime needs], [Status on a small Arm chip], [Compiler \ proved]),
    name("lean.png")[Lean 4],
    [a C++ library, reference counting with cycle collection, threads, an OS for I/O],
    [#no not on the roadmap; the one microcontroller port (ESP32-C3) needed a patched C++ library and *384 KB of RAM*],
    no,
    name("ocaml.svg")[Rocq → OCaml],
    [a generational garbage collector, the C and maths libraries],
    [#no ports need assembly patches and stubs; the OCaml VM for microcontrollers (OMicroB) has no merged Arm port],
    no,
    name("certirocq.svg")[CertiRocq],
    [a heap whose collector is part of the proof; numbers stay unary (`S (S O)`)],
    [#part runs only with a patched runtime: fixed-size heap, and *the program aborts* when it is full],
    [#part \ largely, \ down to C],
    name("scheme.png")[Rocq → Scheme],
    [a small Scheme runtime: to find, or to build],
    [#yes small Scheme systems already fit microcontrollers (Ribbit: 4 KB)],
    no,
  )
}
#v(0.2em)
#text(size: 15pt)[
  Only Scheme has a runtime small enough; only CertiRocq proves its compiler,
  and it does not fit in practice. *We take the Scheme path, and build the runtime.*
]

== From Rocq to Scheme

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.8cm,
  align: top,
  [
    #text(size: 14pt, fill: muted)[Gallina (the language of Rocq)]
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
    #text(size: 14pt, fill: muted)[Scheme, as Rocq extracts it]
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
  Functions take one argument at a time (`lambdas`, `@`); data is a tag and its
  fields (#raw("`(Cons ,x ,l)")), and `match` looks at the tag. Rocq defines these
  three as macros; Encore makes them *built-in*.
]

== Scheme runtimes on the target

#{
  set text(size: 14pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  let no(body) = [#text(fill: accent, weight: "bold")[✗] #body]
  let yes(body) = [#text(fill: rgb("#2e7d32"), weight: "bold")[✓] #body]
  let head(file, body, height: 0.9cm) = stack(spacing: 4pt, image("/assets/logos/" + file, height: height), body)
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (col, row) => if row == 0 { center + bottom } else if col == 0 { left + horizon } else { center + horizon },
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 7pt, y: 6pt),
    table.header([], head("chibi.png")[Chibi], head("ribbit.png", height: 0.7cm)[Ribbit], text(fill: accent, size: 20pt)[Encore]),
    [How it runs], [interpreter, in C], [small bytecode VM, in C], [bytecode VM, in Rust],
    [What ships on the chip], [the Scheme *source*, evaluated at every boot], [bytecode + a generated VM], [bytecode + the VM library],
    [Porting work], [≈ 50 C files, OS stubs], [static heap, debug-output shim], [none: built for bare metal],
    [Fits 256 KB of flash], no[too big], yes[], yes[],
    [Runs the code Rocq extracts], yes[], no[lacks a construct it uses \ (quasiquote)], yes[],
    [Ran the proved logic on the chip], no[], no[hand-written Scheme only], yes[],
  )
}

== The key idea: continuation-passing style (CPS)

#text(size: 18pt)[In CPS, *no function ever returns*: each call also receives *what to do next* (its continuation), and jumps.]
#v(0.3em)
- Code extracted from Rocq is already close to this form: functions take one
  argument at a time
- No return means *no call stack*: a VM built on it needs only registers and a heap,
  no hidden control flow
- Every intermediate value gets a name: it maps directly onto a register
- The garbage collector finds every live value in the registers: no stack to scan

= Encore: compiler and VM

== Encore at a glance

// Colours of the overview: compilation stages, the VM, the host, the OS.
#let green = (fill: rgb("#d5e8d4"), stroke: 0.9pt + rgb("#82b366"))
#let blue = (fill: rgb("#dae8fc"), stroke: 0.9pt + rgb("#6c8ebf"))
#let red = (fill: rgb("#f8cecc"), stroke: 0.9pt + rgb("#b85450"))
#let grey = (fill: rgb("#f5f5f5"), stroke: 0.9pt + rgb("#666666"))
#let stage(pos, name, body) = node(pos, name: name, width: 5.4cm, ..green, text(size: 14pt, body))

#align(center + horizon, scale(118%, reflow: true, diagram(
  spacing: (0.9cm, 0.5cm),
  node-inset: 7pt,
  node-corner-radius: 4pt,
  edge-stroke: 0.9pt + black,
  mark-scale: 80%,

  stage((0, 0), <rocq>)[Rocq (Gallina code)],
  stage((0, 1), <scm>)[Scheme code],
  stage((0, 2), <cps>)[Continuation-passing style (CPS)],
  node((1, 2), name: <opt>, stroke: 0.9pt + black, text(size: 14pt)[CPS optimizer]),

  stage((0, 3.3), <bc>)[Bytecode],
  node((0, 4.05), name: <vml>, stroke: none, text(size: 13pt)[#text(weight: "bold")[_Encore_ VM] (a library \ of the Rust application)]),
  node(enclose: (<bc>, <vml>), name: <vm>, ..blue, inset: 9pt),

  node((1, 3.3), name: <main>, ..red, width: 6.4cm, align(center, stack(spacing: 5pt,
    block(fill: luma(246), inset: 5pt, text(size: 11pt)[```rust
encore_heap!(HEAP, 32_768);
let mut vm = boot(HEAP())?;
```]),
    text(size: 13pt)[`main.rs`]))),
  node((1, 4.4), name: <build>, ..red, width: 6.4cm, text(size: 13pt)[runs the _Encore_ compiler \ `build.rs`]),
  node((0.5, 5.25), name: <hostl>, stroke: none, text(size: 14pt)[*Host* (Rust application)]),
  node(enclose: (<vm>, <main>, <build>, <hostl>), name: <host>, ..red, inset: 9pt),

  node((2.05, 4), name: <other>, ..grey, text(size: 13pt)[Other \ application]),
  node((1, 6.05), name: <osl>, stroke: none, text(size: 14pt, weight: "bold")[Microcontroller OS]),
  node(enclose: (<host>, <other>, <osl>), ..grey, inset: 9pt, corner-radius: 6pt),

  edge(<rocq>, <scm>, "-|>"),
  edge(<scm>, <cps>, "-|>"),
  edge(<cps>, <opt>, "-|>", shift: 0.12cm),
  edge(<opt>, <cps>, "-|>", shift: 0.12cm),
  edge(<cps>, <bc>, "-|>"),
)))

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

== Compiler pipeline

// A stage of the compiler: its name and, in plain words, what it makes explicit.
#let ir(name, sub) = grid(
  columns: (3.3cm, 4.6cm),
  column-gutter: 0.3cm,
  align: left + horizon,
  text(size: 17pt, weight: "bold", fill: accent)[#name],
  text(size: 13pt, fill: muted)[#sub],
)
#let pass(body) = text(size: 12pt, body)

#align(center + horizon, diagram(
  spacing: (1.2cm, 0.8cm),
  node-stroke: 0.8pt + luma(60),
  node-inset: 7pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  node((1, 0), name: <src>, stroke: none, inset: 2pt, text(size: 14pt)[Scheme extracted from Rocq]),
  node((1, 1), name: <ds>, ir([Direct style], [ordinary nested calls, \ functions take all their arguments])),
  node((1, 2), name: <cps>, ir([CPS], [every call is a jump, \ with its continuation])),
  node((0, 2), name: <opt>, inset: 6pt, align(center, text(size: 13pt)[
    #text(weight: "bold")[CPS optimizer] \
    #text(size: 11pt, fill: muted)[repeats until \ nothing changes]])),
  node((1, 3), name: <asm>, ir([Registers], [variables placed in \ the VM's registers])),
  node((1, 4), name: <bin>, fill: accent, stroke: none, inset: 8pt,
    text(size: 15pt, fill: white, weight: "bold")[Bytecode]),

  edge(<src>, <ds>, "-|>", label: pass[parse, merge curried functions], label-side: left),
  edge(<ds>, <cps>, "-|>", label: pass[CPS transform], label-side: left),
  edge(<cps>, <opt>, "-|>", shift: 0.12cm),
  edge(<opt>, <cps>, "-|>", shift: 0.12cm),
  edge(<cps>, <asm>, "-|>", label: pass[register allocation], label-side: left),
  edge(<asm>, <bin>, "-|>", label: pass[emit], label-side: left),
))
#v(0.2em)
#align(center, text(size: 15pt, fill: muted)[
  Each stage makes one thing explicit: how many arguments, where control goes next, which register holds what.
])

// A code panel for the IR walkthrough, in the style of the bytecode slide.
#let ir-code(body, size: 11pt) = block(fill: luma(242), inset: 10pt, radius: 3pt, width: 100%, text(size: size, body))

== CPS: explicit continuations

#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.6cm,
  align: top,
  [
    #text(size: 14pt, fill: muted)[after the transform (`Cons`/`Cons` branch)]
    #ir-code[
```ir
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
```ir
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
  `eqb` is inlined into `int.eq`, and continuations that only pass their result on are removed: the recursive call reuses `k`, so it runs as a loop.
]

== CPS optimizer

#{
  set text(size: 14pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  let group(body) = table.cell(colspan: 2, inset: (top: 8pt, bottom: 3pt, x: 7pt), text(fill: accent, weight: "bold", body))
  table(
    columns: (auto, 1fr),
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(225) }),
    inset: (x: 7pt, y: 5pt),
    table.header([Step], [What it does]),
    group[Rewrites: make the code smaller or faster],
    [Global inlining], [replace a call to a small global function by its body, e.g. `eqb` → `int.eq`],
    [Local inlining], [the same for small local functions, never recursive ones],
    [Hoisting], [move a value that does not change out of a loop],
    [Common subexpressions], [a value computed twice reuses the first result],
    [Contification], [a function always returning to the same place becomes a plain jump],
    group[Clean-up after every rewrite: never grows the code],
    [Dead code], [drop a value that is never used],
    [Copy propagation], [after `let y = x`, use `x` directly],
    [Constant folding], [compute arithmetic and `match` on known values at compile time],
    [Continuation inlining], [a continuation used once is pasted where it is called],
  )
}
#v(0.2em)
#align(center, text(size: 15pt, fill: muted)[
  Rewrites and clean-up repeat until nothing changes (at most 100 rounds). \
  On our workloads it cuts the instructions executed by a factor of 2 to 4.
])

== Bytecode: `digits_eqb`

#grid(
  columns: (1.25fr, 1fr),
  column-gutter: 0.8cm,
  align: horizon,
  block(fill: luma(242), inset: 10pt, radius: 3pt, width: 100%, text(size: 11pt)[
```ir
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
    #codebox(caption: [Rocq])[
```coq
Inductive event := Inc | Dec | Reset.
Inductive effect := Print (v : nat) | Beep.

Definition step (s : nat) (e : event)
  : nat * list effect := ...
```
    ]
  ],
  [
    #codebox(caption: [Rust host])[
```rust
encore_heap!(HEAP, 32_768);  // static arena
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
  codebox(caption: [Rocq: an axiom, extracted to an extern])[
```coq
Parameter read_adc : nat -> nat.
Extract Constant read_adc =>
  "(extern (slot 0) ch)".
```
    ],
  codebox(caption: [Extracted Scheme: `(extern (slot N) args…)`])[
```scheme
;; a curried wrapper that calls slot 0
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
let src = fs::read_to_string("fsm.scm")?;
let (module, ctors) =
    encore_scheme::parse_with_metadata(&src);
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
      rename `Inc` in the Rocq source and `ctors::INC` *stops compiling*.
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
    #codebox(caption: [Rocq], size: 12pt)[
```coq
Inductive event :=
  Inc | Dec | Reset.
Inductive effect :=
  Print (v : nat) | Beep.
(* step returns a pair *)
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

== Encore and its two baselines

#{
  set text(size: 14pt)
  show table.cell.where(y: 0): set text(weight: "bold", size: 18pt)
  let head(body, logo-file: none) = stack(dir: ltr, spacing: 6pt,
    if logo-file != none { box(baseline: 20%, image("/assets/logos/" + logo-file, height: 0.6cm)) },
    body)
  table(
    columns: (auto, 1fr, 1fr, 1fr),
    align: (col, row) => if col == 0 { left + horizon } else { center + horizon },
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 7pt, y: 6pt),
    table.header([], text(fill: accent)[Encore], head(logo-file: "certirocq.svg")[CertiRocq], head(logo-file: "rust.svg")[Rust]),
    [*Role*], [the system under study], [the closest verified competitor], [the speed ceiling, and the reference output],
    [*Source*], [the proved Rocq code], [the same Rocq code], [hand-written, idiomatic firmware Rust],
    [*Compiled by*], [Rocq extraction → Scheme → `encore compile`], [CertiRocq → C, then `gcc -Os`], [`rustc`, optimised for size],
    [*Runs as*], [bytecode, in the Encore VM], [native Arm code + a C runtime], [native Arm code, no runtime],
    [*Memory*], [32 KiB heap, compacting garbage collector], [20 KiB heap, generational garbage collector], [fixed buffers, no heap],
    [*Numbers* (`nat`)], [24-bit integers (assumed, not proved)], [31-bit integers (same assumption)], [machine integers],
    [*Trusted*], [extraction, compiler, VM], [`gcc` and the runtime; the compiler is largely proved], [everything: memory-safe, nothing proved],
  )
}

= Evaluation

== Research questions

#grid(
  columns: (auto, 1fr),
  column-gutter: 0.6cm,
  row-gutter: 0.75em,
  align: (right + top, left + top),
  ..(
    ([RQ1], [*Does it fit?* Does the proved logic run within a secure element's 50 KiB of RAM, as the input grows?]),
    ([RQ2], [*What does it cost?* How much slower is Encore than CertiRocq and than hand-written Rust?]),
    ([RQ3], [*Where does the time go?* How much is interpretation, how much garbage collection, what does the optimizer save?]),
    ([RQ4], [*How does memory behave?* Peak RAM, and the garbage collector's collections, pauses and live data.]),
  ).map(((q, body)) => (text(size: 22pt, weight: "bold", fill: accent, q), text(size: 19pt, body))).flatten(),
)
#v(1fr)
#block(width: 100%, inset: 12pt, radius: 4pt, stroke: 0.5pt + luma(200), text(size: 15pt)[
  *Setup* · the three variants, linked into the same Rust driver · an emulated Arm
  Cortex-M3 (QEMU), 50 KiB of RAM · cost = Arm instructions executed per run
  (not cycles) · every output checked against Rust's
])

== Custom dataset: eight representative firmware workloads

#text(size: 15pt)[Each is a function whose bug would be a security hole or a field failure, with one property proved in Rocq, and an input size *N* that we grow.]
#v(0.1em)
#{
  set text(size: 13pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  table(
    columns: (auto, auto, 1fr, auto, auto),
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 6pt, y: 4.5pt),
    align: horizon,
    table.header([], [Workload], [What it does, in plain words], [Found in], [N grows]),
    [W1], [Command parser], [split a smart-card command into its header and data, then read the nested fields of the data], [bank / SIM card], [5 → 261 bytes],
    [W2], [Transaction decoder], [decode an Ethereum transaction, to show the user what they are about to sign], [crypto wallet], [0 → 260 bytes],
    [W3], [Signing policy], [check a signing request (which key, how much, to whom) against a list of rules], [crypto wallet], [1 → 64 rules],
    [W4], [PIN check], [verify PIN codes, count wrong tries, block the card, unblock it with a second code], [bank / SIM card], [1 → 1000 commands],
    [W5], [Firmware update], [install an update in a spare slot, go back if it fails, never downgrade, survive power cuts], [bootloader], [10 → 1000 events],
    [W6], [Message framing], [rewrite a message so it contains no zero byte (zero marks message boundaries), then decode it], [serial link], [16 → 1024 bytes],
    [W7], [Credential store], [keep login keys and their use counters in a balanced search tree], [security key], [10 → 500 keys],
    [W8], [Checksums], [compute two checksums (CRC) that detect corrupted data: pure arithmetic, *the worst case for an interpreter*], [everywhere], [16 → 1024 bytes],
  )
}

// The rows of every result table.
#let workloads = (
  ([W1], "w1_apdu", [Command parser]),
  ([W2], "w2_rlp", [Transaction decoder]),
  ([W3], "w3_policy", [Signing policy]),
  ([W4], "w4_pin", [PIN check]),
  ([W5], "w5_update", [Firmware update]),
  ([W6], "w6_cobs", [Message framing]),
  ([W7], "w7_store", [Credential store]),
  ([W8], "w8_crc", [Checksums]),
)

== RQ1: does it fit in 50 KiB?

#fit-table(workloads)
#v(0.2em)
#text(size: 15pt)[
  *Encore runs every size of every workload.* CertiRocq fails on 10 of the 27 sizes it was built for:
  ✗ arena, its heap is full; ✗ stack, its C call stack overflows. Rust always fits but proves nothing.
  CertiRocq has no build of W8 yet.
]

== RQ2: what does it cost?

#slowdown-table(workloads)
#v(0.2em)
#text(size: 15pt)[
  Ratio of Arm instructions executed per run, over the sizes where both variants run.
  Encore is *2 to 10 times slower than CertiRocq*, and 10 to 2,000 times slower than
  hand-written Rust; the worst case is pure arithmetic (W8).
]

== RQ3: where does Encore's time go?

#time-chart(workloads.filter(w => w.at(1) != "w8_crc"))
#v(0.1em)
#text(size: 14pt)[
  At the largest size CertiRocq also runs. *The gap is interpretation, not garbage collection*:
  each bytecode instruction costs 27–31 Arm instructions, whatever the workload. The optimizer
  already divides the work by 3 to 4 (– : not measured). A collection splits into mark 22 %,
  forward 17 %, update pointers 36 %, compact 26 %.
]

== RQ4: how does memory behave?

#memory-table(workloads)
#v(0.2em)
#text(size: 14pt)[
  RAM ranges go from the smallest to the largest input size. Encore collects only when its heap
  is full, so it peaks at its 32 KiB heap (40 KiB for W6) plus 5 KiB of stack; at most 28 KiB is
  live. A *pause* is one collection, during which the program is stopped: up to 309 k instructions
  (a few ms at 70 MHz), to weigh against the time limit a smart-card command must answer within.
]

= Conclusion

== Takeaways

- *RQ1, it fits*: proved logic, extracted to Scheme and compiled by Encore, runs
  bare-metal within 50 KiB on every size of all eight workloads, where CertiRocq
  runs out of memory on 10 sizes
- *RQ2, the price is speed*: 2–10× slower than CertiRocq, 10–2,000× slower than
  hand-written Rust, the worst on pure arithmetic
- *RQ3, the price is interpretation*: about 30 Arm instructions per bytecode
  instruction; garbage collection is a minor share
- *RQ4, memory is fixed, not minimal*: a 32–40 KiB heap plus 5 KiB of stack whatever
  the size, at most 28 KiB of it live; collection takes up to 22 % of the time
- *The architecture scales*: the proved `step` grows with the application,
  the trusted part does not

== Next steps

- *Prove the optimizer*: prove each CPS rewrite preserves the program's meaning,
  as CompCert does for C
- *Compile the bytecode to Arm code ahead of time*: removes the interpretation
  cost that RQ3 points at
- *Verify the VM* with `rocq-of-rust`: show the Rust interpreter and its garbage
  collector follow the CPS semantics
- *Measure the rest*: cycles and pauses in time on real boards, a heap sized to
  the live data, proof effort

== Quick start

```sh
encore compile scheme extracted.scm --out program.encr
encore run program.encr
```

- `encore disasm` for an interactive bytecode inspector
