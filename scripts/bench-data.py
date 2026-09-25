#!/usr/bin/env python3
"""Extract the numbers the decks show from encore-benchmarks' results.

    scripts/bench-data.py ../encore-benchmarks/results/benchmarks.jsonl > data/bench.json

Keeps the latest row for each (workload, variant, N) on the QEMU Cortex-M3
board, with the default configurations of the study: E with the CPS
optimizer on, C with its 20 KiB arena. For every case it gives
instructions per run (median) and peak RAM: R static RAM + stack,
C arena high-water + stack, E heap high-water + stack. A C case left out
of the run (it does not fit the RAM budget) is reported with its reason.
"""

import json
import sys

BOARD = "qemu-lm3s6965"

# C cases left out of CASES in certirocq/src/main.rs, from the workload
# READMEs: they abort before producing a row.
C_SKIPPED = {
    ("w0_smoke", 1000): "stack",
    ("w1_apdu", 128): "arena",
    ("w1_apdu", 261): "stack",
    ("w2_rlp", 260): "arena",
    ("w3_policy", 64): "arena",
    ("w5_update", 1000): "stack",
    ("w7_store", 100): "arena",
    ("w7_store", 500): "arena",
}


def keep(r):
    if r["board"] != BOARD:
        return False
    if r["variant"] == "E":
        return r["build"].get("cps_optimize") is True
    if r["variant"] == "C":
        return r["build"]["heap_bytes"] == 20480
    return True


def main(path):
    latest = {}
    for line in open(path):
        r = json.loads(line)
        if keep(r):
            latest[(r["workload"], r["variant"], r["profile"], r["n"])] = r

    out = {}
    for (w, v, profile, n), r in sorted(latest.items(), key=lambda kv: kv[0][3]):
        if profile != "timing":
            continue
        case = out.setdefault(w, {}).setdefault(str(n), {"n": n})
        if not r["ok"]:
            reason = r.get("reason", "")
            case[v] = {"fail": "stack" if "stack" in reason else "arena" if "arena" in reason else "heap"}
            continue
        cell = {"insns": r["insns"]["median"], "stack": r["stack_peak_bytes"]}
        if v == "R":
            cell["ram"] = r["size"]["ram_static_bytes"] + r["stack_peak_bytes"]
        elif v == "C":
            cell["ram"] = r["heap_peak_bytes"] + r["stack_peak_bytes"]
        else:
            mem = latest.get((w, "E", "memory", n))
            cell["heap"] = mem["heap_peak_bytes"]
            cell["heap_budget"] = r["build"]["heap_bytes"]
            cell["vm_ops"] = mem["vm_ops"]
            cell["ram"] = mem["heap_peak_bytes"] + r["stack_peak_bytes"]
        case[v] = cell

    for (w, n), why in C_SKIPPED.items():
        out[w][str(n)].setdefault("C", {"fail": why})

    json.dump({w: list(cases.values()) for w, cases in sorted(out.items())},
              sys.stdout, indent=1)
    print()


if __name__ == "__main__":
    main(sys.argv[1])
