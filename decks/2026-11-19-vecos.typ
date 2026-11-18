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
  author: grid(
    columns: 2,
    column-gutter: 1.5cm,
    row-gutter: 0.35em,
    [*Valentin Bergeron*], [*Karolina Gorna*],
    text(size: 0.85em)[Independent researcher], text(size: 0.85em)[Télécom Paris and Ledger Donjon, Paris, France],
  ),
  date: datetime(year: 2026, month: 11, day: 19),
  slug: "2026-11-19-vecos",
  section-header: true,
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
#let partial = text(fill: muted, weight: "bold")[–]
// The slide headers show the section, so a slide that needs its own name
// states it at the top.
#let kicker(body) = block(below: 0.6em, text(size: 18pt, weight: "bold", fill: accent, body))

// Results snapshot: encore-benchmarks main, 2026-11-04 (CertiRocq timed with
// a 36 KiB arena, RAM needs from minheap.jsonl).
#let vb = json("/data/bench-vecos.json")

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

== The question

#hero[Can the extracted program *itself* run on the chip?]

== The target: 50 KiB of RAM

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  simple-table((auto, 1fr),
    [], [ST33J2M0 secure element],
    [CPU], [ARM Cortex-M, Thumb-2],
    [Flash], [2 MiB],
    [RAM], [*50 KiB*],
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
  [Path], [Runtime it needs], [No OS], [Fits\ 50 KiB], [Verified\ compiler], [Status on a Cortex-M],
  [*Lean 4* → C], [C++ library, reference counting, threads, hosted IO], no, no, no,
    [ESP32 port needs a patched C++ library and 384 KiB of RAM],
  [*Rocq → OCaml*], [generational GC, C library and maths library], no, no, no,
    [native port needs assembly patches, linker script, library stubs],
  [*OCaml VM* (OMicroB)], [small bytecode VM], yes, yes, no,
    [AVR and PIC32 only; Cortex-M0 port unmerged],
  [*CertiRocq* → C], [GC-aware heap, C call stack for recursion], yes, partial, partial,
    [runs after patching its runtime; deep recursion overflows the stack],
  [*Rocq → Scheme*], [a small Scheme runtime], yes, partial, no,
    [needs a runtime that fits: next table],
)
#v(0.3em)
#note[#yes yes · #no no · #partial partly. CertiRocq is the closest verified competitor. Scheme extraction is the only path whose runtime we can make fit: Encore is that runtime.]

== Scheme runtimes for the extracted code

#simple-table((auto, 1fr, 1fr, 1fr), size: 15pt,
  [], [Chibi Scheme], [Ribbit], [*Encore*],
  [Model], [interpreter, in C], [compact VM, in C], [compiler + VM, in Rust],
  [Program on the device], [source text, re-read at every boot], [bytecode], [bytecode],
  [Runs Rocq-extracted Scheme], [#yes], [#no lacks quasiquote], [#yes],
  [Fits 256 KiB of flash], [#no], [#yes], [#yes],
  [Fits 50 KiB of RAM], [#no], [#yes], [#yes],
  [Memory model], [C stack + GC], [static heap + GC], [no call stack, fixed heap + GC],
  [Ran bare-metal in our tests], [#no too large], [hand-written code only], [#yes all 8 workloads],
)
#v(0.3em)
#note[Chibi is too large; Ribbit fits but cannot compile what Rocq extracts. Encore is the only one that does both.]

= Approach

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

== Overview

// Reference diagram (draw.io), redrawn here: the compilation chain from
// Rocq down to bytecode, and how it sits on the device.
#let green = (fill: rgb("#d5e8d4"), stroke: 0.8pt + rgb("#82b366"))
#let blue = (fill: rgb("#dae8fc"), stroke: 0.8pt + rgb("#6c8ebf"))
#let red = (fill: rgb("#f8cecc"), stroke: 0.8pt + rgb("#b85450"))
#let grey = (fill: luma(244), stroke: 0.8pt + luma(110))
#let stepbox(pos, name, style, body, width: 5.4cm) = node(pos, name: name,
  fill: style.fill, stroke: style.stroke, corner-radius: 4pt, inset: 6pt,
  box(width: width, align(center, text(size: 13pt, body))))
#let label(pos, name, body) = node(pos, name: name, stroke: none, inset: 2pt, text(size: 13pt, body))
#let frame(name, nodes, style) = node(name: name, enclose: nodes,
  fill: style.fill, stroke: style.stroke, corner-radius: 6pt, inset: 8pt)

#align(center + horizon, diagram(
  spacing: (0.6cm, 0.45cm),
  edge-stroke: 0.9pt + black,
  mark-scale: 80%,

  // At build time, on the developer's machine.
  frame(<build-time>, (<rocq>, <comp>, <build>, <bt-l>), (fill: white, stroke: (paint: luma(110), thickness: 0.8pt, dash: "dashed"))),
  stepbox((0, 0), <rocq>, green)[Rocq \ (Gallina code)],
  stepbox((0, 1), <scm>, green)[Scheme code],
  stepbox((0, 2), <comp>, (fill: white, stroke: 0.8pt + black))[#text(weight: "bold", fill: black)[Encore compiler]],
  stepbox((1, 2), <build>, red, width: 2.6cm)[`build.rs`],
  label((1, -0.75), <bt-l>, text(weight: "bold", fill: black)[At build time]),

  // On the device: nested frames, drawn first so the boxes sit on top.
  frame(<os>, (<host>, <os-l>), grey),
  frame(<host>, (<vm>, <main>, <host-l>), red),
  frame(<vm>, (<bc>, <vm-l>), blue),

  stepbox((0, 3.7), <bc>, green, width: 4.2cm)[Bytecode],
  label((0, 4.45), <vm-l>, align(center)[#text(weight: "bold", fill: black)[Encore VM] \ (a library of the Rust application)]),
  stepbox((1, 4.05), <main>, red, width: 5.6cm)[
    #box(fill: luma(246), inset: 5pt, text(size: 10pt)[```rust
encore_heap!(HEAP, 40_000);
let mut vm = boot(HEAP())?;
```]) \
    `main.rs`],
  label((0.5, 5.25), <host-l>)[#text(weight: "bold", fill: black)[Host] (Rust application)],
  label((0.5, 6.3), <os-l>, text(weight: "bold", fill: black)[Microcontroller]),

  edge(<rocq>, <scm>, "-|>", label: text(size: 11pt)[extraction], label-side: left),
  edge(<scm>, <comp>, "-|>"),
  edge(<build>, <comp>, "-|>", stroke: (dash: "dashed"), label: text(size: 11pt)[runs], label-side: right),
  edge(<comp>, <bc>, "-|>"),
))

== Virtual machine

#kicker[Encore VM: four design choices]
#v(0.4em)
#{
  set text(size: 20pt)
  grid(
    columns: (auto, 1fr),
    column-gutter: 0.7cm,
    row-gutter: 0.9cm,
    text(weight: "bold", fill: accent)[1], [*No call stack*: the program is compiled to CPS, every call is a jump],
    text(weight: "bold", fill: accent)[2], [*One word per value*: every value is a single 32-bit word],
    text(weight: "bold", fill: accent)[3], [*Fixed heap, its own GC*: no `malloc`, no OS],
    text(weight: "bold", fill: accent)[4], [*Typed host interface*: Rust calls the program and provides the axioms],
  )
}

== Compiler

#kicker[1 · No call stack: compiling to CPS]
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
  node((2, 0), name: <c>, stage[CPS][continuation-passing \ style: every call \ becomes a jump]),
  node((3, 0), name: <d>, stage[CPS optimizer][inline, fold, \ drop dead code]),
  node((4, 0), name: <e>, stage[Registers][name every \ intermediate value]),
  node((5, 0), name: <f>, fill: accent, stroke: none, text(size: 15pt, fill: white, weight: "bold")[Bytecode]),
  edge(<a>, <b>, "-|>"),
  edge(<b>, <c>, "-|>"),
  edge(<c>, <d>, "-|>"),
  edge(<d>, <d>, "-|>", bend: -130deg, loop-angle: -90deg),
  edge(<d>, <e>, "-|>"),
  edge(<e>, <f>, "-|>"),
))
#v(0.6em)
- *Continuation-passing style (CPS)*: each function receives "what to do next" as an argument
  and never returns, so the program needs *no call stack*
- Rocq's extracted code is already curried and close to CPS: the
  rewrite is cheap and its result is small

== Value representation

#kicker[2 · One word per value]
// A 32-bit word as a strip of fields: (body, bits, fill).
#let vr-w = 0.62cm
#let vr-heap = rgb("#fde6d2")
#let vr-code = rgb("#dfe0fb")
#let vr-num = rgb("#fdf8d0")
#let vr-tag = luma(224)
#let vr-bits(..fields) = grid(
  columns: fields.pos().map(f => f.at(1) * vr-w),
  stroke: 0.8pt + black,
  inset: (x: 3pt, y: 6pt),
  align: center + horizon,
  ..fields.pos().map(f => grid.cell(fill: f.at(2, default: white), text(size: 15pt, f.at(0)))),
)
#let vr-tag-f(n) = ([#raw(n)], 8, vr-tag)
#let vr-unused = ([–], 8)
#let vr-group(body) = grid.cell(colspan: 2, align: left, inset: (top: 4pt, bottom: 0pt),
  text(size: 16pt, weight: "bold", fill: black, body))

#align(center, text(size: 16pt, grid(
  columns: (auto, 32 * vr-w),
  column-gutter: 0.5cm,
  row-gutter: 4pt,
  align: (right + horizon, center + horizon),
  [], grid(
    columns: (8 * vr-w,) * 4 + (0pt,),
    align: left,
    ..(31, 24, 16, 8).map(i => text(size: 12pt, fill: muted, str(i))),
    place(right, dx: 0pt, text(size: 12pt, fill: muted, "0")),
  ),
  vr-group[Values (registers, globals, fields)],
  [Integer], vr-bits(([signed integer, 24 bits], 24, vr-num), vr-tag-f("04")),
  [Function], vr-bits(([code address], 16, vr-code), vr-unused, vr-tag-f("05")),
  [Closure], vr-bits(([heap address], 16, vr-heap), vr-unused, vr-tag-f("00")),
  [Constructor], vr-bits(([heap address or `NULL`], 16, vr-heap), ([tag], 8), vr-tag-f("01")),
  [Bytes], vr-bits(([heap address], 16, vr-heap), vr-unused, vr-tag-f("06")),
  vr-group[Headers (first words of a heap object)],
  [GC header], vr-bits(([forwarding address], 16, vr-heap), ([mark, size], 8, vr-num), vr-tag-f("03")),
  [Closure header], vr-bits(([code address], 16, vr-code), ([`env_len`], 8, vr-num), vr-tag-f("02")),
  [Bytes header], vr-bits(([byte length, 24 bits], 24, vr-num), vr-tag-f("07")),
)))

== Garbage collector

#kicker[3 · Fixed heap, its own garbage collector]
#let cell-strip(..cells) = grid(
  columns: cells.pos().map(c => c.at(1)),
  stroke: 0.8pt + black,
  inset: (x: 6pt, y: 9pt),
  align: center + horizon,
  ..cells.pos().map(c => grid.cell(fill: c.at(2, default: none), text(size: 15pt, c.at(0)))),
)
#v(0.3em)
#align(center)[
  #text(size: 14pt, fill: muted)[One arena handed over by the host (`encore_heap!(HEAP, 40_000)`)]
  #v(-0.3em)
  #cell-strip(
    ([heap, allocated upwards #h(1fr) →], 10cm, rgb("#fde6d2")),
    ([free], 5cm),
    ([globals], 3cm, luma(224)),
  )
]
#v(0.5em)
- *Bump allocation*: allocating is moving a pointer
- *Collects only when the heap is full*, in place: mark, compute new addresses,
  update pointers, slide objects down
- *Roots are the registers and globals*: with no call stack, there is no stack to scan
- Memory use is bounded by the arena, whatever the recursion depth

== Host interface

#kicker[4 · Typed host interface]
#let code-panel(caption, body) = block(width: 100%, fill: luma(244), inset: 10pt, radius: 3pt, {
  text(size: 12pt, fill: muted, caption)
  v(-0.2em)
  text(size: 12pt, body)
})
#grid(
  columns: (1fr, 1.1fr),
  column-gutter: 0.7cm,
  align: top,
  code-panel([Rust host calls the proved program (W1)])[
```rust
encore_program!(env!("OUT_DIR"));
encore_heap!(HEAP, config::HEAP_BYTES);

fn run(vm: &mut Vm, n: u32)
    -> Result<VmList<i32>, ExternError> {
    vm.call_global(funcs::RUN, (n as i32,))
}
```
  ],
  code-panel([A Rocq parameter becomes a host function])[
```scheme
;; extracted Scheme, from ExtrEncoreInput
(define input_byte (extern (slot 0) i))
```
```rust
fn input_byte(vm: &mut Vm, arg: Value)
    -> Result<Value, ExternError> {
    let i = vm.ctor_field(arg, 0).int_value()?;
    /* byte i of the current command */
}
vm.register_extern(0, input_byte);
```
  ],
)
#v(0.4em)
#text(size: 16pt)[
  `funcs::RUN` and the constructor tags are generated with the bytecode: a type
  mismatch is an `Err`, not a crash, and host and program cannot drift apart.
]

= Experimental setup

== Research questions

#v(0.5em)
#{
  set text(size: 19pt)
  grid(
    columns: (auto, 1fr),
    column-gutter: 0.8cm,
    row-gutter: 1cm,
    text(weight: "bold", fill: accent)[RQ1], [*Feasibility* — Can Rocq-extracted code run unmodified within the 50 KiB of a secure element, and produce correct results?],
    text(weight: "bold", fill: accent)[RQ2], [*Memory* — How much RAM does each approach need, and how does it grow with the input size?],
    text(weight: "bold", fill: accent)[RQ3], [*Performance* — How much slower is Encore than compiled code, and where does the time go?],
  )
}

== Compared systems

#v(0.3em)
- *Encore*, the system under study: the proved Rocq code, compiled to Encore
  bytecode and interpreted; fixed heap, garbage collected
- *CertiRocq*, the closest verified competitor: the same Rocq code, compiled
  through a verified chain to C, then to native code; garbage collected arena,
  recursion on the C stack
- *Rust*, the performance ceiling and output oracle: hand-written idiomatic
  code, native; static buffers only, nothing proved
#v(0.5em)
#note[Integers: both Rocq variants map Rocq's `nat` to machine integers.]

== Adapting CertiRocq

#kicker[Adapting CertiRocq to a bare-metal Cortex-M]
#simple-table((auto, 0.7fr, 1.3fr), size: 16pt,
  [], [Out of the box], [What we did],
  [*Integers*], [`nat` stays unary (Peano)],
    [map `nat` to 31-bit machine integers and `Nat.*` to C functions (`BenchNat.v`), through an erasure pass we must trust],
  [*Memory*], [a GC that expects a hosted `malloc`],
    [bump allocator over a fixed arena; 32-bit ARM settings; nursery size made configurable],
  [*Recursion*], [direct-style C: recursion uses the C stack],
    [a stack guard aborts the run cleanly instead of overwriting the arena; `-cps` cannot be combined with the integer mapping in this release],
)

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
- *CertiRocq* is timed with a 36 KiB arena: the one size at which every case
  it can run passes; its instruction counts do not depend on the arena size

= Results

== RQ1: Feasibility

#kicker[RQ1 · Feasibility]
#fit-table(workloads, data: vb)
#v(0.3em)
#text(size: 15pt)[
  Encore completes *every input size of every workload*, with the same output as Rust.
  Every CertiRocq failure is a *stack overflow*: its recursion uses the C call stack,
  whose depth grows with N. Encore has no call stack.
]

== RQ2: Memory

#kicker[RQ2 · Memory]
#text(size: 14pt)[RAM needed in all (KiB): statics + stack + the smallest heap or arena that passes.]
#v(0.1em)
#ram-table(workloads, data: vb)
#v(0.2em)
#text(size: 14pt)[
  Encore needs less RAM than CertiRocq wherever both run (1.7–7× less), and
  stays within 38 KiB at the largest sizes. Rust needs almost none: its buffers are static.
]

== RQ3: Performance — the cost

#kicker[RQ3 · Performance: the cost]
#slowdown-table(workloads, data: vb)
#v(0.3em)
#text(size: 15pt)[
  Encore executes 2–10× more instructions than CertiRocq and 10–2,200× more
  than hand-written Rust. The worst case is pure arithmetic (W8), where Rust does
  one table lookup per byte.
]

== RQ3: Performance — where the time goes

#kicker[RQ3 · Performance: where the time goes]
#text(size: 14pt)[Largest input size. Total slowdown = work (bytecode operations per Rust instruction) × interpretation (instructions per bytecode operation).]
#v(0.1em)
#breakdown-table(workloads, data: vb)
#v(0.2em)
#text(size: 15pt)[
  *Interpretation* costs a steady 30 or so instructions per bytecode operation.
  *Functional code* executes more operations than Rust, up to 60–70 per Rust
  instruction (W1, W8): both factors weigh on the largest slowdowns. The *garbage collector*
  takes at most 22% of VM time.
]

= Conclusion

== Takeaways

- *RQ1*: Rocq-extracted code runs unmodified within 50 KiB on all eight
  workloads; CertiRocq overflows its stack on the largest inputs
- *RQ2*: Encore needs 1.7–7× less RAM than CertiRocq, and its needs do not
  depend on recursion depth
- *RQ3*: the price is time: 2–10× CertiRocq, 10–2,200× hand-written Rust,
  from interpretation and from the extra operations of functional code

== Next steps

- *Prove the optimizer*: show each simplification preserves the program's
  meaning, CompCert style
- *Compile to native code* ahead of time: remove the interpretation cost
- *Verify the VM*: prove the Rust interpreter implements the bytecode semantics
- *Measure on real boards*: cycles, GC pauses in time, proof effort
