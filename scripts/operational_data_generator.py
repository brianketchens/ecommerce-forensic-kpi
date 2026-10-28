import pandas as pd
import numpy as np
import random
from datetime import datetime, timedelta

# ============================================================
# OPERATIONAL FORENSICS DATASET GENERATOR — V2
# ============================================================
#
# Causal chain:
#
#   Orders
#      ↓
#   Order units / hourly demand
#      ↓
#   Labor capacity + staging capacity
#      ↓
#   Effective picking capacity
#      ↓
#   Units picked
#      ↓
#   Backlog
#      ↓
#   Order completion
#      ↓
#   SLA performance
#
# Existing output schemas are preserved where possible.
# Additional columns are included where they strengthen
# the operational-forensics model.
#
# ============================================================


# ------------------------------------------------------------
# 0. Configuration & Reproducibility
# ------------------------------------------------------------

SEED = 42
random.seed(SEED)
np.random.seed(SEED)

NUM_CUSTOMERS = 200
NUM_PRODUCTS = 50

START_DATE = datetime(2026, 8, 1)
DAYS_TO_SIMULATE = 30

FACILITY_ID = "FACILITY_01"

# Operational assumptions
BASELINE_HEADCOUNT = 8
AVG_PICK_RATE = 110                 # units per labor hour
BASELINE_CAPACITY = 1000            # staging/system capacity units/hr
CAPACITY_THROTTLE_FACTOR = 0.75     # throughput multiplier when constrained

# Demand assumptions
BASE_DAILY_ORDERS = 200
ORDER_LINES_MIN = 5
ORDER_LINES_MAX = 25

# Incident assumptions
DAILY_CAPACITY_ISSUE_PROBABILITY = 0.15

# ------------------------------------------------------------
# 1. Assumption Registry Seed
# ------------------------------------------------------------

assumptions_seed = pd.DataFrame([
    {
        "assumption_id": "ASM_LABOR_HEADCOUNT",
        "kpi_target_name": "picked_units_per_hour",
        "operational_factor": "headcount",
        "expected_baseline_value": float(BASELINE_HEADCOUNT),
        "impact_coefficient": float(AVG_PICK_RATE),
        "unit_of_measure": "headcount",
        "variance_class": "Avoidable",
        "is_active": True
    },
    {
        "assumption_id": "ASM_STAGING_CAPACITY",
        "kpi_target_name": "picked_units_per_hour",
        "operational_factor": "staging_capacity",
        "expected_baseline_value": float(BASELINE_CAPACITY),
        "impact_coefficient": float(CAPACITY_THROTTLE_FACTOR),
        "unit_of_measure": "units_per_hr",
        "variance_class": "Unavoidable",
        "is_active": True
    }
])


# ------------------------------------------------------------
# 2. Master Entities
# ------------------------------------------------------------

# Customers
customers = pd.DataFrame({
    "customer_id": range(1, NUM_CUSTOMERS + 1),
    "customer_name": [
        f"Customer_{i}" for i in range(1, NUM_CUSTOMERS + 1)
    ],
    "region": [
        random.choice(["North", "South", "East", "West"])
        for _ in range(NUM_CUSTOMERS)
    ]
})


# Products
#
# Use deterministic unique SKUs rather than random SKU generation.
# This prevents accidental business-key collisions.

products = pd.DataFrame({
    "product_id": range(1, NUM_PRODUCTS + 1),
    "sku": [
        f"SKU-{1000 + i}" for i in range(NUM_PRODUCTS)
    ],
    "category": [
        random.choice(["Grocery", "Produce", "Dairy", "Frozen"])
        for _ in range(NUM_PRODUCTS)
    ],
    "unit_price": [
        round(random.uniform(2.0, 25.0), 2)
        for _ in range(NUM_PRODUCTS)
    ]
})


# ------------------------------------------------------------
# 3. Data Containers
# ------------------------------------------------------------

orders_data = []
order_items_data = []
shift_logs_data = []
capacity_data = []
hourly_kpi_telemetry = []
incident_logs_data = []

# New analytical fact:
# hourly demand / workload reconciliation
hourly_demand_data = []

# New analytical fact:
# explicit backlog state
hourly_backlog_data = []

# Optional simulation truth table.
# This is useful for validating the analytical model later.
simulation_truth_data = []

order_id_counter = 1
item_id_counter = 1
incident_id_counter = 1


# ------------------------------------------------------------
# 4. Generate Orders First
# ------------------------------------------------------------
#
# The original generator created telemetry first and orders
# separately. V2 starts with demand so that throughput can
# actually respond to workload.
#
# ------------------------------------------------------------

all_orders = []

for day in range(DAYS_TO_SIMULATE):

    current_date = START_DATE + timedelta(days=day)

    weekday = current_date.weekday()

    # Demand seasonality:
    #
    # Mon-Fri = normal/high
    # Saturday = moderate
    # Sunday = lower
    #
    if weekday == 4:          # Friday
        demand_multiplier = 1.20
    elif weekday in [5]:      # Saturday
        demand_multiplier = 0.85
    elif weekday in [6]:      # Sunday
        demand_multiplier = 0.70
    else:
        demand_multiplier = 1.00

    daily_orders = int(
        np.random.normal(
            BASE_DAILY_ORDERS * demand_multiplier,
            10
        )
    )

    daily_orders = max(60, daily_orders)

    for _ in range(daily_orders):

        # Peak demand is concentrated in the morning,
        # but some orders arrive throughout the day.
        if random.random() < 0.60:
            order_hour = random.randint(5, 9)
        else:
            order_hour = random.randint(10, 20)

        order_time = (
            current_date
            + timedelta(
                hours=order_hour,
                minutes=random.randint(0, 59)
            )
        )

        is_expedited = random.random() < 0.20

        lead_time_hours = 1 if is_expedited else 2

        requested_pickup = (
            order_time
            + timedelta(hours=lead_time_hours)
        )

        customer_id = random.randint(1, NUM_CUSTOMERS)

        all_orders.append({
            "order_id": order_id_counter,
            "customer_id": customer_id,
            "order_placed_at": order_time,
            "requested_pickup_at": requested_pickup,
            "is_expedited": is_expedited
        })

        # Generate order items.
        #
        # The resulting units become actual workload.
        for _ in range(
            random.randint(
                ORDER_LINES_MIN,
                ORDER_LINES_MAX
            )
        ):

            order_items_data.append({
                "order_item_id": item_id_counter,
                "order_id": order_id_counter,
                "product_id": random.randint(
                    1,
                    NUM_PRODUCTS
                ),
                "quantity": random.randint(1, 3)
            })

            item_id_counter += 1

        order_id_counter += 1


# ------------------------------------------------------------
# 5. Create Order / Item DataFrames
# ------------------------------------------------------------

orders_df = pd.DataFrame(all_orders)
order_items_df = pd.DataFrame(order_items_data)

orders_df["order_date"] = (
    orders_df["order_placed_at"].dt.date
)

orders_df["order_hour"] = (
    orders_df["order_placed_at"].dt.hour
)

# Total units required by order
order_units = (
    order_items_df
    .groupby("order_id")["quantity"]
    .sum()
    .rename("units_required")
)

orders_df = orders_df.merge(
    order_units,
    on="order_id",
    how="left"
)

orders_df["units_required"] = (
    orders_df["units_required"]
    .fillna(0)
    .astype(int)
)


# ------------------------------------------------------------
# 6. Daily Operational Conditions
# ------------------------------------------------------------

daily_conditions = {}

for day in range(DAYS_TO_SIMULATE):

    current_date = START_DATE + timedelta(days=day)

    daily_capacity_issue = (
        random.random()
        < DAILY_CAPACITY_ISSUE_PROBABILITY
    )

    # Variable incident severity.
    #
    # This prevents every incident from looking identical.
    if daily_capacity_issue:
        capacity_reduction = random.choice([
            0.20,
            0.25,
            0.35,
            0.50
        ])
    else:
        capacity_reduction = 0.0

    # Staffing call-offs
    morn_calloffs = random.choice([0, 0, 0, 1, 2])
    aft_calloffs = random.choice([0, 0, 1, 1])
    night_calloffs = random.choice([0, 0, 1])

    daily_conditions[current_date.date()] = {
        "capacity_issue": daily_capacity_issue,
        "capacity_reduction": capacity_reduction,
        "morn_calloffs": morn_calloffs,
        "aft_calloffs": aft_calloffs,
        "night_calloffs": night_calloffs
    }


# ------------------------------------------------------------
# 7. Shift Logs
# ------------------------------------------------------------

for day in range(DAYS_TO_SIMULATE):

    current_date = START_DATE + timedelta(days=day)

    conditions = daily_conditions[current_date.date()]

    shifts = [
        {
            "shift": "Morning",
            "req": 8,
            "actual": 8 - conditions["morn_calloffs"],
            "calloffs": conditions["morn_calloffs"]
        },
        {
            "shift": "Afternoon",
            "req": 6,
            "actual": 6 - conditions["aft_calloffs"],
            "calloffs": conditions["aft_calloffs"]
        },
        {
            "shift": "Night",
            "req": 3,
            "actual": 3 - conditions["night_calloffs"],
            "calloffs": conditions["night_calloffs"]
        }
    ]

    for s in shifts:

        shift_logs_data.append({
            "date": current_date.date(),
            "shift": s["shift"],
            "scheduled_headcount": s["req"],
            "actual_headcount": s["actual"],
            "call_offs": s["calloffs"],
            "avg_pick_rate_target": AVG_PICK_RATE
        })


# ------------------------------------------------------------
# 8. Incident Generation
# ------------------------------------------------------------

for day in range(DAYS_TO_SIMULATE):

    current_date = START_DATE + timedelta(days=day)

    conditions = daily_conditions[current_date.date()]

    if not conditions["capacity_issue"]:
        continue

    # Capacity event begins at 08:00.
    t0 = current_date + timedelta(hours=8)

    t1 = (
        t0
        + timedelta(minutes=random.randint(15, 30))
    )

    t2 = (
        t1
        + timedelta(minutes=random.randint(10, 20))
    )

    t3 = (
        t2
        + timedelta(minutes=random.randint(15, 35))
    )

    t4 = t0 + timedelta(hours=2)
    t5 = t0 + timedelta(hours=8)

    incident_id = (
        f"INC-{incident_id_counter:04d}"
    )

    incident_logs_data.append({
        "incident_id": incident_id,
        "facility_id": FACILITY_ID,
        "incident_type": "CAPACITY_BREACH",
        "severity": (
            "Critical"
            if conditions["capacity_reduction"] >= 0.50
            else "High"
        ),
        "root_cause": "Staging Capacity",
        "capacity_reduction_pct": round(conditions["capacity_reduction"], 4),
        "t0_genesis": t0,
        "t1_detection": t1,
        "t2_escalation": t2,
        "t3_intervention": t3,
        "t4_pil": t4,
        "t5_recovery": t5
    })

    incident_id_counter += 1


incident_df = pd.DataFrame(incident_logs_data)


# ------------------------------------------------------------
# 9. Map Incidents to Hours
# ------------------------------------------------------------

def get_incident_for_hour(timestamp):

    if incident_df.empty:
        return None

    matches = incident_df[
        (incident_df["t0_genesis"] <= timestamp) &
        (incident_df["t5_recovery"] > timestamp)
    ]

    if matches.empty:
        return None

    return matches.iloc[0]["incident_id"]


# ------------------------------------------------------------
# 10. Hourly Operational Simulation
# ------------------------------------------------------------
#
# This is the core of V2.
#
# Demand enters the system.
# Labor determines potential throughput.
# Staging capacity constrains throughput.
# Actual throughput reduces backlog.
#
# ------------------------------------------------------------

backlog_units = 0

# Track which orders have been completed.
# We will use this to derive actual_picked_at.
order_remaining_units = dict(
    zip(
        orders_df["order_id"],
        orders_df["units_required"]
    )
)

order_pick_completion = {}

# For assigning backlog work in FIFO order,
# orders are sorted by placement time.
orders_fifo = (
    orders_df
    .sort_values("order_placed_at")
    .copy()
)

# For each hour
for day in range(DAYS_TO_SIMULATE):

    current_date = START_DATE + timedelta(days=day)

    conditions = daily_conditions[current_date.date()]

    for hour in range(24):

        time_bucket = (
            current_date
            + timedelta(hours=hour)
        )

        # ----------------------------------------------------
        # Determine staffing
        # ----------------------------------------------------

        if 4 <= hour < 12:

            scheduled_headcount = 8

            headcount = (
                8
                - conditions["morn_calloffs"]
            )

        elif 12 <= hour < 20:

            scheduled_headcount = 6

            headcount = (
                6
                - conditions["aft_calloffs"]
            )

        else:

            scheduled_headcount = 3

            headcount = (
                3
                - conditions["night_calloffs"]
            )


        # ----------------------------------------------------
        # Capacity
        # ----------------------------------------------------

        if (
            conditions["capacity_issue"]
            and 8 <= hour < 16
        ):

            actual_capacity = int(
                BASELINE_CAPACITY
                * (
                    1
                    - conditions["capacity_reduction"]
                )
            )

        else:

            actual_capacity = BASELINE_CAPACITY


        # ----------------------------------------------------
        # Incoming demand
        # ----------------------------------------------------

        incoming_orders = orders_df[
            (
                orders_df["order_placed_at"]
                >= time_bucket
            )
            &
            (
                orders_df["order_placed_at"]
                < time_bucket + timedelta(hours=1)
            )
        ]

        incoming_units = int(
            incoming_orders["units_required"].sum()
        )


        # ----------------------------------------------------
        # Add incoming workload to backlog
        # ----------------------------------------------------

        opening_backlog = backlog_units

        backlog_units += incoming_units


        # ----------------------------------------------------
        # Labor-derived capacity
        # ----------------------------------------------------

        labor_capacity = (
            headcount
            * AVG_PICK_RATE
        )


        # ----------------------------------------------------
        # Staging constraint
        # ----------------------------------------------------

        if actual_capacity < BASELINE_CAPACITY:
            effective_capacity = min(
                labor_capacity * CAPACITY_THROTTLE_FACTOR,
                actual_capacity
            )
        else:
            effective_capacity = labor_capacity

        effective_capacity = int(max(0, effective_capacity))


        # ----------------------------------------------------
        # Actual units picked
        # ----------------------------------------------------

        units_picked = min(
            backlog_units,
            effective_capacity
        )

        backlog_units -= units_picked

        closing_backlog = backlog_units


        # ----------------------------------------------------
        # KPI
        # ----------------------------------------------------

        # KPI represents actual units picked per hour.
        #
        # Random process noise remains, but cannot create
        # throughput that exceeds the physical workload/capacity
        # constraints.

        epsilon = np.random.normal(0, 15)

        observed_kpi = max(
            0,
            round(
                units_picked + epsilon,
                2
            )
        )

        # When workload is lower than available capacity,
        # actual picked units should remain the meaningful
        # throughput measure.
        actual_kpi = min(
            observed_kpi,
            float(units_picked + 30)
        )


        # ----------------------------------------------------
        # Incident relationship
        # ----------------------------------------------------

        incident_id = get_incident_for_hour(
            time_bucket
        )


        # ----------------------------------------------------
        # Telemetry
        # ----------------------------------------------------

        hourly_kpi_telemetry.append({

            "time_bucket": time_bucket,

            "facility_id": FACILITY_ID,

            "kpi_target_name":
                "picked_units_per_hour",

            # Target KPI reflects scheduled staffing for the shift.
            "target_kpi_value":
                scheduled_headcount * AVG_PICK_RATE,

            "actual_kpi_value":
                round(actual_kpi, 2),

            "headcount_observed":
                headcount,

            "capacity_observed":
                actual_capacity,

            # Added analytical fields
            "scheduled_headcount":
                scheduled_headcount,

            "labor_capacity_units":
                labor_capacity,

            "effective_capacity_units":
                effective_capacity,

            "incoming_demand_units":
                incoming_units,

            "opening_backlog_units":
                opening_backlog,

            "units_picked":
                units_picked,

            "closing_backlog_units":
                closing_backlog,

            "incident_id":
                incident_id
        })


        # ----------------------------------------------------
        # Demand Fact
        # ----------------------------------------------------

        hourly_demand_data.append({

            "time_bucket":
                time_bucket,

            "facility_id":
                FACILITY_ID,

            "incoming_orders":
                len(incoming_orders),

            "incoming_demand_units":
                incoming_units,

            "opening_backlog_units":
                opening_backlog,

            "units_picked":
                units_picked,

            "closing_backlog_units":
                closing_backlog,

            "incident_id":
                incident_id
        })


        # ----------------------------------------------------
        # Backlog Fact
        # ----------------------------------------------------

        hourly_backlog_data.append({

            "time_bucket":
                time_bucket,

            "facility_id":
                FACILITY_ID,

            "opening_backlog_units":
                opening_backlog,

            "incoming_units":
                incoming_units,

            "picked_units":
                units_picked,

            "closing_backlog_units":
                closing_backlog,

            "incident_id":
                incident_id
        })


        # ----------------------------------------------------
        # Capacity Fact
        # ----------------------------------------------------

        capacity_data.append({

            "date":
                current_date.date(),

            "hour":
                hour,

            "system_capacity_limit":
                BASELINE_CAPACITY,

            "actual_capacity_limit":
                actual_capacity,

            "constraint_reason":
                (
                    "Staging area construction"
                    if actual_capacity < BASELINE_CAPACITY
                    else np.nan
                ),

            # Added fields
            "capacity_reduction_pct":
                round(
                    1
                    - (
                        actual_capacity
                        / BASELINE_CAPACITY
                    ),
                    4
                ),

            "incident_id":
                incident_id
        })


# ------------------------------------------------------------
# 11. Derive Order Completion From Actual Throughput
# ------------------------------------------------------------
#
# Rather than randomly assigning delay, determine whether
# an order completed based on the operational system.
#
# The hourly throughput is allocated FIFO to outstanding
# orders.
#
# ------------------------------------------------------------

# Rebuild hourly throughput information
hourly_df = pd.DataFrame(hourly_demand_data)

orders_work = (
    orders_df
    .sort_values("order_placed_at")
    .copy()
)

orders_work["units_remaining"] = (
    orders_work["units_required"]
)

orders_work["actual_picked_at"] = pd.NaT

# We replay throughput chronologically. Within each hour, throughput is
# treated as approximately uniform. This prevents an order arriving late
# in the hour from consuming throughput that occurred before it arrived.
for _, hour_row in hourly_df.iterrows():
    hour_start = hour_row["time_bucket"]
    hour_end = hour_start + timedelta(hours=1)
    hourly_picked = int(hour_row["units_picked"])
    hourly_picked_total = hourly_picked

    if hourly_picked <= 0:
        continue

    eligible = orders_work[
        (orders_work["order_placed_at"] < hour_end)
        & (orders_work["units_remaining"] > 0)
    ]

    for idx in eligible.index:
        if hourly_picked <= 0:
            break

        order_time = max(
            orders_work.at[idx, "order_placed_at"],
            hour_start
        )

        available_fraction = (
            (hour_end - order_time).total_seconds() / 3600
        )
        available_fraction = max(0.0, min(1.0, available_fraction))

        units_available_after_arrival = int(
            np.floor(int(hour_row["units_picked"]) * available_fraction)
        )

        if units_available_after_arrival <= 0:
            continue

        remaining = int(orders_work.at[idx, "units_remaining"])
        units_allocated = min(
            remaining,
            units_available_after_arrival,
            hourly_picked
        )

        orders_work.at[idx, "units_remaining"] -= units_allocated
        hourly_picked -= units_allocated

        if orders_work.at[idx, "units_remaining"] <= 0:
            # Completion occurs at the point in the hour when the cumulative
            # throughput allocated to this order is reached. This preserves
            # temporal ordering even when the order arrives late in the hour.
            units_consumed_before = hourly_picked_total - hourly_picked
            cumulative_units = units_consumed_before + units_allocated

            throughput_offset_seconds = (
                cumulative_units / max(1, hourly_picked_total)
            ) * 3600
            arrival_offset_seconds = max(
                0,
                (order_time - hour_start).total_seconds()
            )
            completion_offset_seconds = max(
                arrival_offset_seconds,
                throughput_offset_seconds
            )

            completion_time = hour_start + timedelta(
                seconds=min(3599, max(1, int(completion_offset_seconds)))
            )
            orders_work.at[idx, "actual_picked_at"] = min(
                completion_time,
                hour_end - timedelta(seconds=1)
            )

# ------------------------------------------------------------
# 12. SLA Calculations
# ------------------------------------------------------------

orders_work["actual_pick_delay_mins"] = (
    (
        orders_work["actual_picked_at"]
        - orders_work["order_placed_at"]
    )
    .dt.total_seconds()
    / 60
)

orders_work["sla_variance_mins"] = (
    (
        orders_work["actual_picked_at"]
        - orders_work["requested_pickup_at"]
    )
    .dt.total_seconds()
    / 60
)

orders_work["status"] = np.where(
    orders_work["actual_picked_at"].notna()
    &
    (
        orders_work["actual_picked_at"]
        <= orders_work["requested_pickup_at"]
    ),
    "Dispensed",
    "Delayed"
)

# Orders that remain incomplete at the end of simulation
orders_work.loc[
    orders_work["actual_picked_at"].isna(),
    "status"
] = "Backlog"


# ------------------------------------------------------------
# 13. Incident Impact / Simulation Truth
# ------------------------------------------------------------
# This validation-only table is an answer key for testing whether the
# analytical model can recover known simulated incident effects.
#
# true_impact_units = maximum incremental backlog created by the incident
# versus a counterfactual with the staging constraint removed, while
# preserving observed labor conditions.
# ------------------------------------------------------------

hourly_truth = (
    hourly_df
    .merge(
        pd.DataFrame(hourly_kpi_telemetry)[["time_bucket", "labor_capacity_units"]],
        on="time_bucket",
        how="left"
    )
    .sort_values("time_bucket")
)

for _, incident in incident_df.iterrows():
    incident_start = incident["t0_genesis"]
    incident_end = incident["t5_recovery"]

    affected_hours = hourly_truth[
        (hourly_truth["time_bucket"] >= incident_start)
        & (hourly_truth["time_bucket"] < incident_end)
    ]

    pre_incident = hourly_truth[hourly_truth["time_bucket"] < incident_start]
    counterfactual_backlog = (
        0 if pre_incident.empty
        else int(pre_incident.iloc[-1]["closing_backlog_units"])
    )

    actual_backlog = counterfactual_backlog
    max_incremental_backlog = 0

    for _, hour_row in affected_hours.iterrows():
        incoming = int(hour_row["incoming_demand_units"])
        actual_backlog += incoming
        counterfactual_picked = min(
            actual_backlog,
            int(hour_row["labor_capacity_units"])
        )
        actual_backlog -= counterfactual_picked

        actual_closing = int(hour_row["closing_backlog_units"])
        max_incremental_backlog = max(
            max_incremental_backlog,
            actual_closing - actual_backlog
        )

    simulation_truth_data.append({
        "incident_id": incident["incident_id"],
        "true_root_cause": incident["root_cause"],
        "true_impact_units": int(max(0, max_incremental_backlog)),
        "capacity_reduction_pct": round(float(incident["capacity_reduction_pct"]), 4),
        "true_incident_flag": True
    })

# ------------------------------------------------------------
# 14. Convert Final DataFrames
# ------------------------------------------------------------

orders_output = orders_work[
    [
        "order_id",
        "customer_id",
        "order_placed_at",
        "requested_pickup_at",
        "actual_picked_at",
        "is_expedited",
        "status",
        "units_required",
        "actual_pick_delay_mins",
        "sla_variance_mins"
    ]
].copy()


# ------------------------------------------------------------
# 15. Data Quality Validation
# ------------------------------------------------------------

assert customers["customer_id"].is_unique

assert products["product_id"].is_unique
assert products["sku"].is_unique

assert orders_output["order_id"].is_unique

assert order_items_df["order_id"].isin(
    orders_output["order_id"]
).all()

# Timestamp ordering for incidents
if not incident_df.empty:

    assert (
        incident_df["t1_detection"]
        > incident_df["t0_genesis"]
    ).all()

    assert (
        incident_df["t2_escalation"]
        > incident_df["t1_detection"]
    ).all()

    assert (
        incident_df["t3_intervention"]
        > incident_df["t2_escalation"]
    ).all()

    assert (
        incident_df["t4_pil"]
        > incident_df["t0_genesis"]
    ).all()

    assert (
        incident_df["t5_recovery"]
        > incident_df["t4_pil"]
    ).all()


# Backlog reconciliation
hourly_demand_df = pd.DataFrame(
    hourly_demand_data
)

reconciliation_error = (
    hourly_demand_df["opening_backlog_units"]
    +
    hourly_demand_df["incoming_demand_units"]
    -
    hourly_demand_df["units_picked"]
    -
    hourly_demand_df["closing_backlog_units"]
)

assert (
    reconciliation_error == 0
).all()

# Behavioral and physical constraint validations
assert len(incident_df) > 0
assert hourly_demand_df["closing_backlog_units"].max() > 0
assert (orders_output["status"] == "Delayed").any()
assert (orders_output["actual_picked_at"].dropna() >= orders_output.loc[orders_output["actual_picked_at"].notna(), "order_placed_at"]).all()
assert (pd.DataFrame(simulation_truth_data)["true_impact_units"] > 0).any()

telemetry_check = pd.DataFrame(hourly_kpi_telemetry)
assert (telemetry_check["effective_capacity_units"] <= telemetry_check["labor_capacity_units"]).all()
assert (telemetry_check["effective_capacity_units"] <= telemetry_check["capacity_observed"]).all()


# ------------------------------------------------------------
# 16. Export CSVs
# ------------------------------------------------------------

assumptions_seed.to_csv(
    "seed_operational_assumptions.csv",
    index=False
)

customers.to_csv(
    "raw_customers.csv",
    index=False
)

products.to_csv(
    "raw_products.csv",
    index=False
)

orders_output.to_csv(
    "raw_orders.csv",
    index=False
)

order_items_df.to_csv(
    "raw_order_items.csv",
    index=False
)

pd.DataFrame(
    shift_logs_data
).to_csv(
    "raw_shift_logs.csv",
    index=False
)

pd.DataFrame(
    hourly_kpi_telemetry
).to_csv(
    "raw_kpi_telemetry.csv",
    index=False
)

pd.DataFrame(
    incident_logs_data
).to_csv(
    "raw_incident_logs.csv",
    index=False
)

pd.DataFrame(
    capacity_data
).to_csv(
    "raw_hourly_capacity.csv",
    index=False
)

pd.DataFrame(
    hourly_demand_data
).to_csv(
    "raw_hourly_demand.csv",
    index=False
)

pd.DataFrame(
    hourly_backlog_data
).to_csv(
    "raw_hourly_backlog.csv",
    index=False
)

pd.DataFrame(
    simulation_truth_data
).to_csv(
    "simulation_truth.csv",
    index=False
)


# ------------------------------------------------------------
# 17. Run Summary
# ------------------------------------------------------------

print(
    "\nOperational Forensics V2 dataset generated successfully."
)

print(
    f"Simulation period: "
    f"{START_DATE.date()} → "
    f"{(START_DATE + timedelta(days=DAYS_TO_SIMULATE - 1)).date()}"
)

print(
    f"Customers: {len(customers):,}"
)

print(
    f"Products: {len(products):,}"
)

print(
    f"Orders: {len(orders_output):,}"
)

print(
    f"Order items: {len(order_items_df):,}"
)

print(
    f"Average units/order: {orders_output['units_required'].mean():.1f}"
)

print(
    f"Incidents: {len(incident_df):,}"
)

print(
    f"Delayed orders: "
    f"{(orders_output['status'] == 'Delayed').sum():,}"
)

print(
    f"Backlog orders: "
    f"{(orders_output['status'] == 'Backlog').sum():,}"
)

print(
    f"Peak backlog units: "
    f"{hourly_demand_df['closing_backlog_units'].max():,}"
)

print(
    "\nBacklog reconciliation: PASSED"
)

print(
    "Timestamp validation: PASSED"
)

print(
    "Business-key validation: PASSED"
)