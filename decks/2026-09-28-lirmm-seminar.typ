#import "/template/lib.typ": *
#import "/template/bench.typ": *

#show: encore-theme.with(
  title: [Encore],
  subtitle: [A bytecode VM and compiler for Rocq-extracted programs],
  institution: [Encore — LIRMM Seminar],
  date: datetime(year: 2026, month: 9, day: 28),
  slug: "2026-09-28-lirmm-seminar",
  links: (
    (url: "https://github.com/vbergeron/encore", label: "encore"),
    (url: "https://github.com/vbergeron/encore-benchmarks", label: "encore-benchmarks"),
  ),
)

== \

#hero[Rocq extraction produces correct code. \ Running it anywhere below a full Lisp runtime hasn't.]

== The problem

- Rocq's extraction mechanism produces correct-by-construction Scheme code
- Running it anywhere below a full Lisp runtime has historically meant a
  large porting effort
- *Encore fills that gap* — a bytecode interpreter with a built-in GC that
  compiles to a `no_std` Rust crate and links into firmware with a fixed
  heap budget

== The name

The name comes from the VM's single calling opcode: `ENCORE`.

- Every function call sets the callee and continuation registers and jumps
- There is no call stack
- In French, *encore* means *again*, *still*, *more*

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

== encore_vm

The VM requires only a fixed arena: `#![no_std]`, brings its own GC.

- Packed 32-bit values: closures, constructors, integers, byte strings
- 256-register file, bump-allocation heap arena
- Mark-compact garbage collector
- Single calling convention: `ENCORE` opcode, set callee and continuation,
  jump without returning

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

= Results

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

== Quick start

```sh
encore compile scheme extracted.scm --out program.encr
encore run program.encr
```

- `encore disasm` for an interactive bytecode inspector
- `encore compile fleche` for Fleche sources
