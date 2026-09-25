// Benchmark results: the recap table, built from data/bench.json, which
// scripts/bench-data.py extracts from encore-benchmarks' results.

#let bench = json("/data/bench.json")

#let accent = rgb("#B5303B")
#let muted = luma(120)

// Recap across workloads: Encore's slowdown range against Rust and CertiRocq
// over the sizes where both ran, and how many sizes each variant fits in the RAM budget.
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
  show table.cell.where(y: 1): set text(weight: "bold", fill: muted, size: 13pt)
  table(
    columns: (auto, 1fr, auto, auto, auto, auto),
    align: (col, row) => if col < 2 { left + horizon } else { center + horizon },
    stroke: (x, y) => (
      bottom: if y == 1 { 0.8pt + black } else if y > 1 { 0.3pt + luma(220) } else { none },
      left: if x in (2, 4) and y > 0 { 0.3pt + luma(200) } else { none },
    ),
    inset: (x: 8pt, y: 5pt),
    table.header(
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Workload],
      table.cell(colspan: 2, align: center)[Encore slowdown],
      table.cell(colspan: 2, align: center)[Sizes that fit],
      [vs Rust], [vs CertiRocq], [Encore], [CertiRocq],
    ),
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
