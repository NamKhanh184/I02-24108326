#!/usr/bin/python3
import json
import sys


def flatten(value, prefix=""):
    items = {}
    if isinstance(value, dict):
        for key, child in value.items():
            name = f"{prefix}.{key}" if prefix else str(key)
            items.update(flatten(child, name))
    elif isinstance(value, list):
        items[prefix] = str(value)
    else:
        items[prefix] = str(value)
    return items


if len(sys.argv) != 2:
    print("Usage: python3 doc_metrics.py <metrics.json>", file=sys.stderr)
    sys.exit(2)

try:
    with open(sys.argv[1], "r", encoding="utf-8") as metrics_file:
        metrics = json.load(metrics_file)
except (OSError, json.JSONDecodeError) as error:
    print(f"::error::Cannot read metrics file: {error}", file=sys.stderr)
    sys.exit(1)

flat = flatten(metrics)
preferred_keys = (
    "design.name",
    "runtime",
    "flow__warnings_count",
    "flow__errors_count",
    "design__instance__count",
    "design__instance__count__stdcell",
    "design__instance__count__stdcell__combinational",
    "design__instance__count__stdcell__sequential",
    "power",
    "power__total",
    "timing__setup__ws__clk",
    "timing__setup__tns__clk",
)

for key in preferred_keys:
    if key in flat:
        print(f"{key}: {flat[key]}")

for key in sorted(flat):
    if any(key.endswith(suffix) for suffix in ("__area", "__area__total", "__count", "__ws", "__tns")):
        print(f"{key}: {flat[key]}")
