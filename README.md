# TimeSeries Workshop - IoT Logistics Fleet Telemetry

## Overview

This workshop demonstrates advanced time-series and geospatial data analysis using PostgreSQL and TigerData (TimescaleDB) for an **IoT logistics** use case,  
eg track telemetry from a fleet of trucks moving cargo between cities. Tracking geolocation data is essential.

Each truck generates readings including:

- GPS Location (Latitude/Longitude)
- Speed (km/h)
- Heading (degrees)
- Engine Temperature (C)
- Fuel Level (%)
- Cargo Weight (kg)
- Origin + Destination City (for the current route)

Use case: Fleet monitoring, route compliance, geofencing, proximity search, and logistics analytics

## What You'll Learn

- **Hypertables**: Convert regular PostgreSQL tables into time-series optimized hypertables

- **Working with IoT Logistics Data**: Work with sample generated fleet telemetry data (telemetry + GPS)

- **IoT Logistics Data Analysis**: Geofencing, proximity, and distance-based analytics

- **Columnar Compression**: Achieve ~10x storage reduction while improving query performance

- **Continuous Aggregates**: Pre-compute aggregations for lightning-fast analytics

- **Real-time Updates**: Build materialized views that update automatically as new data arrives

## Contents

- **`analyze-iot-logistics-psql.sql`**: Complete workshop for psql command-line interface

## Prerequisites

- Timescale Cloud account (get free trial at <https://console.cloud.timescale.com/signup>)

- Optional, but recommended - install psql CLI https://www.tigerdata.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows

- Basic knowledge of SQL and relational data concepts

## Sample Architecture with TigerData

![Sample Architecture with TigerData](https://imgur.com/j1H6zxv.png)

## Architecture highlights

- **Unified Data Flow**: Ingest data from files, streams, IoT devices, and APIs into the TigerData Cloud Service (AWS or Azure)
  
- **Centralized Storage**: Data is organized in the TigerData Cloud Service for analytics, AI, and ML applications (with built in compression and continous real-time aggregations) 
  
- **Real-Time Analytics**: Enables SQL-based queries, dashboards, alerts, and visualizations using Grafana or other tools
  
- **AI & ML Integration**: Connects seamlessly with ChatGPT and Amazon SageMaker for data enrichment and devops automation

## Data Structure

### Truck Telemetry Table

Telemetry + geolocation are recorded in the same row (default every **5 seconds** per truck):

```sql
CREATE TABLE truck_telemetry (
   time TIMESTAMPTZ NOT NULL,
   truck_id INTEGER NOT NULL,
   location GEOGRAPHY(POINT, 4326),  -- GPS location (lon/lat)
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
````

### Cities Table

```sql
CREATE TABLE cities(
   id SERIAL PRIMARY KEY,
   name TEXT,
   location GEOGRAPHY(POINT, 4326)
);
```

### Trucks Table

```sql
CREATE TABLE trucks(
   id INTEGER PRIMARY KEY,
   origin_city_id INTEGER,
   dest_city_id INTEGER
);
```

## Key Features Demonstrated

### 1. Hypertable Creation

Time-series optimized hypertables for fleet telemetry:

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
) WITH (
   tsdb.hypertable,
   tsdb.partition_column='time',
   tsdb.segmentby='truck_id',
   tsdb.orderby='time DESC'
);
```

### 2. Generate Data & Run Analytical Queries

The workshop script generates synthetic data for:

* configurable number of trucks
* configurable months of history
* configurable seconds between readings (default 5 seconds)

Example: find trucks within a geofence polygon during a time window

```sql
WITH fence AS (
  SELECT ST_GeomFromText(
    'POLYGON((-122.36 47.58,-122.36 47.66,-122.28 47.66,-122.28 47.58,-122.36 47.58))',
    4326
  )::geography AS poly
)
SELECT time, truck_id
FROM truck_telemetry, fence
WHERE time >= now() - interval '30 minutes'
  AND ST_Contains(fence.poly::geometry, truck_telemetry.location::geometry);
```

Example: trucks within N km of a city/depot

```sql
WITH depot AS (
  SELECT location AS city_loc
  FROM cities
  WHERE name = 'Vancouver'
)
SELECT t.time, t.truck_id
FROM truck_telemetry t, depot
WHERE t.time >= now() - interval '1 hour'
  AND ST_DWithin(t.location, depot.city_loc, 25000);
```

Example: distance traveled per truck per day (approx via consecutive GPS points)

```sql
WITH daily AS (
  SELECT
    time_bucket('1 day', time) AS day,
    truck_id,
    time,
    location
  FROM truck_telemetry
  WHERE time >= now() - interval '7 days'
),
segments AS (
  SELECT
    day,
    truck_id,
    ST_Distance(
      location,
      LAG(location) OVER (PARTITION BY day, truck_id ORDER BY time)
    ) AS meters
  FROM daily
)
SELECT
  day,
  truck_id,
  SUM(COALESCE(meters,0))/1000.0 AS km_traveled
FROM segments
GROUP BY day, truck_id;
```

Example: distance from point of origin (origin city)

```sql
WITH origin AS (
  SELECT tr.id AS truck_id, c.location AS origin_loc
  FROM trucks tr
  JOIN cities c ON c.id = tr.origin_city_id
),
latest AS (
  SELECT DISTINCT ON (truck_id) truck_id, time, location
  FROM truck_telemetry
  ORDER BY truck_id, time DESC
)
SELECT
  latest.truck_id,
  latest.time,
  ST_Distance(latest.location, origin.origin_loc)/1000.0 AS km_from_origin
FROM latest
JOIN origin ON origin.truck_id = latest.truck_id
ORDER BY km_from_origin DESC
LIMIT 50;
```

### 3. Columnar Compression

Enable ~10x storage compression with improved query performance:

```sql
CALL add_columnstore_policy('truck_telemetry', after => INTERVAL '7d');
```

### 4. Real Time Continuous Aggregates

Create self-updating materialized views for instant analytics (example: daily distance per truck):

```sql
CREATE MATERIALIZED VIEW daily_truck_distance_km
WITH (
   timescaledb.continuous,
   timescaledb.materialized_only = false
) AS
WITH daily AS (
  SELECT
    time_bucket('1 day', time) AS day,
    truck_id,
    time,
    location
  FROM truck_telemetry
),
segments AS (
  SELECT
    day,
    truck_id,
    ST_Distance(
      location,
      LAG(location) OVER (PARTITION BY day, truck_id ORDER BY time)
    ) AS meters
  FROM daily
)
SELECT
  day,
  truck_id,
  SUM(COALESCE(meters,0))/1000.0 AS km_traveled
FROM segments
GROUP BY day, truck_id;

SELECT add_continuous_aggregate_policy(
   'daily_truck_distance_km',
   start_offset => INTERVAL '14 days',
   end_offset => INTERVAL '1 day',
   schedule_interval => INTERVAL '1 day'
);
```

## Getting Started

### Using psql Command Line

1. Follow the instructions in `analyze-iot-logistics-psql.sql`

2. The script will generate sample data and guide you through each step

3. Includes timing comparisons to demonstrate performance improvements

## Workshop Highlights

* **Fleet Telemetry + GPS**: Work with sample generated IoT logistics data (telemetry and geolocation every 5 seconds)
* **Geospatial Analytics**: Geofencing, proximity search, and distance traveled analytics with PostGIS
* **Performance Optimization**: Compare query times before and after compression
* **Storage Efficiency**: See ~10x storage reduction with columnar compression
* **Automatic Updates**: Demonstrate real-time continuous aggregate updates
* **Production Ready**: Learn policies for automatic compression and aggregate refreshing

## Performance Benefits

* **Hypertables**: Automatic partitioning for optimal time-series queries
* **Geospatial Indexing**: Fast geofence and proximity queries using GiST indexes
* **Columnar Storage**: Significant storage reduction with faster analytical queries
* **Continuous Aggregates**: Sub-second response times for common rollups
* **Automatic Policies**: Set-and-forget data lifecycle management

## License
