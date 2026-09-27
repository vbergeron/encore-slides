#import "/template/lib.typ": *

#show: encore-theme.with(
  title: [From Rocq to Metal],
  subtitle: [Firmware and software applications of formal methods],
  institution: [LIRMM Seminar],
  date: datetime(year: 2026, month: 9, day: 28),
  slug: "2026-09-28-seminar-intro",
)

== This afternoon

#let item(n, title, body) = grid(
  columns: (1.2cm, 1fr),
  column-gutter: 0.4em,
  align: (right + top, left + top),
  text(size: 26pt, weight: "bold", fill: rgb("#B5303B"))[#n],
  [
    #text(size: 20pt, weight: "bold")[#title]
    #v(-0.4em)
    #text(size: 15pt, fill: luma(90))[#body]
  ],
)

#v(0.4em)
#stack(
  spacing: 0.9em,
  item("1", [Formal methods, applied], [
    AI puts pressure on keeping invariants constant and securing evolving
    codebases: how we apply formal methods to industrial goals, and how we
    generate proofs
  ]),
  item("2", [Encore: running Rocq programs on microcontrollers], [
    A compiler and bytecode VM for Rocq programs extracted to Scheme, running
    on bare-metal targets with no operating system
  ]),
  item("3", [Zorya: concolic execution of Go binaries], [
    A concolic execution engine written in Rust, using Ghidra's P-Code as
    intermediate representation and Z3 as solver
  ]),
)

= Formal methods, applied

== The problem: making AI reliable

- AI produces more code, faster, than a team can review
- The system's invariants have to stay constant while the codebase evolves
- Tests and review alone do not scale with generated code
- *Goal:* increase the reliability of AI-assisted development with
  machine-checked constraints

== What we put in place

#let entry(title, body) = [
  #text(size: 19pt, weight: "bold")[#title]
  #v(-0.4em)
  #text(size: 15pt, fill: luma(90))[#body]
]

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1.2cm,
  row-gutter: 1.2em,
  entry([Scala + tacit], [Scala is historically our backend language]),
  entry([CUE as an ontology], [Domain concepts described in CUE]),
  entry([Critical logic in Rocq], [Served by an OCaml + gRPC service]),
  entry([Rocq as a spec], [Data structures designed in Rocq]),
)

#let logo(file, height: 1.6cm) = place(
  top + right, dy: -0.4cm, image("/assets/logos/" + file, height: height),
)

== Scala + TACIT

#logo("scala.svg")
#block(width: 85%)[
  #text(size: 16pt)[Scala is historically our backend language.
  #link("https://github.com/lampepfl/tacit")[TACIT] (EPFL) is a safety harness
  for AI agents: *the agent writes Scala 3 code instead of calling tools*.]
]
#v(0.2em)
#grid(
  columns: (1fr, 1.1fr),
  column-gutter: 0.8cm,
  text(size: 14pt)[
    - Agent code is type-checked with *capture checking* in safe mode
    - Capabilities (files, processes, network) are values in scope:
      code cannot forge them or exceed its budget
    - `Classified` data cannot leak out of pure sub-computations
    - Exposed as an MCP server
  ],
  align(horizon, image("/assets/diagrams/tacit-overview.png", width: 100%)),
)

== CUE as an ontology

#logo("cue.svg")
#block(width: 85%)[
  #text(size: 16pt)[#link("https://cuelang.org")[CUE] is a constraint language
  where *types and values are the same thing*: schemas, constraints and data
  are merged by unification.]
]
#v(0.2em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.8cm,
  text(size: 14pt)[
    - Domain concepts and their constraints are written once, in CUE
    - Unification is order-independent: definitions compose from several
      files without precedence rules
    - `cue vet` checks JSON or YAML data against the definitions
  ],
  text(size: 13pt)[
```cue
#Currency: "EUR" | "USD" | "CHF"

#Account: {
  id:       string & =~"^[A-Z]{2}[0-9]{8}$"
  currency: #Currency
  balance:  int & >=0
}
```
  ],
)

== Rocq

#logo("rocq.svg", height: 1cm)
#block(width: 85%)[
  #text(size: 16pt)[The logic where a mistake is costly is written in Rocq,
  where its properties are proved.]
]
#v(0.4em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 1cm,
  [
    #text(size: 19pt, weight: "bold")[Critical logic]
    #v(-0.3em)
    #text(size: 14pt)[
      - Encoded and proved in Rocq
      - Extracted to OCaml
      - Served to the backend over gRPC
    ]
  ],
  [
    #text(size: 19pt, weight: "bold")[Rocq as a spec]
    #v(-0.3em)
    #text(size: 14pt)[
      - Data structures designed in Rocq
      - Published as a document that references the proofs
    ]
  ],
)

== Boulodrome: Rocq as an MCP server

#text(size: 16pt)[Personal project. An MCP server that gives an AI assistant
interactive access to Rocq through coq-lsp's Petanque API: *theorem proving
becomes a tool-calling loop*.]
#v(0.3em)

#let group(title, body) = [
  #text(size: 16pt, weight: "bold", fill: rgb("#B5303B"))[#title]
  #v(-0.5em)
  #text(size: 13pt)[#body]
]

#grid(
  columns: (1fr, 1.15fr),
  column-gutter: 0.8cm,
  stack(
    spacing: 0.7em,
    group([Explore], [`rocq_file_toc`, `rocq_search`, `rocq_inspect`,
      `rocq_premises`]),
    group([Prove], [`rocq_start_proof`, `rocq_try_tactics` (side-effect
      free), `rocq_run_tactics`, `rocq_goals`, `rocq_undo` to any
      indexed proof state]),
    group([Check], [`rocq_verify`: the file compiles, and every theorem is
      audited with `Print Assumptions` against a list of allowed axioms;
      `rocq_proof_script` returns the committed tactics]),
  ),
  text(size: 11pt)[
#text(size: 13pt, fill: luma(110))[`rocq_verify` output]
```
Verification of Foo.v:
No compile errors.
2 theorem(s)/lemma(s) checked for axioms:
- plus_comm: closed, no axioms
- shady_thm: DEPENDS ON UNLISTED AXIOM(S):
    Classical_Prop.classic : forall P : Prop, P \/ ~ P

NOT VERIFIED: see flagged item(s) above.
```
  ],
)

== Outlook

- *Adaptive scheduler* in cut-free Prolog, designed to be provable with LPTP
- *hallmark*: encoding business rules in Rocq
