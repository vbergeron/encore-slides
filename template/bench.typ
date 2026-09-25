// Benchmark result slides: tables built from data/bench.json, which
// scripts/bench-data.py extracts from encore-benchmarks' results.

#let bench = json("/data/bench.json")

#let accent = rgb("#B5303B")
#let muted = luma(120)

// 817 · 148k · 1.83M
#let fmt-insns(x) = {
  if x < 1000 { str(x) }
  else if x < 1000000 { str(calc.round(x / 1000, digits: if x < 10000 { 1 } else { 0 })) + "k" }
  else { str(calc.round(x / 1000000, digits: if x < 10000000 { 2 } else { 1 })) + "M" }
}

#let fmt-kib(bytes) = {
  let k = bytes / 1024
  str(calc.round(k, digits: if k < 10 { 2 } else { 1 }))
}

#let fmt-ratio(a, b) = {
  let r = a / b
  "×" + str(calc.round(r, digits: if r < 10 { 1 } else { 0 }))
}

// A case that did not run: why, in the table.
#let fail-cell(why) = text(fill: muted, size: 0.85em)[✗ #why]

// One line per N: instructions per run and peak RAM for R, C and E, and the
// slowdown of E against R and C. `c: false` for a workload without a C
// variant. An E heap peak at the heap budget means the collector ran (it
// only collects a full heap): it is marked with a dagger.
#let bench-table(workload, n-label: [N], c: true) = {
  let cases = bench.at(workload)
  let na = text(fill: muted)[n/a]
  let insns(cell) = if cell == none { na } else if "fail" in cell { fail-cell(cell.fail) } else { fmt-insns(cell.insns) }
  let ram(cell) = if cell == none { na } else if "fail" in cell { fail-cell(cell.fail) } else { fmt-kib(cell.ram) }
  let e-ram(cell) = {
    let full = cell.heap >= cell.heap_budget * 0.97
    [#fmt-kib(cell.ram)#if full { super[†] }]
  }
  let ratio(e, other) = if other == none or "fail" in other { text(fill: muted)[–] } else {
    text(fill: accent, weight: "bold", fmt-ratio(e.insns, other.insns))
  }

  set text(size: 15pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  show table.cell.where(y: 1): set text(weight: "bold", fill: muted, size: 13pt)
  table(
    columns: (auto, 1fr, 1fr, 1fr, auto, auto, 1fr, 1fr, 1fr),
    align: (col, row) => if col == 0 { left + horizon } else { right + horizon },
    stroke: (x, y) => (
      bottom: if y == 1 { 0.8pt + black } else if y > 1 { 0.3pt + luma(220) } else { none },
      left: if x in (1, 4, 6) and y > 0 { 0.3pt + luma(200) } else { none },
    ),
    inset: (x: 8pt, y: 6pt),
    table.header(
      table.cell(rowspan: 2, align: left + bottom, n-label),
      table.cell(colspan: 3, align: center)[Instructions / run],
      table.cell(colspan: 2, align: center)[E slowdown],
      table.cell(colspan: 3, align: center)[Peak RAM (KiB)],
      [R], [C], [E], [vs R], [vs C], [R], [C], [E],
    ),
    ..cases.map(case => {
      let r = case.at("R", default: none)
      let cc = if c { case.at("C", default: none) } else { none }
      let e = case.E
      (
        str(case.n),
        insns(r), insns(cc), insns(e),
        ratio(e, r), ratio(e, cc),
        ram(r), ram(cc), e-ram(e),
      )
    }).flatten(),
  )
}

// The one sentence to remember about what is proved.
#let theorem(name, body) = block(
  width: 100%,
  inset: (x: 14pt, y: 10pt),
  radius: 4pt,
  fill: accent.lighten(90%),
  stroke: (left: 3pt + accent),
)[
  #text(size: 15pt)[#text(fill: accent, weight: "bold")[Proved]#h(0.6em)#raw(name)#h(0.6em)#body]
]

#let bench-note(body) = text(size: 11pt, fill: muted, body)

// A workload slide: one line of context, the table, the theorem, notes.
#let workload-slide(workload, intro, n-label: [N], c: true, thm: (), note: none) = {
  text(size: 17pt, intro)
  v(0.2em)
  bench-table(workload, n-label: n-label, c: c)
  v(0.1em)
  theorem(..thm)
  if note != none {
    v(-0.3em)
    bench-note(note)
  }
}

// Recap across workloads: E's slowdown range against R and C over the sizes
// where both ran, and how many sizes each variant fits in the RAM budget.
#let recap-table(workloads) = {
  let range(xs) = if xs.len() == 0 { text(fill: muted)[–] } else {
    let lo = calc.min(..xs)
    let hi = calc.max(..xs)
    let f(r) = str(calc.round(r, digits: if r < 10 { 1 } else { 0 }))
    text(fill: accent, weight: "bold", "×" + if f(lo) == f(hi) { f(lo) } else { f(lo) + " – " + f(hi) })
  }
  let ran(cell) = cell != none and "insns" in cell
  set text(size: 15pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  table(
    columns: (auto, 1fr, auto, auto, auto, auto),
    align: (col, row) => if col < 2 { left + horizon } else { center + horizon },
    stroke: (x, y) => (bottom: if y == 0 { 0.8pt + black } else { 0.3pt + luma(220) }),
    inset: (x: 8pt, y: 5pt),
    table.header([], [Workload], [E vs R], [E vs C], [Fits: E], [Fits: C]),
    ..workloads.map(((id, key, name)) => {
      let cases = bench.at(key)
      let has-c = cases.any(c => "C" in c)
      (
        id, name,
        range(cases.filter(c => ran(c.at("R", default: none))).map(c => c.E.insns / c.R.insns)),
        range(cases.filter(c => ran(c.at("C", default: none))).map(c => c.E.insns / c.C.insns)),
        [#cases.filter(c => ran(c.E)).len() / #cases.len()],
        if has-c [#cases.filter(c => ran(c.at("C", default: none))).len() / #cases.len()] else { text(fill: muted)[n/a] },
      )
    }).flatten(),
  )
}
