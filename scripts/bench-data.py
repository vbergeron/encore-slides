#!/usr/bin/env python3
"""Extract the numbers the decks show from encore-benchmarks' results.

    scripts/bench-data.py ../encore-benchmarks/results > data/bench.json

Reads `benchmarks.jsonl` and `minheap.jsonl` in that directory, on the QEMU
Cortex-M3 board. For every (workload, N) it gives, per variant:

- `insns`: instructions per run (median, latest timing row). E with the
  CPS optimizer on. C with its default 2^10-word nursery (arena = E's
  heap, or 36 KiB where that is a few hundred bytes short), and in
  `insns_min_ram` at the nursery that minimises its RAM (rows labelled
  `c-best-nursery`).
- `ram`: the RAM the case needs in all, in bytes. R: static RAM + peak
  stack. E and C: `minheap`'s `ram_total_bytes`, statics with the smallest
  heap or arena that passes plus the peak stack; for C the best nursery
  of 2^6 to 2^10 words (`nursery`, its log2), for E also `heap`, the
  smallest heap.
- for E, `gc`: the collector on the memory run (collections, share of VM
  time spent collecting, longest pause since boot in instructions, bytes
  live after the latest collection).
- a case that passes at no heap or arena size within the RAM budget is
  `{"fail": "stack" | "arena" | "heap"}`.
"""

import json
import sys
from pathlib import Path

BOARD = "qemu-lm3s6965"
C_DEFAULT_LABELS = ("aligned-budget-all-n", "c-arena-36k")


def rows(path):
    with open(path) as f:
        for line in f:
            if line.strip():
                r = json.loads(line)
                if r["board"] == BOARD:
                    yield r


def why(reason):
    reason = reason or ""
    return "stack" if "stack" in reason else "arena" if "arena" in reason else "heap"


def main(results):
    results = Path(results)

    # minheap: E (optimizer on) by case; C by case and nursery.
    e_ram, c_ram = {}, {}
    for r in rows(results / "minheap.jsonl"):
        key = (r["workload"], r["n"])
        if r["variant"] == "E" and r["build"]["cps_optimize"] == "on":
            e_ram[key] = r
        elif r["variant"] == "C":
            c_ram.setdefault(key, {})[r["build"]["c_log_nursery"]] = r
    c_best = {}
    for key, by_nursery in c_ram.items():
        ok = [(r["ram_total_bytes"], k) for k, r in by_nursery.items() if r["ok"]]
        c_best[key] = min(ok) if ok else None

    timing, memory, c_default, c_min_ram = {}, {}, {}, {}
    for r in rows(results / "benchmarks.jsonl"):
        key = (r["workload"], r["n"])
        v, b = r["variant"], r["build"]
        if v == "E" and b.get("cps_optimize") is not True:
            continue
        if v == "C":
            if not r["ok"]:
                continue
            if r.get("label") in C_DEFAULT_LABELS and b.get("c_log_nursery") == 10:
                c_default[key] = r
            best = c_best.get(key)
            if r.get("label") == "c-best-nursery" and best and b.get("c_log_nursery") == best[1]:
                c_min_ram[key] = r
            continue
        if r["profile"] == "timing":
            timing[(v, key)] = r
        elif r["profile"] == "memory":
            memory[(v, key)] = r

    out = {}
    cases = sorted({k for _, k in timing} | set(e_ram) | set(c_ram), key=lambda k: (k[0], k[1]))
    for key in cases:
        w, n = key
        case = out.setdefault(w, [])
        case.append(entry := {"n": n})

        rt = timing.get(("R", key))
        if rt:
            entry["R"] = {"insns": rt["insns"]["median"], "stack": rt["stack_peak_bytes"],
                          "ram": rt["size"]["ram_static_bytes"] + rt["stack_peak_bytes"]}

        et, em, eh = timing.get(("E", key)), memory.get(("E", key)), e_ram.get(key)
        if eh and not eh["ok"]:
            entry["E"] = {"fail": why(eh.get("reason"))}
        elif et and et["ok"] and eh:
            cell = {"insns": et["insns"]["median"], "stack": eh["stack_peak_bytes"],
                    "heap": eh["min_heap_bytes"], "ram": eh["ram_total_bytes"]}
            if em and em["ok"]:
                gc = em["gc"]
                cell["vm_ops"] = em["vm_ops"]
                cell["gc"] = {"count": gc["count"], "pct": gc["pct"],
                              "pause_max": gc["pause_max_since_boot"], "live": gc["live_bytes"]}
            entry["E"] = cell

        if key in c_ram:
            best = c_best[key]
            if best is None:
                reasons = [r.get("reason") for r in c_ram[key].values()]
                entry["C"] = {"fail": "stack" if any("stack" in (x or "") for x in reasons) else why(reasons[0])}
            else:
                ram, nursery = best
                cell = {"ram": ram, "nursery": nursery,
                        "stack": c_ram[key][nursery]["stack_peak_bytes"]}
                if key in c_default:
                    cell["insns"] = c_default[key]["insns"]["median"]
                if key in c_min_ram:
                    cell["insns_min_ram"] = c_min_ram[key]["insns"]["median"]
                entry["C"] = cell

    json.dump(out, sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "../encore-benchmarks/results")
