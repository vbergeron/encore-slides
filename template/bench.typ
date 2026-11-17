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

// Recap across workloads: peak RAM of each variant over the sizes it ran
// (KiB, static RAM or heap/arena high-water + stack), and Encore's garbage
// collector: most collections in one run, share of VM time spent collecting
// over the sizes that collect, longest pause and most bytes live after a collection.
#let memory-table(workloads) = {
  let fmt(x) = str(calc.round(x, digits: if x < 10 { 1 } else { 0 }))
  let range(xs, unit: "", strong: false) = if xs.len() == 0 { text(fill: muted)[–] } else {
    let lo = fmt(calc.min(..xs))
    let hi = fmt(calc.max(..xs))
    let s = (if lo == hi { lo } else { lo + " – " + hi }) + unit
    if strong { text(fill: accent, weight: "bold", s) } else { s }
  }
  let kib(cells) = cells.map(c => c.ram / 1024)
  let ran(cell) = cell != none and "insns" in cell
  set text(size: 15pt)
  show table.cell.where(y: 0): set text(weight: "bold")
  show table.cell.where(y: 1): set text(weight: "bold", fill: muted, size: 13pt)
  table(
    columns: (auto, 1fr, auto, auto, auto, auto, auto, auto, auto),
    align: (col, row) => if col < 2 { left + horizon } else { center + horizon },
    stroke: (x, y) => (
      bottom: if y == 1 { 0.8pt + black } else if y > 1 { 0.3pt + luma(220) } else { none },
      left: if x in (2, 5) and y > 0 { 0.3pt + luma(200) } else { none },
    ),
    inset: (x: 7pt, y: 5pt),
    table.header(
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Workload],
      table.cell(colspan: 3, align: center)[Peak RAM (KiB)],
      table.cell(colspan: 4, align: center)[Encore GC],
      [Rust], [CertiRocq], [Encore], [collections], [time], [max pause], [live KiB],
    ),
    ..workloads.map(((id, key, name)) => {
      let cases = bench.at(key)
      let has-c = cases.any(c => "C" in c)
      let gcs = cases.filter(c => ran(c.E)).map(c => c.E.gc)
      (
        id, name,
        range(kib(cases.map(c => c.R).filter(ran))),
        if has-c { range(kib(cases.map(c => c.at("C", default: none)).filter(ran))) } else { text(fill: muted)[n/a] },
        range(kib(cases.map(c => c.E).filter(ran)), strong: true),
        str(calc.max(..gcs.map(g => g.count))),
        range(gcs.filter(g => g.count > 0).map(g => g.pct), unit: " %", strong: true),
        fmt(calc.max(..gcs.map(g => g.pause_max)) / 1000) + " k",
        fmt(calc.max(..gcs.map(g => g.live)) / 1024),
      )
    }).flatten(),
  )
}

// ---------------------------------------------------------------------------
// Evaluation tables of the VeCOS deck: one research question each, one value
// per cell (no ranges), every column labelled with what it measures. Each
// takes `data:`, a snapshot written by scripts/bench-data.py (the VeCOS deck
// passes data/bench-vecos.json: CertiRocq timed with a 36 KiB arena).

#let _ran(cell) = cell != none and "insns" in cell
#let _fmt(x) = str(calc.round(x, digits: if x < 10 { 1 } else { 0 }))
#let _cross(why) = text(fill: accent, weight: "bold")[✗ #why]
#let _na(body) = text(fill: muted, size: 12pt, body)

#let _eval-table(columns, groups, sub, rows, size: 14pt) = {
  set text(size: size)
  show table.cell.where(y: 0): set text(weight: "bold")
  show table.cell.where(y: 1): set text(weight: "bold", fill: muted, size: size - 2pt)
  let starts = ()
  let x = 2
  for (_, span) in groups { starts.push(x); x += span }
  table(
    columns: columns,
    align: (col, row) => if col < 2 { left + horizon } else { center + horizon },
    stroke: (x, y) => (
      bottom: if y == 1 { 0.8pt + black } else if y > 1 { 0.3pt + luma(220) } else { none },
      left: if x in starts and y > 0 { 0.3pt + luma(200) } else { none },
    ),
    inset: (x: 7pt, y: 4.5pt),
    table.header(
      table.cell(rowspan: 2)[], table.cell(rowspan: 2, align: left + bottom)[Workload],
      ..groups.map(((label, span)) => table.cell(colspan: span, align: center, label)),
      ..sub,
    ),
    ..rows.flatten(),
  )
}

// RQ1: how many of the input sizes each variant completes within 50 KiB,
// whatever its heap or arena size (minheap search), output checked against Rust.
#let fit-table(workloads, data: bench) = _eval-table(
  (auto, 1fr, auto, auto, auto),
  (([Input sizes completed within 50 KiB], 3),),
  ([Rust], [CertiRocq], [Encore]),
  workloads.map(((id, key, name)) => {
    let cases = data.at(key)
    let n = cases.len()
    let built = cases.any(c => "C" in c)
    let c-ok = cases.filter(c => "need" in c.at("C", default: (:))).len()
    (
      id, name,
      [#cases.filter(c => _ran(c.R)).len() / #n],
      if built [#c-ok / #n] else { _na[not built] },
      text(fill: accent, weight: "bold")[#cases.filter(c => "need" in c.E).len() / #n],
    )
  }),
)

// RQ2: RAM needed in all (statics + smallest heap or arena that passes + stack),
// at the smallest and the largest input size.
#let ram-table(workloads, data: bench) = {
  let kib(b) = _fmt(b / 1024)
  let need(c, v) = {
    let cell = c.at(v, default: none)
    if cell == none { _na[n/b] }
    else if v == "R" { kib(cell.ram) }
    else if "need" in cell { if v == "E" { text(fill: accent, weight: "bold", kib(cell.need)) } else { kib(cell.need) } }
    else { _cross(cell.at("need_fail", default: "")) }
  }
  _eval-table(
    (auto, 1fr, auto, auto, auto, auto, auto, auto, auto, auto),
    (([Smallest N], 4), ([Largest N], 4)),
    ([N], [Rust], [CertiRocq], [Encore], [N], [Rust], [CertiRocq], [Encore]),
    workloads.map(((id, key, name)) => {
      let cases = data.at(key)
      let lo = cases.first()
      let hi = cases.last()
      (id, name,
        text(fill: muted, str(lo.n)), need(lo, "R"), need(lo, "C"), need(lo, "E"),
        text(fill: muted, str(hi.n)), need(hi, "R"), need(hi, "C"), need(hi, "E"))
    }),
  )
}

// RQ3: Encore's instructions per run divided by Rust's and CertiRocq's,
// at the smallest input size and at the largest one the other variant completes
// (CertiRocq timing rows at the snapshot's arena size).
#let slowdown-table(workloads, data: bench) = {
  let x(r) = text(fill: accent, weight: "bold", "×" + _fmt(r))
  let pair(cases, v) = {
    let both = cases.filter(c => _ran(c.at(v, default: none)))
    if both.len() == 0 { return (_na[not built], _na[–]) }
    let lo = both.first()
    let hi = both.last()
    (x(lo.E.insns / lo.at(v).insns), [#x(hi.E.insns / hi.at(v).insns) #text(size: 11pt, fill: muted)[(N=#hi.n)]])
  }
  _eval-table(
    (auto, 1fr, auto, auto, auto, auto),
    (([Encore ÷ Rust (instructions)], 2), ([Encore ÷ CertiRocq (instructions)], 2)),
    ([smallest N], [largest N], [smallest N], [largest common N]),
    workloads.map(((id, key, name)) => {
      let cases = data.at(key)
      (id, name, ..pair(cases, "R"), ..pair(cases, "C"))
    }),
  )
}

// RQ3: where Encore's time goes, at the largest input size. The slowdown
// against Rust factors into how many bytecode operations the functional
// program executes per Rust instruction, times the cost of one operation;
// then the share of VM time spent in the garbage collector.
#let breakdown-table(workloads, data: bench) = _eval-table(
  (auto, 1fr, auto, auto, auto, auto),
  (([Slowdown vs Rust], 3), ([GC overhead], 1)),
  ([work (ops / Rust insn)], [interpretation (insns / op)], [total (×)], [% of VM time]),
  workloads.map(((id, key, name)) => {
    let c = data.at(key).last()
    let gc = c.E.gc
    (id, name,
      _fmt(c.E.vm_ops / c.R.insns), _fmt(c.E.insns / c.E.vm_ops),
      text(fill: accent, weight: "bold", "×" + _fmt(c.E.insns / c.R.insns)),
      _fmt(100 * gc.pause_total / gc.run_time) + " %")
  }),
)
