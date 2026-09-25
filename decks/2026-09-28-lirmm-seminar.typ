#import "/template/lib.typ": *
#import "/template/bench.typ": *

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

== \

#hero[Standard extraction targets for proof assistants \ need runtimes too large for embedded devices.]

= State of the art

== Why verify firmware logic

- Generated code is getting cheap: *more code to review*, same assurance level
- seL4 showed machine-checked correctness at the systems level; firmware
  wants the same rigour
- Formal specifications scale: a generated implementation is checked against
  theorem statements
- But extracted code needs a runtime, and the usual answer is to *translate
  the specification by hand* into the host language, weakening the link to
  the proof

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
  [Path], [Runtime needs], [`no_std`], [Cortex-M], [Proof kept],
  [*Lean 4*], [C++ library, ref-counting + cycle GC, tasks, hosted IO], [no], [no], [none],
  [*OCaml / OMicroB*], [generational GC, libc/libm; OMicroB: AVR and PIC32 only], [no], [no], [none],
  [*CertiRocq*], [GC-aware heap; Peano `nat`, no machine arithmetic], [partial], [partial], [compiler chain],
  [*Scheme*], [compact semantics, no mandatory hosted runtime], [yes], [yes], [full],
)
#v(0.3em)
#text(size: 15pt, fill: muted)[
  Verified compilers (CompCert, CakeML) show the strongest story is possible;
  small Scheme systems (PICOBIT, Ribbit) show Scheme fits a microcontroller.
]

= Why Encore

== The approach

+ *Fix the constraint first*: 50 KB of RAM, no hosted runtime
+ *Survey the extraction paths*: Lean 4 and OCaml fall on their runtimes;
  CertiRocq only for bounded allocation
+ *Pick Scheme extraction*: compact, untyped, no mandatory runtime
+ *Try existing Scheme runtimes on the target* before writing one
+ *Build a purpose-built runtime* for the Scheme that Rocq actually emits

== Existing Scheme runtimes, on the target

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

== The key insight: CPS

Rocq-extracted Scheme is *heavily curried* and already close to CPS form.

- The CPS rewrite removes the call stack *semantically*; a register VM
  removes it *physically*: no hidden control flow, no frames
- Every intermediate value is named: register allocation is natural
- GC roots are trivial: every live register is a root, and CPS keeps them
  contiguous, so no stack scanning
- Only the macros of `macros_extr.scm` are supported, as core primitives,
  plus `define-extern` for host functions

== The name

The name comes from the VM's single calling opcode: `ENCORE`.

- Every function call sets the callee and continuation registers and jumps
- There is no call stack
- In French, *encore* means *again*, *still*, *more*

= Architecture

== Firmware as a state transition

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
    - Encore's Scheme frontend, compiler and VM
    - the Rust compiler
    - host callbacks for admitted axioms
    - event poller and effect interpreter
  ],
)
#v(0.5em)
#text(size: 17pt, fill: muted)[The trusted boundary changes only when new hardware actions, externs or primitives are added.]

== Pipeline

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

== Compiler pipeline

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  [
    - *DS uncurry* — flattens curried lambdas
    - *DSI resolve* — named binders to de Bruijn indices
    - *CPS transform* — continuation-passing style
  ],
  [
    - *CPS optimizer* — inlining, hoisting, CSE, contification
    - *ASM resolve* — closure conversion, register assignment
    - *ASM peephole* + *ASM emit* — ENCR binary output
  ],
)

== The VM

The VM requires only a fixed arena: `#![no_std]`, brings its own GC.

- Packed 32-bit values: closures, constructors, integers, byte strings
- 256-register file, bump-allocation heap arena
- Mark-compact garbage collector
- Single calling convention: `ENCORE` opcode, set callee and continuation,
  jump without returning

== Host–VM interface

The VM is a library inside a Rust application that keeps control of memory and I/O.

- *Two entry points*: call a global or closure with typed arguments; register
  externs the VM reaches through `EXTERN`
- `#[derive(ValueEncode, ValueDecode)]` map Rust types to constructor tags
- `VmList<T>`, `VmBytes`: lazy traversal, bounded copies into caller buffers
- `build.rs` runs the compiler: `bytecode.bin` and `bindings.rs` (function
  and constructor constants), so host and bytecode cannot drift apart

= Experiment plan

== Goal

Show, on realistic firmware workloads, what logic proved in Rocq costs when
Encore runs it, against CertiRocq and against hand-written Rust. The paper
covers flash, heap and build time on seven micro-benchmarks; four gaps remain:

- *No execution speed*
- *No Rust baseline*
- *No realistic workload*: the paper's signing app is a toy
- *A handicapped CertiRocq*: collector disabled, Peano integers

== Research questions

#simple-table((auto, auto, 1fr), size: 16pt,
  [], [Question], [Asked as],
  [Q1], [*Feasibility*], [which workloads fit in 50 KB of RAM and 256 KB of flash, for each toolchain?],
  [Q2], [*Cost*], [overhead in flash, RAM, cycles and worst-case latency against Rust `no_std`; where does VM + bytecode flash cross native code?],
  [Q3], [*Predictability*], [do the GC and CPS give a bounded latency, compatible with soft real time (APDU, USB)?],
  [Q4], [*Value of the proof*], [which property is proved, with how many lines, and how much remains trusted?],
  [Q5], [*Integration effort*], [size of the unverified Rust layer, number of externs, ease of evolving the logic],
)

== Systems compared

#let pipe(..steps) = {
  set text(size: 15pt)
  let arrow = text(fill: accent, size: 12pt)[↓]
  stack(dir: ttb, spacing: 6pt, ..steps.pos().map(s => align(center, s)).intersperse(align(center, arrow)))
}
#let variant-card(name, role) = block(
  width: 100%, inset: 14pt, radius: 4pt, stroke: 0.5pt + luma(200),
)[
  #align(center)[
    #text(size: 20pt, weight: "bold", fill: accent)[#name] \
    #text(size: 14pt, fill: muted)[#role]
  ]
]
// One slide per variant: its pipeline on the left, what matters on the right.
#let variant-slide(role, pipeline, body) = {
  text(size: 20pt, fill: muted, role)
  v(0.4em)
  grid(
    columns: (0.9fr, 1.1fr),
    column-gutter: 1cm,
    block(width: 100%, inset: 14pt, radius: 4pt, stroke: 0.5pt + luma(200), pipeline),
    { set text(size: 17pt); body },
  )
}

#v(1fr)
#grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  column-gutter: 0.6cm,
  variant-card([Encore], [system under study]),
  variant-card([CertiRocq], [closest verified competitor]),
  variant-card([Rust no_std], [performance ceiling, output oracle]),
  variant-card(text(fill: muted)[Verified Rust], [Kani or Verus: planned, not measured]),
)
#v(1fr)
#align(center, text(size: 14pt, fill: muted)[
  All linked against the same Rust I/O layer, so only the logic changes ·
  verified Rust proves the Rust, not the Gallina: a different question
])

== Encore

#variant-slide([system under study], pipe(
  [Gallina],
  [Rocq extraction → Scheme],
  [`encore compile` → bytecode],
  [`encore_vm`, `no_std` Rust],
  [mark-compact GC, 32 KiB heap],
))[
  - Extraction directives from `ExtrEncore.v`: `nat` becomes a 24-bit VM
    integer, arithmetic maps to VM primitives
  - CPS optimizer on
  - The collector runs only when the heap is full
  - Trusted: extraction, the compiler, the VM and the `nat` mapping
    (none of them verified)
]

== CertiRocq

#variant-slide([closest verified competitor], pipe(
  [Gallina],
  [CertiRocq → Clight],
  [`arm-none-eabi-gcc -Os`],
  [CertiRocq runtime],
  [generational GC, 20 KiB arena],
))[
  - *Same Gallina* as Encore, CertiRocq v0.9.1
  - `nat` mapped to 31-bit machine integers: the same unproven assumption as Encore
  - Real GC on a static arena, not the paper's "abort" mode
  - Compiler largely verified down to Clight; gcc, the runtime and the
    `nat` mapping are trusted
  - A case that does not fit the RAM budget is reported as ✗ arena / ✗ stack
]

== Rust no_std

#variant-slide([performance ceiling, output oracle], pipe(
  [hand-written, not from the Gallina],
  [`rustc`, `opt-level = "s"`, LTO],
  [no allocator, static buffers],
  text(fill: muted)[no proof],
))[
  - Idiomatic firmware Rust: does not copy the functional structure
  - *Performance ceiling*: what the logic costs without proof
  - *Output oracle*: every Encore and CertiRocq output is hashed and compared with Rust's
    before any number is kept
  - Memory-safe, but none of the workload properties are proved
]

== Secondary variants

- *Encore AOT*: the Thumb-2 backend, once it exists. Tells whether the gap
  comes from interpretation or from the CPS and GC model
- *Rust with `alloc`*: a fixed-heap allocator and the functional style
  (`Box`, linked lists). Separates the cost of allocation from the cost of the VM
- *Encore without the CPS optimizer*: isolates its contribution

== Metrics

#simple-table((auto, auto, 1fr), size: 14pt,
  [Metric], [Unit], [How],
  [Flash], [bytes], [section sizes; runtime separate from the program],
  [Static RAM, peak stack], [bytes], [`.data` + `.bss`; stack painting],
  [Peak heap], [bytes], [heap high-water mark, and the smallest heap that still passes],
  [Cycles], [CPU cycles], [DWT `CYCCNT` around each call, median and p99],
  [Worst-case latency, GC count], [µs, count], [max GC pause and max `step` duration],
  [Energy], [µJ / op], [Otii Arc or PPK2, optional],
  [Build time], [s], [wall clock, 5 runs],
  [Proof effort, TCB], [lines], [spec, proof, program; unverified Rust + VM + compiler + externs],
)

== Protocol

+ *Same Gallina* for Encore and CertiRocq; same calling interface and input
  vectors for every variant
+ *Oracle*: Rust's output is the reference; a divergence is a bug, fixed
  before measuring
+ *Size N* for each workload, to plot curves, not points
+ *RAM budget at link time*: 50 KB (ST33J2M0), then 64 KB (ST33K1M5); what
  does not fit fails, which answers Q1
+ *Every run recorded* in `benchmarks.jsonl` with commit, variant, board and N

== Eight firmware workloads

#text(size: 15pt)[Each is a `step` function whose bug is a security hole or a field failure.]
#v(0.2em)
#simple-table((auto, auto, 1fr, auto), size: 13pt,
  [], [Workload], [Property proved], [N],
  [W1], [APDU + BER-TLV parser], [an accepted APDU is exactly the encoding of what was parsed], [5 → 261 B],
  [W2], [Ethereum RLP decoder], [what is displayed is what is signed], [0 → 260 B],
  [W3], [BIP32 path policy], [only compliant paths, amounts and destinations are signed], [1 → 64 rules],
  [W4], [PIN state machine], [the retry counter never goes up without the PIN or PUK], [1 → 1000 APDUs],
  [W5], [A/B firmware update], [a power cut at any step still boots a valid, non-rolled-back image], [10 → 1000 events],
  [W6], [COBS framing], [`decode (encode l) = Some l`, no zero byte], [16 → 1024 B],
  [W7], [FIDO credential store], [red-black invariants; `lookup` after `insert`], [10 → 500 entries],
  [W8], [CRC-16 and CRC-32], [equals the polynomial definition], [16 → 1024 B],
)

== Why these workloads

- *W1, W2, W6 parse untrusted input*, the first source of vulnerabilities in
  secure elements. Rust brings memory safety, not the round trip or the
  display/signature correspondence
- *W3, W4, W5 are security policies*: the bugs live in rare event sequences,
  which fuzzing reaches poorly
- *W7* takes the paper's red-black tree to a real use and 500 entries
- *W8 is deliberately unfavourable* to Encore: pure arithmetic, kept in the
  main results

== Platforms

#simple-table((auto, auto, 1fr), size: 15pt,
  [Platform], [Core], [Role],
  [QEMU `lm3s6965evb`], [Cortex-M3], [continuous integration, exact instruction counts],
  [Cortex-M33 board (STM32U5)], [Cortex-M33], [main platform: cycles, GC pauses, energy],
  [Cortex-M4 board (nRF52840)], [Cortex-M4], [sensitivity across cores],
  [ST33 (Ledger Flex)], [Cortex-M35P], [final validation on W2 and W4],
)
#v(0.3em)
#text(size: 15pt, fill: muted)[Fixed clock, caches and flash prefetch frozen, same gcc and Rust 1.88 everywhere.]

== Threats to validity

- *`nat` as machine integers*: faster but unproven, wrong beyond 2#super[23]:
  Encore and CertiRocq use the same representation
- *CertiRocq's handicap*: its real GC on a static arena, not the paper's abort mode
- *Quality of the Rust baseline*: a weak baseline flatters Encore; reviewed and published
- *Workload selection*: W8, unfavourable, stays in the main results
- *Trusted base*: Encore's compiler and VM are not verified, unlike most of CertiRocq
- *QEMU counts instructions, not cycles*: speed conclusions need the boards

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
