#import "/template/lib.typ": *
#import "/template/bench.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// VeCOS 2026 — conference talk for "From Rocq to Metal", ~20 min.
// Outline in the order a research audience expects: context, state of the
// art, approach, Encore, experimental setup (research questions, compared
// systems, dataset), results per research question, conclusion.

#show: encore-theme.with(
  title: [From Rocq to Metal],
  subtitle: [A pipeline for formally verified microcontroller firmware],
  institution: [VeCOS 2026 — Amsterdam],
  date: datetime(year: 2026, month: 11, day: 19),
  slug: "2026-11-19-vecos",
  links: (
    (url: "https://arxiv.org/pdf/2606.02651", label: "Paper"),
    (url: "https://github.com/vbergeron/encore", label: "encore"),
    (url: "https://github.com/vbergeron/encore-benchmarks", label: "encore-benchmarks"),
  ),
)

#let simple-table(columns, size: 15pt, ..cells) = {
  set text(size: size)
  show table.cell.where(y: 0): set text(weight: "bold")
  table(
    columns: columns,
    align: left + horizon,
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 7pt, y: 5pt),
    ..cells,
  )
}
#let yes = text(fill: rgb("#2e7d32"), weight: "bold")[✓]
#let no = text(fill: accent, weight: "bold")[✗]
#let note(body) = text(size: 14pt, fill: muted, body)

#let workloads = (
  ([W1], "w1_apdu", [Smart-card command parser]),
  ([W2], "w2_rlp", [Transaction decoder]),
  ([W3], "w3_policy", [Signing policy]),
  ([W4], "w4_pin", [PIN counter]),
  ([W5], "w5_update", [Firmware update]),
  ([W6], "w6_cobs", [Serial framing]),
  ([W7], "w7_store", [Credential store]),
  ([W8], "w8_crc", [Checksums]),
)

= Context

== Proved logic, unproved runtime

- Secure elements and hardware wallets run small, critical logic: command
  parsing, PIN counters, signing policy, firmware updates
- Rocq can prove that logic, but *extracted code needs a runtime*
- The usual answer on a microcontroller: *re-implement the specification by
  hand* in C or Rust, and lose the link to the proof
- Question: can the extracted program itself run on the chip?

== The target: 50 KB of RAM

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  simple-table((auto, 1fr),
    [], [ST33J2M0 secure element],
    [CPU], [ARM Cortex-M, Thumb-2],
    [Flash], [2 MB],
    [RAM], [*50 KB*],
    [Clock], [60 MHz],
    [Cache], [none],
  ),
  [
    - RAM is the binding constraint
    - No operating system, no C library, no Rust `std`
    - Applications often ship with *no runtime at all*
  ],
)

= State of the art

== Running extracted code: the options

#simple-table((auto, 1fr, auto, auto, auto, 1fr), size: 13pt,
  [Path], [Runtime it needs], [No OS], [Fits\ 50 KB], [Verified\ compiler], [Status on a Cortex-M],
  [*Lean 4* → C], [C++ library, reference counting, threads, hosted IO], no, no, no,
    [ESP32 port needs a patched C++ library and 384 KB of RAM],
  [*Rocq → OCaml*], [generational GC, C library and maths library], no, no, no,
    [native port needs assembly patches, linker script, library stubs],
  [*OCaml VM* (OMicroB)], [small bytecode VM], yes, yes, no,
    [AVR and PIC32 only; Cortex-M0 port unmerged],
  [*CertiRocq* → C], [GC-aware heap, C call stack for recursion], yes, [partly], [largely],
    [runs after patching its runtime; deep recursion overflows the stack],
  [*Rocq → Scheme*], [a small Scheme runtime], yes, [depends], no,
    [needs a runtime that fits: next table],
)
#v(0.3em)
#note[CertiRocq is the closest verified competitor. Scheme extraction is the only path whose runtime we can make fit: Encore is that runtime.]

== Scheme runtimes for the extracted code

#simple-table((auto, 1fr, 1fr, 1fr), size: 15pt,
  [], [Chibi Scheme], [Ribbit], [*Encore*],
  [Model], [interpreter, in C], [compact VM, in C], [compiler + VM, in Rust],
  [Program on the device], [source text, re-read at every boot], [bytecode], [bytecode],
  [Runs Rocq-extracted Scheme], [#yes], [#no lacks quasiquote], [#yes],
  [Fits 256 KB of flash], [#no], [#yes], [#yes],
  [Fits 50 KB of RAM], [#no], [#yes], [#yes],
  [Memory model], [C stack + GC], [static heap + GC], [no call stack, fixed heap + GC],
  [Ran bare-metal in our tests], [#no too large], [hand-written code only], [#yes all 8 workloads],
)
#v(0.3em)
#note[Chibi is too large; Ribbit fits but cannot compile what Rocq extracts. Encore is the only one that does both.]

= Approach

== Overview

#let box-node(pos, body, name: none, fill: none, stroke: 0.8pt + luma(60)) = node(
  pos, name: name, fill: fill, stroke: stroke, inset: 7pt, corner-radius: 3pt,
  align(center, text(size: 13pt, body)))
#let group(nodes, label, fill) = node(
  enclose: nodes, fill: fill, stroke: none, inset: 10pt, corner-radius: 6pt)
#let group-label(pos, body, name: none) = node(pos, name: name, stroke: none, inset: 2pt,
  text(size: 12pt, weight: "bold", fill: muted, body))

#align(center + horizon, diagram(
  spacing: (0.9cm, 0.8cm),
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  group((<spec>, <step>, <sdk>, <l1>), none, accent.lighten(88%)),
  group-label((0, -0.8), name: <l1>)[In Rocq: proved],
  group-label((2, 0.25))[On the build machine],
  group-label((4.2, -0.8), name: <l3>)[On the device],
  box-node((0, 0), name: <spec>)[*Specification* \ theorems on `step`],
  box-node((0, 1), name: <step>)[*Application* \ `step : State × Event` \ `→ State × list Effect`],
  box-node((0, 2), name: <sdk>)[*Formal SDK* \ events, effects, axioms],

  group((<scm>, <comp>), none, luma(240)),
  box-node((1.4, 1), name: <scm>)[Extracted \ Scheme],
  box-node((2.6, 1), name: <comp>)[*Encore compiler*],

  group((<vm>, <drv>, <ext>, <l3>), none, luma(240)),
  box-node((4.2, 1), name: <vm>, fill: accent, stroke: none)[#text(fill: white)[#text(weight: "bold")[Encore VM] \ runs `step`]],
  box-node((4.2, 0), name: <drv>)[Rust driver \ events in, effects out],
  box-node((4.2, 2), name: <ext>)[Host functions \ hash, CRC, crypto],

  edge(<spec>, <step>, "-", stroke: (dash: "dashed")),
  edge(<sdk>, <step>, "-", stroke: (dash: "dashed")),
  edge(<step>, <scm>, "-|>", label: text(size: 11pt)[extraction], label-side: left),
  edge(<scm>, <comp>, "-|>"),
  edge(<comp>, <vm>, "-|>", label: text(size: 11pt)[bytecode], label-side: left),
  edge(<drv>, <vm>, "<|-|>"),
  edge(<ext>, <vm>, "<|-|>"),
))
#v(0.2em)
#align(center, note[Placeholder until the reference diagram is dropped in.])

== Maximise the pure core

#align(center, text(size: 22pt)[`step : State × Event → State × list Effect`])
#v(0.3em)
- The whole application is one pure function: a state and an event in, the
  next state and a list of effects out
- Parsing, policy, state machines, storage layout: all under `step`
- Costly pure functions (hashes, checksums, signatures) are *axiomatised* and
  provided by the host, often by a hardware accelerator
- Proofs are invariants over `step`: what holds before an event holds after it

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
    - the Encore compiler and VM
    - the Rust compiler
    - host functions behind the axioms
    - the driver: events in, effects out
  ],
)
#v(0.5em)
#text(size: 17pt, fill: muted)[The trusted part changes only when new hardware actions or host functions are added.]

= Encore

== Compiler

#let stage(body, sub) = align(center, {
  text(size: 15pt, weight: "bold", body)
  linebreak()
  text(size: 11pt, fill: muted, sub)
})

#align(center + horizon, diagram(
  spacing: (0.7cm, 1cm),
  node-shape: rect,
  node-stroke: 0.8pt + luma(60),
  node-inset: 8pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,
  node((0, 0), name: <a>, stage[Extracted \ Scheme][from Rocq]),
  node((1, 0), name: <b>, stage[Uncurry][one call per \ function, not \ per argument]),
  node((2, 0), name: <c>, stage[Continuations][every call \ becomes a jump]),
  node((3, 0), name: <d>, stage[Simplify][inline, fold, \ drop dead code]),
  node((4, 0), name: <e>, stage[Registers][name every \ intermediate value]),
  node((5, 0), name: <f>, fill: accent, stroke: none, text(size: 15pt, fill: white, weight: "bold")[Bytecode]),
  edge(<a>, <b>, "-|>"),
  edge(<b>, <c>, "-|>"),
  edge(<c>, <d>, "-|>"),
  edge(<d>, <c>, "-|>", bend: 40deg, label: text(size: 11pt)[until nothing changes], label-side: left),
  edge(<d>, <e>, "-|>"),
  edge(<e>, <f>, "-|>"),
))
#v(0.6em)
- *Continuations*: each function receives "what to do next" as an argument
  and never returns, so the program needs *no call stack*
- Rocq's extracted code is already curried and close to this form: the
  rewrite is cheap and its result is small

== Virtual machine

A fixed memory area and nothing else: `no_std` Rust, its own garbage collector.

- No call stack: memory use is bounded by the heap, *not by recursion depth*
- 256 registers; values packed in 32 bits: integers, closures, constructors, bytes
- Garbage collector finds live data from the registers alone, and runs only when the heap is full
- The Rust driver calls `step` with typed values and receives the effects;
  axiomatised functions are host functions the program calls

= Experimental setup

== Research questions

#v(0.5em)
#{
  set text(size: 19pt)
  grid(
    columns: (auto, 1fr),
    column-gutter: 0.8cm,
    row-gutter: 1cm,
    text(weight: "bold", fill: accent)[RQ1], [*Feasibility* — Can Rocq-extracted code run unmodified within the 50 KB of a secure element, and produce correct results?],
    text(weight: "bold", fill: accent)[RQ2], [*Memory* — How much RAM does each approach need, and how does it grow with the input size?],
    text(weight: "bold", fill: accent)[RQ3], [*Performance* — How much slower is Encore than compiled code, and where does the time go?],
  )
}

== Compared systems

#simple-table((auto, 1fr, 1fr, 1fr), size: 15pt,
  [], [*Encore*], [*CertiRocq*], [*Rust*],
  [Role], [system under study], [closest verified competitor], [performance ceiling, output oracle],
  [Source], [the proved Rocq code], [the same Rocq code], [hand-written, idiomatic],
  [Compiled to], [Encore bytecode, interpreted], [C (verified chain), then native code], [native code],
  [Memory], [fixed heap, garbage collected], [arena, garbage collected; recursion on the C stack], [static buffers only],
  [Trusted], [extraction, compiler, VM], [C compiler, runtime], [everything: nothing is proved],
)
#v(0.3em)
#note[Integers: both Rocq variants map Rocq's `nat` to machine integers, the same unproven assumption.]

== Custom dataset: eight representative firmware workloads

#text(size: 15pt)[Each is a `step` function whose bug would be a security hole or a field failure, with one property proved in Rocq, run at 3–4 input sizes N.]
#v(0.2em)
#{
  set text(size: 13pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  table(
    columns: (auto, auto, 1fr, auto),
    align: left + horizon,
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 7pt, y: 4pt),
    table.header([], [Workload], [What it does], [N]),
    [W1], [Smart-card command parser], [decodes a command sent to a bank card or SIM, and its nested fields], [5 → 261 bytes],
    [W2], [Transaction decoder], [decodes an Ethereum transaction so a hardware wallet can show what the user signs], [0 → 260 bytes],
    [W3], [Signing policy], [checks a requested signing key against a list of allowed rules], [1 → 64 rules],
    [W4], [PIN counter], [checks PINs, locks after 3 wrong tries, unlocks with a recovery code], [1 → 1000 commands],
    [W5], [Firmware update], [switches between two firmware copies, refuses old versions, survives power cuts], [10 → 1000 events],
    [W6], [Serial framing], [encodes then decodes a packet so it can be sent byte by byte on a wire], [16 → 1024 bytes],
    [W7], [Credential store], [stores login keys (passkeys) in a balanced search tree], [10 → 500 entries],
    [W8], [Checksums], [computes two error-detecting codes (CRC) over a data block: pure arithmetic, the worst case for an interpreter], [16 → 1024 bytes],
  )
}

== Methodology

- *Platform*: emulated ARM Cortex-M3 (QEMU), RAM budget fixed at *50 KiB*
- *Same harness*: one Rust driver feeds the same inputs to all three variants
- *Correctness*: every output is hashed and compared with the Rust one
- *Time*: instructions executed per run, counted exactly by the emulator
  (deterministic; cycles need real boards)
- *Memory*: RAM needed in all, statics + stack + the smallest heap or arena
  with which the run still succeeds, found by binary search

= Results

== RQ1: Feasibility

#fit-table(workloads)
#v(0.3em)
#text(size: 15pt)[
  Encore completes *every input size of every workload*, with the same output as Rust.
  Every CertiRocq failure is a *stack overflow*: its recursion uses the C call stack,
  whose depth grows with N. Encore has no call stack.
]

== RQ2: Memory

#text(size: 14pt)[RAM needed in all (KiB): statics + stack + the smallest heap or arena that passes.]
#v(0.1em)
#ram-table(workloads)
#v(0.2em)
#text(size: 14pt)[
  Encore needs less RAM than CertiRocq wherever both run (1.7–7× less), and
  stays within 38 KiB at the largest sizes. Rust needs almost none: its buffers are static.
]

== RQ3: Performance — the cost

#slowdown-table(workloads)
#v(0.3em)
#text(size: 15pt)[
  Encore executes 2–10× more instructions than CertiRocq and 10–2,200× more
  than hand-written Rust. The worst case is pure arithmetic (W8), where Rust does
  one table lookup per byte.
]

== RQ3: Performance — where the time goes

#text(size: 14pt)[Largest input size. Slowdown vs Rust = bytecode operations per Rust instruction × instructions per operation.]
#v(0.1em)
#breakdown-table(workloads)
#v(0.2em)
#text(size: 13pt)[
  *Interpretation* costs a steady 30 or so instructions per bytecode operation: this is
  the main gap with CertiRocq, which runs native code. *Functional code* executes
  more operations than Rust, most on arithmetic (W8). The *garbage collector* takes
  0–22% of VM time (bar: 0–25%); while it runs the program is stopped, at most
  about 300 k instructions, some 5 ms at 60 MHz.
]

= Conclusion

== Takeaways

- *RQ1*: Rocq-extracted code runs unmodified within 50 KiB on all eight
  workloads; CertiRocq overflows its stack on the largest inputs
- *RQ2*: Encore needs 1.7–7× less RAM than CertiRocq, and its needs do not
  depend on recursion depth
- *RQ3*: the price is time: 2–10× CertiRocq, 10–2,200× hand-written Rust,
  mostly from interpretation
- *The architecture scales*: the proved `step` grows with the application,
  the trusted part does not

== Next steps

- *Prove the optimizer*: show each simplification preserves the program's
  meaning, CompCert style
- *Compile to native code* ahead of time: remove the interpretation cost
- *Verify the VM*: prove the Rust interpreter implements the bytecode semantics
- *Measure on real boards*: cycles, GC pauses in time, proof effort
