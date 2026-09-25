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
  set text(size: 14pt)
  let arrow = text(fill: accent, size: 11pt)[↓]
  stack(dir: ttb, spacing: 5pt, ..steps.pos().map(s => align(center, s)).intersperse(align(center, arrow)))
}
#let variant(letter, name, role, body) = block(
  width: 100%, height: 100%, inset: 12pt, radius: 4pt,
  stroke: 0.5pt + luma(200),
)[
  #text(size: 24pt, weight: "bold", fill: accent)[#letter]#h(0.3em)#text(size: 18pt, weight: "bold")[#name]
  #v(-0.5em)
  #text(size: 13pt, fill: muted)[#role]
  #v(0.3em)
  #body
]

#grid(
  columns: (1fr, 1fr, 1fr),
  rows: 7.6cm,
  column-gutter: 0.6cm,
  variant("E", [Encore], [system under study], pipe(
    [Gallina],
    [Rocq extraction → Scheme],
    [`encore compile` → bytecode],
    [`encore_vm`, `no_std` Rust],
    [mark-compact GC, 32 KiB heap],
  )),
  variant("C", [CertiRocq], [closest verified competitor], pipe(
    [Gallina],
    [CertiRocq → Clight],
    [`arm-none-eabi-gcc -Os`],
    [CertiRocq runtime],
    [generational GC, 20 KiB arena],
  )),
  variant("R", [Rust no_std], [performance ceiling, output oracle], pipe(
    [hand-written, not from the Gallina],
    [`rustc`, `opt-level = "s"`, LTO],
    [no allocator, static buffers],
    text(fill: muted)[no proof],
  )),
)
#v(0.2em)
#align(center, text(size: 13pt, fill: muted)[
  Same inputs, same Rust driver and harness, every output checked against R ·
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

#let legend(minheap) = [
  ✗ arena / ✗ stack: C does not fit the RAM budget ·
  † E heap full, the collector ran#if minheap != none [; smallest heap that passes: #minheap]
]

== W1 · APDU + BER-TLV parser

#workload-slide("w1_apdu", n-label: [APDU (B)],
  [Split an ISO 7816 command APDU, then parse the BER-TLV tree of its data field.],
  thm: ("run_roundtrip", [an accepted APDU is exactly the encoding of what was parsed, and the decoder never runs out of fuel.]),
  note: legend[10.5 KiB],
)

== W2 · Ethereum transaction decoder

#workload-slide("w2_rlp", n-label: [calldata (B)],
  [Strict RLP decoding of a legacy transaction, rendered to the screen the user approves.],
  thm: ("what_you_see_is_what_you_sign", [two accepted payloads that show the same screen are the same bytes.]),
  note: legend[16.75 KiB],
)

== W3 · BIP32 path policy

#workload-slide("w3_policy", n-label: [rules],
  [Check 16 signing requests (path, amount, destination) against the first N rules.],
  thm: ("run_signs_only_compliant", [a request is signed iff some rule allows its path, amount and destination.]),
  note: legend[1 KiB],
)

== W4 · PIN state machine

#workload-slide("w4_pin", n-label: [APDUs],
  [VERIFY, CHANGE, RESET RETRY COUNTER and SELECT over a stream of N commands.],
  thm: ("tries_up_only_with_secret", [the retry counter never goes back up without the correct PIN or PUK.]),
  note: legend(none),
)

== W5 · A/B firmware update

#workload-slide("w5_update", n-label: [events],
  [Download, seal, trial-boot and confirm images, with power cuts between flash writes.],
  thm: ("power_cut_safe", [a cut after any number of writes still boots a valid image, never below the anti-rollback counter.]),
  note: legend[28 KiB],
)

== W6 · COBS framing

#workload-slide("w6_cobs", n-label: [frame (B)],
  [Encode a frame so it contains no zero byte, then decode it back.],
  thm: ("cobs_roundtrip", [`decode (encode l) = Some l`, and the encoding contains no zero.]),
  note: [#legend[32.25 KiB] · E heap is 40 KiB here],
)

== W7 · FIDO credential store

#workload-slide("w7_store", n-label: [entries],
  [Register N credentials in a persistent red-black tree, then answer 32 assertions.],
  thm: ("lookup_insert", [after `insert x v`, `lookup x` finds `v`, every other handle is unchanged, and the tree stays balanced.]),
  note: legend[12.75 KiB],
)

== W8 · CRC-16 and CRC-32

#workload-slide("w8_crc", n-label: [block (B)], c: false,
  [Bit-serial CRCs streamed over a block: pure arithmetic, the least favourable case for a VM.],
  thm: ("crc32_input_correct", [the loop computes the polynomial definition of the CRC, the remainder over GF(2).]),
  note: [No C variant yet · R does one table lookup per byte, E about 1,040 VM instructions per byte · † E heap full, the collector ran; smallest heap that passes: 0.5 KiB],
)

== Quick start

```sh
encore compile scheme extracted.scm --out program.encr
encore run program.encr
```

- `encore disasm` for an interactive bytecode inspector
- `encore compile fleche` for Fleche sources
