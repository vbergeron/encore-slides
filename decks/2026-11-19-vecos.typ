#import "/template/lib.typ": *
#import "/template/bench.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

// VeCOS 2026 — conference talk for "From Rocq to Metal". A ~20 min cut of
// the LIRMM seminar (decks/2026-09-28-lirmm-seminar.typ): the approach, Encore
// at one level of detail, then the evaluation.

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
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 8pt, y: 6pt),
    ..cells,
  )
}

#let workloads = (
  ([W1], "w1_apdu", [APDU + BER-TLV parser]),
  ([W2], "w2_rlp", [Ethereum RLP decoder]),
  ([W3], "w3_policy", [BIP32 path policy]),
  ([W4], "w4_pin", [PIN state machine]),
  ([W5], "w5_update", [A/B firmware update]),
  ([W6], "w6_cobs", [COBS framing]),
  ([W7], "w7_store", [FIDO credential store]),
  ([W8], "w8_crc", [CRC-16 and CRC-32]),
)

= Motivation

== Proved logic, unproved runtime

- Secure elements and hardware wallets run small, critical logic: APDU
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
    [], [ST33J2M0],
    [ISA], [ARM + Thumb-2],
    [Flash], [2 MB],
    [RAM], [*50 KB*],
    [Clock], [60 MHz],
    [Cache], [none],
  ),
  [
    - RAM is the binding constraint
    - No libc, no libm, no Rust `std`
    - Applications often ship with *no runtime at all*
  ],
)

== Extraction paths

#simple-table((auto, 1fr, auto, auto),
  [Path], [Runtime needs], [`no_std`], [Verified compilation],
  [*Lean 4*], [C++ library, ref-counting + cycle GC, hosted IO], [no], [no],
  [*Rocq → OCaml*], [generational GC, libc/libm], [no], [no],
  [*CertiRocq*], [GC-aware heap, C stack for recursion], [partial], [Gallina → Clight, largely],
  [*Rocq → Scheme*], [a small runtime, to find or to build], [yes], [no],
)
#v(0.3em)
#text(size: 15pt, fill: muted)[
  CertiRocq is the closest verified competitor; Scheme extraction is the only
  path whose runtime we can make fit. Encore is that runtime.
]

= Approach

== Maximise the pure core

#align(center, text(size: 22pt)[`step : State × Event → State × list Effect`])
#v(0.3em)
- The whole application is one pure function: a state and an event in, the
  next state and a list of effects out
- Parsing, policy, state machines, storage layout: all Gallina, all under `step`
- Pure but costly functions (hashes, CRCs, MACs) are *axiomatised* and
  realised by host callbacks
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
    - host callbacks for admitted axioms
    - event poller and effect interpreter
  ],
)
#v(0.5em)
#text(size: 17pt, fill: muted)[The trusted boundary changes only when new hardware actions, externs or primitives are added.]

= Encore

== Compiler pipeline

#let ir(name, sub) = grid(
  columns: (1.6cm, 4.4cm),
  column-gutter: 0.3cm,
  align: left + horizon,
  text(size: 18pt, weight: "bold", fill: accent)[#name],
  text(size: 13pt, fill: muted)[#sub],
)
#let pass(body) = text(size: 12pt, body)

#align(center + horizon, diagram(
  spacing: (1.2cm, 0.75cm),
  node-stroke: 0.8pt + luma(60),
  node-inset: 7pt,
  node-corner-radius: 3pt,
  edge-stroke: 0.8pt + luma(60),
  mark-scale: 80%,

  node((1, 0), name: <src>, stroke: none, inset: 2pt, text(size: 14pt)[Scheme extracted from Rocq]),
  node((1, 1), name: <ds>, ir([DS], [direct style, uncurried])),
  node((1, 2), name: <dsi>, ir([DSI], [de Bruijn indexed])),
  node((1, 3), name: <cps>, ir([CPS], [continuation-passing])),
  node((0, 3), name: <opt>, inset: 6pt, align(center, text(size: 13pt)[
    #text(weight: "bold")[CPS optimizer] \
    #text(size: 11pt, fill: muted)[nine passes, \ to a fixpoint]])),
  node((1, 4), name: <asm>, ir([ASM], [registers])),
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

== Why CPS

Rocq-extracted Scheme is *heavily curried* and already close to CPS form.

- The CPS rewrite removes the call stack *semantically*; a register VM
  removes it *physically*: no hidden control flow, no frames
- Every intermediate value is named: register allocation is natural
- GC roots are trivial: every live register is a root, no stack scanning
- Memory use is bounded by the heap, not by recursion depth

== The VM

A fixed arena and nothing else: `#![no_std]` Rust, brings its own GC.

- Packed 32-bit values: closures, constructors, 24-bit integers, byte strings
- 256-register file, bump-allocation heap
- Mark-compact garbage collector, run only when the heap is full
- One calling convention: `ENCORE` sets callee and continuation and jumps,
  never returns
- Host ↔ VM boundary generated from one source: typed values via
  `#[derive(ValueEncode, ValueDecode)]`, externs for axiomatised functions

= Evaluation

== Three ways to ship the same logic

#let variant-card(name, role, body) = block(
  width: 100%, height: 100%, inset: 14pt, radius: 4pt, stroke: 0.5pt + luma(200),
)[
  #align(center)[
    #text(size: 24pt, weight: "bold", fill: accent)[#name] \
    #text(size: 13pt, fill: muted)[#role]
  ]
  #v(0.3em)
  #set text(size: 14pt)
  #body
]

#v(0.5em)
#block(height: 60%, grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 0.8cm,
  variant-card([Encore], [system under study])[
    - Gallina → Scheme → bytecode
    - 32 KiB heap, mark-compact GC
  ],
  variant-card([CertiRocq], [closest verified competitor])[
    - Gallina → Clight, `gcc -Os`
    - 20 KiB arena, generational GC
  ],
  variant-card([Rust no_std], [ceiling and output oracle])[
    - hand-written, `opt-level = "s"`
    - static buffers, no allocator
  ],
))
#v(1fr)
#align(center, text(size: 14pt, fill: muted)[
  Same inputs, same Rust driver and harness, every output checked against Rust ·
  QEMU Cortex-M3, 50 KiB RAM budget · instructions counted per run
])

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

== Instructions across workloads

#recap-table(workloads)
#v(0.3em)
#text(size: 16pt)[
  Encore runs every size of every workload within the 50 KiB budget, including
  the 10 where CertiRocq runs out of arena or stack. The price is instructions:
  2–10× CertiRocq and 10–2,000× hand-written Rust, the worst on pure arithmetic (W8).
]

== Memory and GC across workloads

#memory-table(workloads)
#v(0.3em)
#text(size: 16pt)[
  Encore collects only when the heap is full, so it peaks at its 32 KiB heap
  (40 KiB for W6) plus 5 KiB of stack; what is live after a collection is at most
  28 KiB. Collection costs 3–22% of VM time, with pauses up to 309 k instructions.
]

= Conclusion

== Takeaways

- *Proved logic fits a secure-element budget*: all eight workloads run
  bare-metal on an emulated Cortex-M3 within 50 KiB, where CertiRocq runs out
  of memory on 10 cases
- *The price is instructions*: 2–10× CertiRocq, 10–2,000× hand-written Rust
- *Memory is fixed, not minimal*: a 32–40 KiB heap plus 5 KiB of stack whatever
  the size
- *The architecture scales*: the proved `step` grows with the application,
  the trusted boundary does not

== Next steps

- *Prove the optimizer*: the nine CPS passes, semantics-preserving, CompCert style
- *Ahead-of-time Thumb-2 backend*: separate the cost of interpretation from
  the CPS and GC model
- *Verify the VM* with `rocq-of-rust`: a simulation between the CPS semantics
  and the Rust interpreter
- *Measure on real boards*: cycles, GC pauses in time, proof effort
