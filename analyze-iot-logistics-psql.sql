
---

## analyze-iot-logistics-psql.sql

```sql
-- ============================================================================
-- IoT Logistics Fleet Telemetry Workshop (TimescaleDB + PostGIS)
-- ============================================================================
-- Telemetry + GPS location generated every 5 seconds per truck
-- ============================================================================

-- \timing on

CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS postgis;

DROP TABLE IF EXISTS truck_telemetry CASCADE;
DROP TABLE IF EXISTS trucks CASCADE;
DROP TABLE IF EXISTS cities CASCADE;

-- ---------------------------------------------------------------------------
-- Generator parameters (override in psql if needed)
-- ---------------------------------------------------------------------------
\set num_trucks 10000
\set months_back 24
\set step_seconds 5
\set batch_days 1
\set batch_trucks 1000

-- ---------------------------------------------------------------------------
-- Cities
-- ---------------------------------------------------------------------------
CREATE TABLE cities (
  id SERIAL PRIMARY KEY,
  name TEXT,
  location GEOGRAPHY(POINT, 4326)
);

INSERT INTO cities (name, location) VALUES
 ('Seattle', ST_SetSRID(ST_MakePoint(-122.3321,47.6062),4326)::geography),
 ('San Francisco', ST_SetSRID(ST_MakePoint(-122.4194,37.7749),4326)::geography),
 ('Los Angeles', ST_SetSRID(ST_MakePoint(-118.2437,34.0522),4326)::geography),
 ('Denver', ST_SetSRID(ST_MakePoint(-104.9903,39.7392),4326)::geography),
 ('Chicago', ST_SetSRID(ST_MakePoint(-87.6298,41.8781),4326)::geography);

-- ---------------------------------------------------------------------------
-- Trucks
-- ---------------------------------------------------------------------------
CREATE TABLE trucks (
  id INTEGER PRIMARY KEY,
  origin_city_id INTEGER REFERENCES cities(id),
  dest_city_id INTEGER REFERENCES cities(id),
  seed DOUBLE PRECISION
);

INSERT INTO trucks
SELECT
  t,
  (t % 5) + 1,
  ((t + 2) % 5) + 1,
  random()
FROM generate_series(1, :num_trucks) t;

-- ---------------------------------------------------------------------------
-- Telemetry hypertable (includes geolocation)
-- ---------------------------------------------------------------------------
CREATE TABLE truck_telemetry (
  time TIMESTAMPTZ NOT NULL,
  truck_id INTEGER NOT NULL,
  location GEOGRAPHY(POINT, 4326),
  speed_kph DOUBLE PRECISION,
  heading_deg DOUBLE PRECISION,
  engine_temp_c DOUBLE PRECISION,
  fuel_pct DOUBLE PRECISION,
  cargo_kg DOUBLE PRECISION,
  origin_city_id INTEGER,
  dest_city_id INTEGER
) WITH (
  tsdb.hypertable,
  tsdb.partition_column='time',
  tsdb.segmentby='truck_id',
  tsdb.orderby='time DESC'
);

CREATE INDEX ON truck_telemetry (truck_id, time DESC);
CREATE INDEX ON truck_telemetry USING GIST (location);

-- ---------------------------------------------------------------------------
-- Route interpolation function
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION truck_route_point(
  truck INT,
  ts TIMESTAMPTZ,
  start_ts TIMESTAMPTZ
) RETURNS GEOGRAPHY
LANGUAGE SQL STABLE AS $$
WITH t AS (
  SELECT tr.seed, c1.location o, c2.location d
  FROM trucks tr
  JOIN cities c1 ON c1.id = tr.origin_city_id
  JOIN cities c2 ON c2.id = tr.dest_city_id
  WHERE tr.id = truck
),
p AS (
  SELECT mod(extract(epoch FROM (ts - start_ts)), 28800) / 28800.0 f FROM t
)
SELECT ST_LineInterpolatePoint(
  ST_MakeLine(o::geometry, d::geometry),
  f
)::geography
FROM t, p;
$$;

-- ---------------------------------------------------------------------------
-- Generate telemetry + GPS every 5 seconds
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  start_ts TIMESTAMPTZ := now() - make_interval(months => :months_back);
  end_ts   TIMESTAMPTZ := now();
  t_start  TIMESTAMPTZ;
  t_end    TIMESTAMPTZ;
BEGIN
  t_start := start_ts;

  WHILE t_start < end_ts LOOP
    t_end := LEAST(t_start + make_interval(days => :batch_days), end_ts);

    INSERT INTO truck_telemetry
    SELECT
      ts,
      tr.id,
      truck_route_point(tr.id, ts, start_ts),
      40 + random() * 70,
      random() * 360,
      70 + random() * 40,
      10 + random() * 90,
      random() * 20000,
      tr.origin_city_id,
      tr.dest_city_id
    FROM generate_series(t_start, t_end, make_interval(secs => :step_seconds)) ts
    JOIN trucks tr ON tr.id <= :batch_trucks;

    t_start := t_end;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- Example geospatial queries
-- ---------------------------------------------------------------------------

-- Trucks within 25km of Seattle in last hour
SELECT truck_id, time
FROM truck_telemetry t
JOIN cities c ON c.name='Seattle'
WHERE t.time > now() - interval '1 hour'
AND ST_DWithin(t.location, c.location, 25000);

-- Distance traveled per truck per day
WITH d AS (
  SELECT
    time_bucket('1 day', time) day,
    truck_id,
    ST_Distance(location,
      LAG(location) OVER (PARTITION BY truck_id ORDER BY time)) m
  FROM truck_telemetry
)
SELECT day, truck_id, sum(coalesce(m,0))/1000 km
FROM d
GROUP BY day, truck_id;

-- Enable compression
CALL add_columnstore_policy('truck_telemetry', after => INTERVAL '7 days');

