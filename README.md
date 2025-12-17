
# TimeSeries Workshop - IoT Logistics Fleet Telemetry

## Overview

This workshop demonstrates advanced time-series and geospatial data analysis using PostgreSQL and TigerData (TimescaleDB) for IoT logistics.

The use case models a fleet of trucks transporting cargo between cities. Each truck emits telemetry and GPS location (latitude/longitude) every 5 seconds, enabling real-time fleet tracking, route analytics, geofencing, and distance-based operational insights.

Telemetry includes:

- Timestamp
- GPS location (latitude/longitude)
- Speed (km/h)
- Heading (degrees)
- Engine temperature (°C)
- Fuel level (%)
- Cargo weight (kg)
- Origin city and destination city

## What You’ll Learn

- **Hypertables**: Store high-frequency IoT telemetry efficiently using TimescaleDB
- **Working with Fleet Telemetry Data**: Work with sample generated fleet IoT data (telemetry + GPS)
- **Geospatial Analytics (PostGIS)**: Perform geofencing, proximity, and distance calculations
- **Columnar Compression**: Reduce storage footprint while improving query performance
- **Continuous Aggregates**: Pre-compute daily summaries for fast analytics
- **Real-Time Updates**: Build materialized views that update as new data arrives

## Contents

- **`analyze-iot-logistics-psql.sql`**: Complete workshop script

## Prerequisites

- TimescaleDB (Timescale Cloud or self-hosted)
- PostgreSQL 14+
- PostGIS extension (enabled automatically by the script)
- Basic SQL knowledge
- Optional, but recommended: install psql CLI  
  https://www.tigerdata.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows

## Data Structure

### Truck Telemetry Table

```sql
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
);
````

### Cities Table

```sql
CREATE TABLE cities (
   id SERIAL PRIMARY KEY,
   name TEXT,
   location GEOGRAPHY(POINT, 4326)
);
```

### Trucks Table

```sql
CREATE TABLE trucks (
   id INTEGER PRIMARY KEY,
   origin_city_id INTEGER,
   dest_city_id INTEGER
);
```

## Synthetic Data Generation

The workshop script generates a **manageable dataset** using:

* **1,000 trucks**
* **7 days of history**
* **1 reading every 5 seconds per truck**

This yields ~120 million rows, which is large enough to demonstrate:

* Time-series ingestion performance
* Query performance with and without compression
* Geospatial analysis (geofencing, proximity, distance)
* Continuous aggregate speedups

The synthetic movement model approximates trucking routes between cities and interpolates GPS points along those routes using a deterministic journey model written entirely in SQL.

## Getting Started

Run the workshop SQL script in your PostgreSQL client:

```bash
psql -h <host> -U <user> -d <db> -f analyze-iot-logistics-psql.sql
```

or choose your preferred SQL client.

Follow the comments in the script step by step.

## Sample Queries

### Latest Known Position per Truck

```sql
SELECT DISTINCT ON (truck_id)
  truck_id, time, location, speed_kph, fuel_pct
FROM truck_telemetry
ORDER BY truck_id, time DESC;
```

### Trucks in a Geofence (Example Polygon)

```sql
WITH fence AS (
  SELECT ST_GeomFromText(
    'POLYGON((-122.36 47.58,-122.36 47.66,-122.28 47.66,-122.28 47.58,-122.36 47.58))',
    4326
  )::geography AS poly
)
SELECT
  time, truck_id
FROM truck_telemetry, fence
WHERE ST_Contains(fence.poly::geometry, truck_telemetry.location::geometry)
  AND time >= NOW() - INTERVAL '30 minutes';
```

### Distance Traveled per Truck (Daily)

```sql
WITH daily AS (
  SELECT
    time_bucket('1 day', time) AS day,
    truck_id,
    ST_Distance(
      location,
      LAG(location) OVER (PARTITION BY day, truck_id ORDER BY time)
    ) AS dist
  FROM truck_telemetry
)
SELECT day, truck_id, SUM(COALESCE(dist,0)) / 1000 AS km_traveled
FROM daily
GROUP BY day, truck_id;
```

## Compression & Continuous Aggregates

### Enable Automatic Compression

```sql
CALL add_columnstore_policy('truck_telemetry', after => INTERVAL '1 day');
```

### Create Continuous Aggregate (Daily Distance)

```sql
CREATE MATERIALIZED VIEW daily_truck_distance_km
WITH (
  timescaledb.continuous,
  timescaledb.materialized_only = false
) AS
SELECT
  time_bucket('1 day', time) AS day,
  truck_id,
  SUM(distance_meters)/1000 AS km_traveled
FROM (
  SELECT
    time,
    truck_id,
    ST_Distance(
      location,
      LAG(location) OVER (PARTITION BY truck_id ORDER BY time)
    ) AS distance_meters
  FROM truck_telemetry
) sub
GROUP BY day, truck_id;
```

## Intended Audience

* Data engineers
* Platform engineers
* Architects
* Developers building IoT, logistics, or geospatial analytics systems



## (Optional) Visualizing Fleet Telemetry with Grafana

This optional section walks through launching **Grafana locally using Docker**, connecting it to your TimescaleDB (TigerData) database, and building a simple dashboard to visualize fleet telemetry and geospatial data.

### Prerequisites

- Docker installed locally  
  https://docs.docker.com/get-docker/
- A running TimescaleDB database (Timescale Cloud or self-hosted)
- Database connection details:
  - Host
  - Database name
  - Username
  - Password
  - Port (typically 5432)

## Launch Grafana Using Docker

Run the following command to start Grafana locally:

```bash
docker run -d \
  --name grafana \
  -p 3000:3000 \
  grafana/grafana:latest
````

Grafana will be available at:

```
http://localhost:3000
```

Default login credentials:

* **Username:** admin
* **Password:** admin
  (You will be prompted to change the password on first login.)

## Connect Grafana to TimescaleDB (TigerData)

1. In Grafana, go to **Connections → Data sources**
2. Click **Add data source**
3. Select **PostgreSQL**

Fill in the connection details:

* **Host:** `<your-timescaledb-host>:5432`
* **Database:** `<database_name>`
* **User:** `<username>`
* **Password:** `<password>`
* **SSL Mode:** `require` (recommended for Timescale Cloud)

Additional settings:

* **TimescaleDB:** ✅ Enable
* **PostgreSQL Version:** 14+

Click **Save & Test** to verify the connection.

## Create a Fleet Telemetry Dashboard

1. Go to **Dashboards → New → New Dashboard**
2. Click **Add a new panel**
3. Select your PostgreSQL data source

## Sample Queries for Grafana Panels

### 1. Fleet Speed Over Time

```sql
SELECT
  $__time(time),
  AVG(speed_kph) AS avg_speed_kph
FROM truck_telemetry
WHERE $__timeFilter(time)
GROUP BY 1
ORDER BY 1;
```

Suggested visualization:

* **Time series**
* Y-axis: Average speed (km/h)

### 2. Active Trucks (Last Known Positions)

```sql
SELECT DISTINCT ON (truck_id)
  time AS "time",
  truck_id,
  ST_Y(location::geometry) AS latitude,
  ST_X(location::geometry) AS longitude
FROM truck_telemetry
WHERE time >= NOW() - INTERVAL '5 minutes'
ORDER BY truck_id, time DESC;
```

Suggested visualization:

* **Geomap**
* Latitude: `latitude`
* Longitude: `longitude`

### 3. Trucks Within a Depot Radius (Example: Vancouver)

```sql
WITH depot AS (
  SELECT location AS city_loc
  FROM cities
  WHERE name = 'Vancouver'
)
SELECT
  t.time,
  t.truck_id,
  ST_Distance(t.location, depot.city_loc) / 1000 AS km_from_vancouver
FROM truck_telemetry t, depot
WHERE $__timeFilter(t.time)
  AND ST_DWithin(t.location, depot.city_loc, 25000);
```

Suggested visualization:

* **Table**
* Columns: truck_id, km_from_vancouver, time

### 4. Distance Traveled Per Truck (Daily)

```sql
SELECT
  day,
  truck_id,
  km_traveled
FROM daily_truck_summary
WHERE $__timeFilter(day)
ORDER BY day DESC, km_traveled DESC;
```

Suggested visualization:

* **Bar chart** or **Table**

## Add Panels to a Dashboard

For each query:

1. Paste the SQL into the panel editor
2. Choose an appropriate visualization
3. Adjust axes, units, and legends
4. Click **Apply**

Repeat to build a multi-panel dashboard showing:

* Fleet speed trends
* Live truck locations
* Geofence proximity
* Distance traveled per truck

## Suggested Dashboard Layout

* **Top row:** Fleet-wide metrics (average speed, active trucks)
* **Middle row:** Live map of truck locations
* **Bottom row:** Distance traveled and fuel usage tables

## Summary

Using Grafana with TimescaleDB enables:

* Real-time fleet monitoring
* Interactive geospatial visualization
* Fast analytics over high-volume IoT telemetry
* Production-ready dashboards with minimal setup

This setup mirrors common production architectures for logistics and fleet-tracking platforms.

## License

MIT License
