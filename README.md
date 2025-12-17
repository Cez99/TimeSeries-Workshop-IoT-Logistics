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
  
- **R**


---

## License

```
