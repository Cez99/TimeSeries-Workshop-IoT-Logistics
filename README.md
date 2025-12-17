# TimeSeries Workshop – IoT Logistics Fleet Telemetry

## Overview

This workshop demonstrates advanced time-series and geospatial analytics using PostgreSQL with TimescaleDB for an IoT logistics use case.

The scenario models a fleet of trucks transporting cargo between cities. Each truck emits telemetry and GPS geolocation data every 5 seconds, enabling real-time fleet tracking, geofencing, route analysis, and historical movement analytics.

Telemetry captured per truck includes:

- Timestamp
- GPS location (latitude / longitude)
- Speed (km/h)
- Heading (degrees)
- Engine temperature (°C)
- Fuel level (%)
- Cargo weight (kg)
- Origin city and destination city

Use cases include fleet monitoring, logistics optimization, geofencing alerts, route compliance, distance analytics, and operational reporting.

---

## What You’ll Learn

- Hypertables for high-frequency IoT telemetry using TimescaleDB
- IoT data modeling for large-scale fleet tracking
- Synthetic data generation for multi-month time-series workloads
- Geospatial analytics using PostGIS (geofencing, proximity, distance)
- Columnar compression for storage and query optimization
- Continuous aggregates for fast daily analytics
- Data lifecycle policies for time-series data

---

## Contents

- analyze-iot-logistics-psql.sql  
  Complete workshop script designed to be run from the psql command-line interface

---

## Prerequisites

- TimescaleDB (Timescale Cloud or self-hosted)
- psql CLI  
  https://www.tigerdata.com/blog/how-to-install-psql-on-mac-ubuntu-debian-windows
- Basic knowledge of SQL
- PostGIS extension enabled (created automatically by the script)

---

## Important Note on Dataset Size

A realistic production configuration of:

- 10,000 trucks  
- 24 months of history  
- 1 telemetry and GPS reading every 5 seconds per truck  

results in hundreds of billions of rows.

For this reason, the workshop script is fully parameterized and supports batch-based data generation. Start with smaller values and scale up gradually.

Adjustable parameters include:

- Number of trucks
- Months of historical data
- Seconds between telemetry readings
- Batch size (time window)
- Batch size (truck ranges)

---

## Data Structure

### Fleet Telemetry Table

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
   tsdb.partition_column = 'time',
   tsdb.segmentby = 'truck_id',
   tsdb.orderby = 'time DESC'
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

## Key Features Demonstrated

### High-Frequency IoT Telemetry

Each truck emits telemetry and GPS coordinates every 5 seconds, simulating real-world fleet tracking systems.

### Parameterized Data Generation

The workshop generates synthetic telemetry using pure SQL. You can control:

* Fleet size
* Historical time range
* Sampling interval
* Batch sizes for safe scaling

### Geospatial Analytics (PostGIS)

Example queries included:

* Trucks inside a geographic boundary (geofence) at a given time
* Trucks within a given distance of a city or depot
* Distance traveled per truck per day
* Current distance from origin city
* Detection of geofence entry events

### Columnar Compression

Enable automatic compression of older telemetry data:

```sql
CALL add_columnstore_policy('truck_telemetry', after => INTERVAL '7 days');
```

### Continuous Aggregates

Create self-updating materialized views for daily fleet analytics such as distance traveled per truck.

---

## Getting Started

Using the psql command line:

1. Connect to your TimescaleDB instance using psql
2. Run the workshop script:

```bash
\i analyze-iot-logistics-psql.sql
```

3. Start with small parameter values and scale up gradually

---

## Workshop Highlights

* Realistic IoT logistics telemetry
* High-ingest time-series modeling
* Built-in geospatial analytics
* Storage and performance optimization
* Production-ready patterns for fleet telemetry workloads

---

## Intended Audience

* Data engineers
* Platform engineers
* Architects
* Developers working with IoT, logistics, fleet tracking, or geospatial analytics

---

## License

```
