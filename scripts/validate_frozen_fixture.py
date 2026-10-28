#!/usr/bin/env python3
"""Validate the committed frozen raw CSV fixture without regenerating it."""
from __future__ import annotations
import csv
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "tests" / "fixtures" / "frozen_fixture_sha256.json"
EXPECTED = {
    "raw_customers.csv": (200, ["customer_id", "customer_name", "region"]),
    "raw_products.csv": (50, ["product_id", "sku", "category", "unit_price"]),
    "raw_orders.csv": (5636, ["order_id", "customer_id", "order_placed_at", "requested_pickup_at", "actual_picked_at", "is_expedited", "status", "units_required", "actual_pick_delay_mins", "sla_variance_mins"]),
    "raw_order_items.csv": (85221, ["order_item_id", "order_id", "product_id", "quantity"]),
    "raw_shift_logs.csv": (90, ["date", "shift", "scheduled_headcount", "actual_headcount", "call_offs", "avg_pick_rate_target"]),
    "raw_hourly_capacity.csv": (720, ["date", "hour", "system_capacity_limit", "actual_capacity_limit", "constraint_reason", "capacity_reduction_pct", "incident_id"]),
    "raw_kpi_telemetry.csv": (720, ["time_bucket", "facility_id", "kpi_target_name", "target_kpi_value", "actual_kpi_value", "headcount_observed", "capacity_observed", "scheduled_headcount", "labor_capacity_units", "effective_capacity_units", "incoming_demand_units", "opening_backlog_units", "units_picked", "closing_backlog_units", "incident_id"]),
    "raw_incident_logs.csv": (3, ["incident_id", "facility_id", "incident_type", "severity", "root_cause", "capacity_reduction_pct", "t0_genesis", "t1_detection", "t2_escalation", "t3_intervention", "t4_pil", "t5_recovery"]),
    "raw_hourly_demand.csv": (720, ["time_bucket", "facility_id", "incoming_orders", "incoming_demand_units", "opening_backlog_units", "units_picked", "closing_backlog_units", "incident_id"]),
    "raw_hourly_backlog.csv": (720, ["time_bucket", "facility_id", "opening_backlog_units", "incoming_units", "picked_units", "closing_backlog_units", "incident_id"]),
    "simulation_truth.csv": (3, ["incident_id", "true_root_cause", "true_impact_units", "capacity_reduction_pct", "true_incident_flag"]),
}

def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)

def read_csv(name: str):
    path = ROOT / name
    if not path.is_file(): fail(f"required fixture file missing: {name}")
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames is None: fail(f"{name}: missing header")
            rows = list(reader)
            return reader.fieldnames, rows
    except (UnicodeDecodeError, csv.Error) as exc:
        fail(f"{name}: cannot parse CSV: {exc}")

def check_unique(name, rows, key):
    values = [r[key] for r in rows]
    if any(v is None or v == "" for v in values): fail(f"{name}: null/blank {key}")
    if len(set(values)) != len(values): fail(f"{name}: duplicate {key}")

def check_fk(child_name, child_rows, child_key, parent_name, parent_rows, parent_key):
    parent = {r[parent_key] for r in parent_rows}
    missing = [r[child_key] for r in child_rows if r[child_key] not in parent]
    if missing: fail(f"{child_name}.{child_key}: {len(missing)} orphan reference(s) to {parent_name}.{parent_key}")

def main():
    if not MANIFEST.is_file(): fail("frozen fixture SHA-256 manifest missing")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    data = {}
    for name, (expected_count, expected_header) in EXPECTED.items():
        path = ROOT / name
        if not path.is_file(): fail(f"required fixture file missing: {name}")
        canonical_bytes = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        actual_hash = hashlib.sha256(canonical_bytes).hexdigest()
        if manifest.get(name) != actual_hash:
            fail(f"{name}: SHA-256 differs from frozen fixture manifest; do not regenerate or edit the fixture in this CI path")
        header, rows = read_csv(name)
        if header != expected_header: fail(f"{name}: header mismatch\nexpected: {expected_header}\nactual:   {header}")
        if len(rows) != expected_count: fail(f"{name}: expected {expected_count} data rows, found {len(rows)}")
        data[name] = rows
        print(f"PASS {name}: {len(rows):,} rows; SHA-256 verified")

    for name, key in [("raw_customers.csv", "customer_id"), ("raw_products.csv", "product_id"), ("raw_products.csv", "sku"), ("raw_orders.csv", "order_id"), ("raw_order_items.csv", "order_item_id"), ("raw_incident_logs.csv", "incident_id"), ("simulation_truth.csv", "incident_id")]:
        check_unique(name, data[name], key)
    for name, keys in [("raw_hourly_capacity.csv", ("date", "hour")), ("raw_shift_logs.csv", ("date", "shift")), ("raw_hourly_demand.csv", ("time_bucket", "facility_id")), ("raw_hourly_backlog.csv", ("time_bucket", "facility_id")), ("raw_kpi_telemetry.csv", ("time_bucket", "facility_id"))]:
        vals = [tuple(r[k] for k in keys) for r in data[name]]
        if any(any(v is None or v == "" for v in item) for item in vals): fail(f"{name}: blank composite key {keys}")
        if len(set(vals)) != len(vals): fail(f"{name}: duplicate composite key {keys}")

    check_fk("raw_orders.csv", data["raw_orders.csv"], "customer_id", "raw_customers.csv", data["raw_customers.csv"], "customer_id")
    check_fk("raw_order_items.csv", data["raw_order_items.csv"], "order_id", "raw_orders.csv", data["raw_orders.csv"], "order_id")
    check_fk("raw_order_items.csv", data["raw_order_items.csv"], "product_id", "raw_products.csv", data["raw_products.csv"], "product_id")
    check_fk("simulation_truth.csv", data["simulation_truth.csv"], "incident_id", "raw_incident_logs.csv", data["raw_incident_logs.csv"], "incident_id")

    for name, opening, incoming, picked, closing in [
        ("raw_hourly_backlog.csv", "opening_backlog_units", "incoming_units", "picked_units", "closing_backlog_units"),
        ("raw_hourly_demand.csv", "opening_backlog_units", "incoming_demand_units", "units_picked", "closing_backlog_units"),
    ]:
        for idx, row in enumerate(data[name], start=2):
            try: expected = int(row[opening]) + int(row[incoming]) - int(row[picked]); actual = int(row[closing])
            except (ValueError, TypeError): fail(f"{name}:{idx}: invalid numeric backlog field")
            if expected != actual: fail(f"{name}:{idx}: backlog conservation mismatch ({expected} != {actual})")

    timeline = ["t0_genesis", "t1_detection", "t2_escalation", "t3_intervention", "t4_pil", "t5_recovery"]
    for idx, row in enumerate(data["raw_incident_logs.csv"], start=2):
        times = [row[k] for k in timeline]
        if any(not t for t in times) or times != sorted(times): fail(f"raw_incident_logs.csv:{idx}: invalid T0-T5 incident timeline")

    print("PASS unique keys, foreign keys, hourly grain, backlog conservation, and incident timelines")
    print("PASS frozen fixture validation complete; no data generation was run")

if __name__ == "__main__": main()
