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
  #link("https://github.com/lampepfl/tacit")[TACIT] (Odersky et al., CAIS 2026) is a safety harness
  for AI agents: *the agent writes Scala 3 code instead of calling tools*.]
]
#v(0.2em)
#grid(
  columns: (1fr, 1.1fr),
  column-gutter: 0.8cm,
  text(size: 12pt)[
```scala
import language.experimental.captureChecking

class Net extends caps.SharedCapability:
  def post(url: String, body: String): Unit

def audit(msg: String)(using net: Net) =
  net.post("/audit", msg)

// f must be pure: it captures no capability
def validate(f: String -> Boolean) = ...

validate(s => s.nonEmpty)         // ok
validate(s => { audit(s); true }) // error
// String ->{net} Boolean is not
// String -> Boolean
```
  ],
  align(horizon, image("/assets/diagrams/tacit-overview.png", width: 100%)),
)
#place(bottom + left, text(size: 10pt, fill: luma(110))[
  M. Odersky, Y. Zhao, Y. Xu, O. Bračevac, C. N. Pham.
  _Securing Agents With Tracked Capabilities._ Proc. ACM Conference on AI and
  Agentic Systems (CAIS), 2026, pp. 812–838.
  #link("https://doi.org/10.1145/3786335.3813127")[doi:10.1145/3786335.3813127].
  Figure from the TACIT repository.
])

== CUE as an ontology

#logo("cue.svg")
#block(width: 85%)[
  #text(size: 16pt)[#link("https://cuelang.org")[CUE] is a constraint language
  where *types and values are the same thing*: from `string` to `"EUR"`, every
  value is an element of one lattice, ordered by instance-of (#sym.subset.eq.sq).]
]
#v(0.1em)

// Hasse diagram of a fragment of the value lattice: top, types, constraints,
// concrete values, bottom. Coordinates are node centers.
#let hasse = {
  let nodes = (
    top: ((5.2, 0.0), [`_` #sym.top]),
    str: ((2.6, 1.3), `string`),
    int: ((7.8, 1.3), `int`),
    cur: ((2.6, 2.6), `#Currency`),
    nat: ((7.8, 2.6), `int & >=0`),
    eur: ((1.0, 3.9), `"EUR"`),
    usd: ((2.6, 3.9), `"USD"`),
    chf: ((4.2, 3.9), `"CHF"`),
    n300: ((6.9, 3.9), `300`),
    n500: ((8.7, 3.9), `500`),
    bot: ((5.2, 5.2), [`_|_` #sym.bot]),
  )
  let edges = (
    ("top", "str"), ("top", "int"), ("str", "cur"), ("int", "nat"),
    ("cur", "eur"), ("cur", "usd"), ("cur", "chf"),
    ("nat", "n300"), ("nat", "n500"),
    ("eur", "bot"), ("usd", "bot"), ("chf", "bot"),
    ("n300", "bot"), ("n500", "bot"),
  )
  let pt(k, dy) = {
    let (x, y) = nodes.at(k).at(0)
    (x * 1.15cm, y * 1.15cm + dy)
  }
  box(width: 12cm, height: 6.4cm, {
    for (hi, lo) in edges {
      place(line(start: pt(hi, 0.32cm), end: pt(lo, -0.32cm),
        stroke: 0.8pt + luma(150)))
    }
    for (k, v) in nodes {
      let (x, y) = v.at(0)
      place(dx: x * 1.15cm - 1.4cm, dy: y * 1.15cm - 0.3cm,
        box(width: 2.8cm, height: 0.6cm,
          align(center + horizon, text(size: 13pt, v.at(1)))))
    }
  })
}

#grid(
  columns: (1fr, 12cm),
  column-gutter: 0.8cm,
  text(size: 13.5pt)[
    - *Unification `&` is the meet* #sym.inter.sq: commutative, associative,
      idempotent. Definitions compose from any number of files, in any
      order, with no precedence rules
    - `_` is the top #sym.top, `_|_` the bottom #sym.bot: an error is a meet
      that reaches #sym.bot, as `"EUR" & "CHF"` does
    - Disjunction `|` is the join; `*` marks a default
    - `cue vet` checks that data #sym.subset.eq.sq schema
    #v(0.2em)
    #text(size: 15pt, weight: "bold", fill: rgb("#B5303B"))[Speed]
    #v(-0.4em)
    - Not Turing-complete: evaluation always terminates
    - Meets never backtrack; only disjunctions branch
    - cue v0.17.1, 4 vCPU: one file in 13 ms, startup included;
      100 000 transfers streamed in 16 s
  ],
  align(center + horizon, hasse),
)
#place(bottom + left, text(size: 10pt, fill: luma(110))[
  CUE's value model descends from typed feature structures:
  B. Carpenter. _The Logic of Typed Feature Structures._ Cambridge University
  Press, 1992. See also
  #link("https://cuelang.org/docs/concept/the-logic-of-cue/")[_The Logic of CUE_].
])

== CUE: a complete example

#text(size: 15pt)[A schema, a policy written by another team, and data: three
sources, one meet.]

#let file(name) = text(size: 11pt, fill: luma(110))[#name]

#grid(
  columns: (1fr, 1.2fr),
  column-gutter: 0.8cm,
  [
    #file(`schema.cue`)
    #v(-0.5em)
    #text(size: 11pt)[
```cue
#Currency: "EUR" | "USD" | "CHF"
#Account: {
  iban:     =~"^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$"
  currency: #Currency
  balance:  int & >=0
}
#Transfer: {
  from:   #Account
  to:     #Account & {currency: from.currency}
  amount: int & >0 & <=from.balance
  fee:    *0 | int & >=0
}
transfers: [...#Transfer]
```
    ]
    #v(-0.2em)
    #file([`policy.cue`: refines, never overrides])
    #v(-0.5em)
    #text(size: 11pt)[
```cue
#Transfer: {
  amount: <=10_000
  if amount > 5_000 {fee: 15}
}
```
    ]
  ],
  [
    #file(`transfers.yaml`)
    #v(-0.5em)
    #text(size: 11pt)[
```yaml
transfers:
- from: {iban: FR7630006000011, currency: EUR, balance: 8000}
  to:   {iban: DE8937040044053, currency: EUR, balance: 0}
  amount: 6000
- from: {iban: FR7630006000011, currency: EUR, balance: 300}
  to:   {iban: CH9300762011623, currency: CHF, balance: 0}
  amount: 500
```
    ]
    #v(-0.2em)
    #file([`cue vet -c schema.cue policy.cue transfers.yaml` (abridged)])
    #v(-0.5em)
    #text(size: 11pt, fill: rgb("#B5303B"))[
```
transfers.1.to.currency: conflicting values "EUR" and "CHF"
transfers.1.amount: invalid value 500 (out of bound <=300)
```
    ]
    #v(-0.2em)
    #text(size: 11pt)[The first transfer passes, and `cue export` gives it
    `fee: 15`: the policy computed it.]
    #v(0.1em)
    #grid(
      columns: (auto, 1fr),
      column-gutter: 0.5cm,
      align: horizon,
      tiaoma.qrcode(base-url + "play/", width: 2.4cm),
      text(size: 12pt)[
        *Try it live:* this example, evaluated in the browser by CUE
        compiled to WebAssembly \
        #text(size: 10pt, fill: luma(110))[#link(base-url + "play/")]
      ],
    )
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
  align: top,
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
