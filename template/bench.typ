// Benchmark results: the evaluation's tables and chart, built from
// data/bench.json, which scripts/bench-data.py extracts from
// encore-benchmarks' results.

#let bench = json("/data/bench.json")

#let accent = rgb("#B5303B")
#let muted = luma(120)

#let ran(cell) = cell != none and "insns" in cell
#let fmt(x) = str(calc.round(x, digits: if x < 10 { 1 } else { 0 }))
#let dash = text(fill: muted)[–]

// "lo – hi" over a list of numbers, or one number when they round the same.
#let span(xs, unit: "", prefix: "", strong: false) = if xs.len() == 0 { dash } else {
  let lo = fmt(calc.min(..xs))
  let hi = fmt(calc.max(..xs))
  let s = prefix + (if lo == hi { lo } else { lo + " – " + hi }) + unit
  if strong { text(fill: accent, weight: "bold", s) } else { s }
}

// The shared look of the result tables: a two-row header (a group, then its
// columns), thin rules, and a vertical rule before each column in `groups`.
#let result-table(columns, groups, header, left-cols: 2, inset-y: 5pt, ..rows) = {
  set text(size: 14pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  show table.cell.where(y: 1): set text(weight: "bold", fill: muted, size: 12pt)
  table(
    columns: columns,
    align: (col, row) => if col < left-cols { left + horizon } else { center + horizon },
    stroke: (x, y) => (
      bottom: if y == 1 { 0.8pt + black } else if y > 1 { 0.3pt + luma(220) } else { none },
      left: if x in groups and y > 0 { 0.3pt + luma(200) } else { none },
    ),
    inset: (x: 7pt, y: inset-y),
    table.header(..header),
    ..rows,
  )
}

// RQ1: how many of the input sizes each variant runs within the RAM budget,
// and why the others fail.
#let fit-table(workloads) = {
  let count(cases, v) = {
    let cells = cases.map(c => c.at(v, default: none))
    if cells.all(c => c == none) { return text(fill: muted, size: 12pt)[not built] }
    let ok = cells.filter(ran).len()
    let fails = cells.filter(c => c != none and "fail" in c).map(c => c.fail)
    let s = [#ok / #cases.len()]
    if ok == cases.len() { text(weight: "bold", s) } else [
      #text(fill: accent, weight: "bold", s)
      #text(size: 11pt, fill: muted)[✗ #fails.dedup().map(f => f + (if fails.filter(g => g == f).len() > 1 { " ×" + str(fails.filter(g => g == f).len()) } else { "" })).join(", ")]
    ]
  }
  result-table(
    (auto, 1fr, auto, auto, auto, auto), (2, 3),
    (
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Workload],
      table.cell(rowspan: 2, align: center + bottom)[Sizes N tested],
      table.cell(colspan: 3, align: center)[Sizes that run within 50 KiB of RAM],
      [Rust], [CertiRocq], [Encore],
    ),
    ..workloads.map(((id, key, name)) => {
      let cases = bench.at(key)
      (
        id, name,
        text(size: 12pt)[#cases.len() sizes, #cases.first().n → #cases.last().n],
        count(cases, "R"), count(cases, "C"), count(cases, "E"),
      )
    }).flatten(),
  )
}

// RQ2: Encore's instructions per run divided by the other variant's, from the
// smallest to the largest ratio over the sizes where both ran.
#let slowdown-table(workloads) = {
  let ratios(cases, v) = cases.filter(c => ran(c.E) and ran(c.at(v, default: none))).map(c => c.E.insns / c.at(v).insns)
  result-table(
    (auto, 1fr, auto, auto), (2,),
    (
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Workload],
      table.cell(colspan: 2, align: center)[Encore is slower by (min – max over the sizes N)],
      [than Rust], [than CertiRocq],
    ),
    ..workloads.map(((id, key, name)) => {
      let cases = bench.at(key)
      let c = ratios(cases, "C")
      (
        id, name,
        span(ratios(cases, "R"), prefix: "×", strong: true),
        if cases.any(c => "C" in c) { span(c, prefix: "×", strong: true) } else { text(fill: muted, size: 12pt)[not built] },
      )
    }).flatten(),
  )
}

// RQ3: where Encore's instructions go, at the largest size CertiRocq also runs.
// One bar per workload, CertiRocq's run as the unit: interpreting the
// bytecode, then collecting garbage.
#let time-chart(workloads, unit: 1.05cm) = {
  let interp-c = accent
  let gc-c = rgb("#5b4a8a")
  let c-c = luma(175)
  let bar(w, fill) = box(width: w * unit, height: 0.36cm, fill: fill)
  let rows = workloads.map(((id, key, name)) => {
    let cases = bench.at(key).filter(c => ran(c.E) and ran(c.at("C", default: none)))
    let c = cases.last()
    let e = c.E
    let ratio = e.insns / c.C.insns
    let gc = e.gc.pct / 100
    (
      id, text(size: 12pt)[N = #c.n],
      stack(spacing: 2pt,
        bar(1, c-c),
        stack(dir: ltr, bar(ratio * (1 - gc), interp-c), bar(ratio * gc, gc-c))),
      text(fill: accent, weight: "bold")[×#str(calc.round(ratio, digits: 1))],
      [#fmt(100 * gc) %],
      fmt(e.insns * (1 - gc) / e.vm_ops),
      if "insns_noopt" in e [×#fmt(e.insns_noopt / e.insns)] else { dash },
    )
  })
  let key(fill, body) = box(baseline: 0.05cm, stack(dir: ltr, spacing: 4pt, box(width: 0.42cm, height: 0.42cm, fill: fill), body))
  align(center, text(size: 13pt)[
    #key(c-c)[CertiRocq] #h(1.2em) #key(interp-c)[Encore: interpreting bytecode] #h(1.2em) #key(gc-c)[Encore: collecting garbage]
  ])
  v(-0.2em)
  result-table(
    (auto, auto, 1fr, auto, auto, auto, auto), (3,), left-cols: 3, inset-y: 3pt,
    (
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Size],
      table.cell(rowspan: 2, align: left + bottom)[Instructions per run, CertiRocq = 1],
      table.cell(colspan: 4, align: center)[Encore],
      [÷ CertiRocq], [in GC], [Arm instr. \ per VM instr.], [CPS optimizer \ gain],
    ),
    ..rows.flatten(),
  )
}

// RQ4: peak RAM of each variant over the sizes it ran (KiB: static RAM or
// heap/arena high-water mark, plus stack), and Encore's garbage collector.
#let memory-table(workloads) = {
  let kib(cells) = cells.map(c => c.ram / 1024)
  result-table(
    (auto, 1fr, auto, auto, auto, auto, auto, auto, auto), (2, 5),
    (
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Workload],
      table.cell(colspan: 3, align: center)[Peak RAM, KiB (min – max over the sizes N)],
      table.cell(colspan: 4, align: center)[Encore garbage collector (worst size N)],
      [Rust], [CertiRocq], [Encore], [collections \ per run], [share of \ VM time], [longest pause \ (k instr.)], [live after \ GC (KiB)],
    ),
    ..workloads.map(((id, key, name)) => {
      let cases = bench.at(key)
      let cs = cases.map(c => c.at("C", default: none))
      let c-fails = cs.filter(c => c != none and "fail" in c).len()
      let gcs = cases.filter(c => ran(c.E)).map(c => c.E.gc)
      (
        id, name,
        span(kib(cases.map(c => c.R).filter(ran))),
        if cs.all(c => c == none) { text(fill: muted, size: 12pt)[not built] } else [
          #span(kib(cs.filter(ran)))
          #if c-fails > 0 { text(size: 11pt, fill: accent)[(✗ on #c-fails)] }
        ],
        span(kib(cases.map(c => c.E).filter(ran)), strong: true),
        str(calc.max(..gcs.map(g => g.count))),
        text(fill: accent, weight: "bold", fmt(calc.max(..gcs.map(g => g.pct))) + " %"),
        fmt(calc.max(..gcs.map(g => g.pause_max)) / 1000),
        fmt(calc.max(..gcs.map(g => g.live)) / 1024),
      )
    }).flatten(),
  )
}
