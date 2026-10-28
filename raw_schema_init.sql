-- ============================================================
-- E-COMMERCE OPERATIONAL FORENSICS
-- RAW SCHEMA INITIALIZATION
--
-- Generator: operational_data_generator.py V2
--
-- Causal model:
--
--   demand
--      ↓
--   labor / capacity
--      ↓
--   throughput
--      ↓
--   backlog
--      ↓
--   order completion
--      ↓
--   SLA
--
-- PostgreSQL / psql
-- ============================================================


-- ============================================================
-- 0. SCHEMA
-- ============================================================

CREATE SCHEMA IF NOT EXISTS raw_data;


-- ============================================================
-- 1. RESET RAW TABLES
--
-- Synthetic data is regenerated as a complete dataset.
-- Drop/recreate prevents stale schemas from surviving generator
-- revisions.
-- ============================================================

DROP TABLE IF EXISTS raw_data.simulation_truth CASCADE;
DROP TABLE IF EXISTS raw_data.raw_hourly_backlog CASCADE;
DROP TABLE IF EXISTS raw_data.raw_hourly_demand CASCADE;
DROP TABLE IF EXISTS raw_data.raw_incident_logs CASCADE;
DROP TABLE IF EXISTS raw_data.raw_kpi_telemetry CASCADE;
DROP TABLE IF EXISTS raw_data.raw_hourly_capacity CASCADE;
DROP TABLE IF EXISTS raw_data.raw_shift_logs CASCADE;
DROP TABLE IF EXISTS raw_data.raw_order_items CASCADE;
DROP TABLE IF EXISTS raw_data.raw_orders CASCADE;
DROP TABLE IF EXISTS raw_data.raw_products CASCADE;
DROP TABLE IF EXISTS raw_data.raw_customers CASCADE;


-- ============================================================
-- 2. MASTER ENTITIES
-- ============================================================

CREATE TABLE raw_data.raw_customers (

    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    region VARCHAR(50)

);


CREATE TABLE raw_data.raw_products (

    product_id INT PRIMARY KEY,
    sku VARCHAR(50),
    category VARCHAR(50),
    unit_price NUMERIC(10, 2)

);


CREATE TABLE raw_data.raw_orders (

    order_id INT PRIMARY KEY,
    customer_id INT,

    order_placed_at TIMESTAMP,
    requested_pickup_at TIMESTAMP,
    actual_picked_at TIMESTAMP,

    is_expedited BOOLEAN,
    status VARCHAR(50),

    units_required INT,
    actual_pick_delay_mins NUMERIC,
    sla_variance_mins NUMERIC

);


CREATE TABLE raw_data.raw_order_items (

    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT

);


-- ============================================================
-- 3. LABOR / CAPACITY
-- ============================================================

CREATE TABLE raw_data.raw_shift_logs (

    date DATE,
    shift VARCHAR(50),

    scheduled_headcount INT,
    actual_headcount INT,
    call_offs INT,

    avg_pick_rate_target INT

);


CREATE TABLE raw_data.raw_hourly_capacity (

    date DATE,
    hour INT,

    system_capacity_limit INT,
    actual_capacity_limit INT,
    constraint_reason VARCHAR(255),

    capacity_reduction_pct NUMERIC(5, 4),
    incident_id VARCHAR(50)

);


-- ============================================================
-- 4. HOURLY DEMAND
--
-- Grain:
--   facility / hour
--
-- Demand enters the system here.
-- ============================================================

CREATE TABLE raw_data.raw_hourly_demand (

    time_bucket TIMESTAMP,
    facility_id VARCHAR(50),

    incoming_orders INT,
    incoming_demand_units INT,

    opening_backlog_units INT,
    units_picked INT,
    closing_backlog_units INT,

    incident_id VARCHAR(50)

);


-- ============================================================
-- 5. HOURLY BACKLOG
--
-- Grain:
--   facility / hour
--
-- Reconciliation:
--
--   opening_backlog
--   + incoming_units
--   - picked_units
--   = closing_backlog
-- ============================================================

CREATE TABLE raw_data.raw_hourly_backlog (

    time_bucket TIMESTAMP,
    facility_id VARCHAR(50),

    opening_backlog_units INT,
    incoming_units INT,
    picked_units INT,
    closing_backlog_units INT,

    incident_id VARCHAR(50)

);


-- ============================================================
-- 6. KPI TELEMETRY
--
-- Original telemetry fields retained.
-- V2 operational context included.
-- ============================================================

CREATE TABLE raw_data.raw_kpi_telemetry (

    time_bucket TIMESTAMP,
    facility_id VARCHAR(50),

    kpi_target_name VARCHAR(100),
    target_kpi_value NUMERIC,
    actual_kpi_value NUMERIC,

    headcount_observed NUMERIC,
    capacity_observed NUMERIC,

    scheduled_headcount INT,
    labor_capacity_units NUMERIC,
    effective_capacity_units NUMERIC,

    incoming_demand_units INT,
    opening_backlog_units INT,
    units_picked INT,
    closing_backlog_units INT,

    incident_id VARCHAR(50)

);


-- ============================================================
-- 7. INCIDENT LOG
--
-- Incident lifecycle:
--
--   t0 = genesis
--   t1 = detection
--   t2 = escalation
--   t3 = intervention
--   t4 = PIL
--   t5 = recovery
-- ============================================================

CREATE TABLE raw_data.raw_incident_logs (

    incident_id VARCHAR(50) PRIMARY KEY,
    facility_id VARCHAR(50),

    incident_type VARCHAR(50),
    severity VARCHAR(50),
    root_cause VARCHAR(255),

    capacity_reduction_pct NUMERIC(5, 4),

    t0_genesis TIMESTAMP,
    t1_detection TIMESTAMP,
    t2_escalation TIMESTAMP,
    t3_intervention TIMESTAMP,
    t4_pil TIMESTAMP,
    t5_recovery TIMESTAMP

);


-- ============================================================
-- 8. SIMULATION TRUTH
--
-- Ground truth for validating the analytical model.
--
-- This table should NOT flow into the production analytical
-- marts. It exists to validate whether the model can recover
-- the known causal condition.
-- ============================================================

CREATE TABLE raw_data.simulation_truth (

    incident_id VARCHAR(50) PRIMARY KEY,

    true_root_cause VARCHAR(255),
    true_impact_units NUMERIC,
    capacity_reduction_pct NUMERIC(5, 4),
    true_incident_flag BOOLEAN

);


-- ============================================================
-- 9. BULK LOAD
--
-- Explicit column lists prevent CSV column-order drift from
-- silently breaking ingestion.
-- ============================================================

-- ============================================================
-- 9. BULK LOAD
--
-- Explicit column lists prevent CSV column-order drift from
-- silently breaking ingestion.
-- ============================================================

\copy raw_data.raw_customers (customer_id, customer_name, region) FROM 'raw_customers.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_products (product_id, sku, category, unit_price) FROM 'raw_products.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_orders (order_id, customer_id, order_placed_at, requested_pickup_at, actual_picked_at, is_expedited, status, units_required, actual_pick_delay_mins, sla_variance_mins) FROM 'raw_orders.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_order_items (order_item_id, order_id, product_id, quantity) FROM 'raw_order_items.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_shift_logs (date, shift, scheduled_headcount, actual_headcount, call_offs, avg_pick_rate_target) FROM 'raw_shift_logs.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_hourly_capacity (date, hour, system_capacity_limit, actual_capacity_limit, constraint_reason, capacity_reduction_pct, incident_id) FROM 'raw_hourly_capacity.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_kpi_telemetry (time_bucket, facility_id, kpi_target_name, target_kpi_value, actual_kpi_value, headcount_observed, capacity_observed, scheduled_headcount, labor_capacity_units, effective_capacity_units, incoming_demand_units, opening_backlog_units, units_picked, closing_backlog_units, incident_id) FROM 'raw_kpi_telemetry.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_incident_logs (incident_id, facility_id, incident_type, severity, root_cause, capacity_reduction_pct, t0_genesis, t1_detection, t2_escalation, t3_intervention, t4_pil, t5_recovery) FROM 'raw_incident_logs.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_hourly_demand (time_bucket, facility_id, incoming_orders, incoming_demand_units, opening_backlog_units, units_picked, closing_backlog_units, incident_id) FROM 'raw_hourly_demand.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.raw_hourly_backlog (time_bucket, facility_id, opening_backlog_units, incoming_units, picked_units, closing_backlog_units, incident_id) FROM 'raw_hourly_backlog.csv' WITH (FORMAT csv, HEADER true);

\copy raw_data.simulation_truth (incident_id, true_root_cause, true_impact_units, capacity_reduction_pct, true_incident_flag) FROM 'simulation_truth.csv' WITH (FORMAT csv, HEADER true);


-- ============================================================
-- 10. RAW VALIDATION
-- ============================================================

-- Customers
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM raw_data.raw_customers;


-- Products
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT product_id) AS distinct_product_ids,
    COUNT(DISTINCT sku) AS distinct_skus
FROM raw_data.raw_products;


-- Orders
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM raw_data.raw_orders;


-- Orphan order items
SELECT COUNT(*) AS orphan_order_items
FROM raw_data.raw_order_items oi
LEFT JOIN raw_data.raw_orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- Orphan product references
SELECT COUNT(*) AS orphan_product_items
FROM raw_data.raw_order_items oi
LEFT JOIN raw_data.raw_products p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- Backlog reconciliation
SELECT COUNT(*) AS backlog_reconciliation_errors
FROM raw_data.raw_hourly_backlog
WHERE opening_backlog_units
    + incoming_units
    - picked_units
    <> closing_backlog_units;


-- Incident timeline
SELECT COUNT(*) AS invalid_incident_timelines
FROM raw_data.raw_incident_logs
WHERE NOT (
       t0_genesis <= t1_detection
   AND t1_detection <= t2_escalation
   AND t2_escalation <= t3_intervention
   AND t3_intervention <= t4_pil
   AND t4_pil <= t5_recovery
);


-- Incident -> simulation truth
SELECT COUNT(*) AS incidents_without_truth
FROM raw_data.raw_incident_logs i
LEFT JOIN raw_data.simulation_truth t
    ON i.incident_id = t.incident_id
WHERE t.incident_id IS NULL;


-- ============================================================
-- V2 DATASET ROW-COUNT VALIDATION
-- ============================================================

DO $$
BEGIN

    IF (SELECT COUNT(*) FROM raw_data.raw_customers) <> 200 THEN
        RAISE EXCEPTION 'Unexpected customer row count';
    END IF;

    IF (SELECT COUNT(*) FROM raw_data.raw_products) <> 50 THEN
        RAISE EXCEPTION 'Unexpected product row count';
    END IF;

    IF (SELECT COUNT(*) FROM raw_data.raw_orders) <> 5636 THEN
        RAISE EXCEPTION 'Unexpected order row count';
    END IF;

    IF (SELECT COUNT(*) FROM raw_data.raw_order_items) <> 85221 THEN
        RAISE EXCEPTION 'Unexpected order-item row count';
    END IF;

    IF (SELECT COUNT(*) FROM raw_data.raw_incident_logs) <> 3 THEN
        RAISE EXCEPTION 'Unexpected incident row count';
    END IF;

    IF (SELECT COUNT(*) FROM raw_data.simulation_truth) <> 3 THEN
        RAISE EXCEPTION 'Unexpected simulation-truth row count';
    END IF;

END $$;


-- ============================================================
-- END
-- ============================================================