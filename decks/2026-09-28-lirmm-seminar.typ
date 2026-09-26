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

#let logo(file, height: 2cm) = image("/assets/logos/" + file, height: height)
// An alternative's slide: its logo in the top-right corner, then the points.
#let logo-slide(file, body, height: 1.6cm) = {
  place(top + right, dy: -0.4cm, logo(file, height: height))
  block(width: 78%, body)
}

== \

#hero[Standard extraction targets for proof assistants \ need runtimes too large for embedded devices.]

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

= A firmware architecture for proof

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

== The approach

+ *Fix the constraint first*: 50 KB of RAM, no hosted runtime
+ *Survey the extraction paths*: Lean 4, OCaml, CertiRocq, Scheme
+ *Pick Scheme extraction*: compact, untyped, no mandatory runtime
+ *Try existing Scheme runtimes on the target* before writing one: Chibi, Ribbit
+ *Build a purpose-built runtime* for the Scheme that Rocq actually emits

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
    #text(size: 14pt, fill: muted)[Gallina (W4, PIN state machine)]
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

== The name

The name comes from the VM's single calling opcode: `ENCORE`.

- Every function call sets the callee and continuation registers and jumps
- There is no call stack
- In French, *encore* means *again*, *still*, *more*

= Encore: compiler and VM

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

#let pipe(..steps) = {
  set text(size: 15pt)
  let arrow = text(fill: accent, size: 12pt)[↓]
  stack(dir: ttb, spacing: 6pt, ..steps.pos().map(s => align(center, s)).intersperse(align(center, arrow)))
}
#let variant-card(name, role) = block(
  width: 100%, inset: 14pt, radius: 4pt, stroke: 0.5pt + luma(200),
)[
  #align(center)[
    #text(size: 26pt, weight: "bold", fill: accent)[#name] \
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

#place(top + right, dy: -0.4cm, logo("certirocq.svg", height: 1.4cm))
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

#place(top + right, dy: -0.4cm, logo("rust.svg", height: 1.4cm))
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
