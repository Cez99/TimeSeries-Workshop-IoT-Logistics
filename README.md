# TimeSeries Workshop – IoT Logistics Fleet Telemetry

## Overview

This workshop demonstrates time-series and geospatial analytics using PostgreSQL and TigerData (TimescaleDB) for an **IoT logistics** use case.

The scenario models a fleet of trucks transporting cargo between cities. Each truck generates **telemetry and GPS geolocation data every 5 seconds**, enabling real-time fleet tracking, geofencing, proximity analysis, and historical movement analytics.

Typical use cases include fleet monitoring, route compliance, logistics optimization, geofencing alerts, and distance-based analytics.

---

## What You’ll Learn

- **Hypertables**  
  Convert regular PostgreSQL tables into time-series optimized hypertables

- **Working with IoT Logistics Data**  
  Analyze high-frequency fleet telemetry and GPS data

- **Geospatial Analytics (PostGIS)**  
  Perform geofencing, proximity, and distance calculations

- **Columnar Compression**  
  Reduce storage by ~10x while improving analytical query performance

- **Continuous Aggregates**  
  Precompute rollups for fast, scalable analytics

- **Real-Time Updates**  
  Query materialized views that automatically stay up to date as new data arrives

---

## Contents

- **`analyze-iot-logistics-psql.sql`**  
  Complete workshop script designed to be run as plain SQL in any PostgreSQL client

---

## Prerequisites

- TimescaleDB (Timescale Cloud or self-hosted)
- PostgreSQL 14+
- PostGIS extension (enabled automatically by the script)
- Basic SQL knowledge

Optional:
- `psql` CLI  
  https://www.tigerdata.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows

---

## Dataset Size (Workshop Defaults)

The default configuration in this workshop intentionally uses a **manageable but realistic dataset**:

- **1,000 trucks**
- **7 days of history**
- **1 telemetry + GPS reading every 5 seconds**

This generates approximately **120 million rows**, which is large enough to:

- demonstrate hypertable performance
- show the impact of compression
- highlight continuous aggregate speedups
- run meaningful geospatial queries

The SQL script is written in **plain SQL** with clearly labeled constants, making it easy to scale the dataset up or down by editing the data generation section.

---

## Data Model

### Fleet Telemetry Table

Telemetry and GPS location are recorded together in a single hypertable.

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

---

## Sample Architecture with TigerData

![Sample Architecture with TigerData](https://imgur.com/j1H6zxv.png)

---

## Workshop Flow

The SQL script follows a structured workshop flow:

1. Enable TimescaleDB and PostGIS
2. Create reference tables (cities, trucks)
3. Create a telemetry hypertable
4. Generate synthetic fleet telemetry + GPS data
5. Run baseline analytical queries
6. Enable compression and observe storage savings
7. Re-run queries on compressed data
8. Create and query continuous aggregates
9. Demonstrate real-time updates

This mirrors common production workflows for IoT and logistics platforms.

---

## Example Analytics

### Fleet Telemetry Analysis

* Trucks reporting high engine temperatures
* Average speed by time window
* Fuel usage trends

### Geospatial Analytics

* Trucks inside a geofence polygon
* Trucks within a given distance of a depot
* Distance traveled per truck per day
* Distance from origin city
* Entry detection into a geographic boundary

---

## Compression and Storage Optimization

Enable columnar compression to significantly reduce storage footprint:

```sql
CALL add_columnstore_policy('truck_telemetry', after => INTERVAL '1 day');
```

Compression typically provides:

* ~10x storage reduction
* faster analytical queries
* lower infrastructure costs

---

## Continuous Aggregates

Continuous aggregates precompute expensive queries and keep them up to date automatically.

Example: daily distance traveled per truck

```sql
SELECT *
FROM daily_truck_summary
WHERE day >= NOW() - INTERVAL '7 days'
ORDER BY day DESC;
```

This enables sub-second analytics over large telemetry datasets.

---

## Getting Started

1. Connect to your TimescaleDB instance
2. Run the workshop script:

```sql
\i analyze-iot-logistics-psql.sql
```

(or execute the file using your SQL client)

3. Follow the comments in the SQL file step by step

---

## Intended Audience

* Data engineers
* Platform engineers
* Solution architects
* Developers working with:

  * IoT platforms
  * Fleet tracking systems
  * Logistics and supply chain analytics
  * Geospatial data

---

## License
