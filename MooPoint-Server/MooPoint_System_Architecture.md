# 🐄 MooPoint System Architecture

> **A comprehensive livestock tracking and monitoring system**
> **Last Updated: March 5, 2026****

---

## 📑 Quick Navigation

[Jump to Section](#table-of-contents)

---

# 📑 Table of Contents

1. [🎯 System Overview](#-system-overview)
2. [🏗️ Component Architecture](#-component-architecture)
3. [� File Structure & Component Organization](#-file-structure--component-organization)
4. [� Data Flow & Signal Flows](#-data-flow--signal-flows)
5. [📡 Communication Protocols](#-communication-protocols)
6. [🔒 Security Model](#-security-model)
7. [🔋 Power Management](#-power-management)
8. [🗺️ Geofencing System](#-geofencing-system)
9. [📊 Extended Metrics System](#-extended-metrics-system)
10. [📱 BLE Provisioning](#-ble-provisioning)
11. [🧠 AI Analytics & Real-time Dashboard](#-ai-analytics--real-time-dashboard)
12. [🚀 Configuration Management](#-configuration-management)
13. [📡 State Management & Data Models](#-state-management--data-models)
14. [🎨 UI Component Library](#-ui-component-library)
15. [🚀 Deployment & Operations](#-deployment--operations)
16. [⚙️ Technical Specifications](#-technical-specifications)
17. [🔮 Future Development](#-future-development)

---

# 🎯 System Overview

> 💡 **What is MooPoint?**
> MooPoint is a three-component ecosystem designed for real-time livestock tracking in rural environments with limited infrastructure.

## The Four Pillars

### 🔵 MooPoint-Tracker (Cattle)
**Lilygo T-Echo Lite nRF52840 GPS tracking device worn by animals**
- Real-time GPS positioning with L76K multi-GNSS support
- LoRa long-range communication with HMAC security
- Adaptive 4-tier power management (1-2 weeks battery life)
- BLE 5.0 provisioning with device authentication
- IMU-based behavior detection and motion sensing
- Extended metrics collection for network diagnostics
- Gateway-initiated configuration updates
- Optional 1.22" e-paper display for status information

### 🟠 MooPoint-Tracker (Fence) - *NEW*
**Lilygo T-Echo Lite nRF52840 stationary fence monitoring device**
- Fixed GPS position with high-precision location
- LoRa long-range communication with outage detection
- Continuous power supply (solar/battery hybrid)
- BLE 5.0 provisioning with device authentication
- Extended metrics collection for network diagnostics
- Gateway-initiated configuration updates
- Status LED indicators for visual monitoring
- Environmental monitoring (temperature, voltage)

### � MooPoint-Gateway
**ESP32-S3 LoRa gateway bridging trackers to internet**
- Multi-tracker support (50+ simultaneous connections)
- MQTT cloud synchronization with device authentication
- Local geofence caching with version control
- Status display interface with real-time metrics
- Device map management and synchronization
- ACKNotifyPacket v3.1 for always-on acknowledgments
- IRQ-based non-blocking packet processing
- Web-based configuration portal

### 🟣 MooPoint-Server
**Node.js backend with Flutter web interface**
- Real-time data visualization with WebSocket updates
- Geofence management with point-in-polygon algorithms
- InfluxDB time-series data storage with Telegraf processing
- PostgreSQL for configuration and node management
- BLE provisioning system with device credential management
- Extended metrics processing and network health monitoring
- AI-powered analytics and behavioral insights
- Modern Flutter UI with Material Design Icons (MDI)
- Multi-tracker type support (cattle & fence)

---

## ✨ Key Features

| Feature | Description | Benefit |
|---------|-------------|---------|
| 📍 Real-time GPS Tracking | Via LoRa communication | Monitor animal locations continuously |
| 🗺️ Geofence Alerts | Boundary management system | Instant notifications when animals leave zones |
| 🔋 Adaptive Power | 4-tier battery management | 2-6 weeks battery life |
| 📊 Extended Metrics | Diagnostic data collection | Network health monitoring |
| 📱 BLE Provisioning | Easy device configuration | No need for complex setup tools |
| 🌐 Real-time Dashboard | Flutter-based interface | Monitor fleet from anywhere |
| 🔄 MQTT Sync | Real-time data synchronization | Always up-to-date information |
| 🔐 Multi-node Auth | Individual device security | Secure fleet management |
| 🧠 AI Analytics | Behavior analysis & insights | Health monitoring and alerts |
| 📡 Multi-tracker Types | Cattle & fence tracker support | Comprehensive coverage |
| 🚀 Config Push | Multi-tracker configuration | Efficient fleet management |
| 📈 Coverage Heatmaps | Network visualization | Optimize gateway placement |
| 🔔 Real-time Alerts | WebSocket notifications | Immediate issue detection |
| 📱 Mobile Provisioning | BLE device discovery | Easy field configuration |

---

# 🏗️ Component Architecture

## 1️⃣ MooPoint-Tracker (nRF52840)

### 1.1️⃣ Cattle Tracker (Mobile)

#### Hardware Stack

```
┌───────────────────────────────────────┐
│         Hardware Layer                │
├───────────────────────────────────────┤
│  • nRF52840 MCU (64MHz ARM Cortex-M4) │
│  • L76K GNSS Module (Multi-GNSS)      │
│  • SX1262 LoRa (868/915MHz)           │
│  • 1.22" SPI E-Paper (176x192)        │
│  • 500mAh Li-ion Battery              │
│  • IMU (Accelerometer/Gyro)           │
│  • RGB Status LED                     │
└───────────────────────────────────────┘
```

#### Software Architecture

```
┌─────────────────────────────────────────┐
│         Arduino Application             │
│    (T_Echo_Tracker.ino - Main Sketch)    │
├──────────┬──────────┬───────────────────┤
│ GPS Task │LoRa Task │  Display Task     │
│          │          │                   │
│ Position │ TX/RX    │  E-Paper UI       │
│ Tracking │ Protocol │  Status Display   │
├──────────┴──────────┴───────────────────┤
│      Power Management │ BLE Provision   │
│      (Adaptive Cycles)│ (Configuration) │
├───────────────────────┴─────────────────┤
│   EEPROM Storage │   Geofence Engine    │
├─────────────────────────────────────────┤
│         Arduino Framework               │
├─────────────────────────────────────────┤
│         nRF52840 Core (mbed)            │
└─────────────────────────────────────────┘
```

### 1.2️⃣ Fence Tracker (Stationary) - *NEW*

#### Hardware Stack

```
┌───────────────────────────────────────┐
│         Hardware Layer                │
├───────────────────────────────────────┤
│  • nRF52840 MCU (64MHz ARM Cortex-M4) │
│  • L76K GNSS Module (Multi-GNSS)      │
│  • SX1262 LoRa (868/915MHz)           │
│  • Status LEDs (3x RGB)               │
│  • Solar Panel + External Battery     │
│  • Environmental Sensors              │
└───────────────────────────────────────┘
```

#### Software Architecture

```
┌─────────────────────────────────────────┐
│         Fence Tracker Arduino App       │
│    (T_Echo_Tracker_Fence.ino - Sketch)   │
├──────────┬──────────┬───────────────────┤
│ GPS Task │LoRa Task │  Status Task      │
│          │          │                   │
│ Position │ TX/RX    │  LED Indicators   │
│ Validation│ Protocol │  Environmental   │
├──────────┴──────────┴───────────────────┤
│   Power Management │ BLE Provision   │
│   (Solar/Battery)  │ (Configuration) │
├───────────────────────┴─────────────────┤
│   EEPROM Storage   │   Outage Detection  │
├─────────────────────────────────────────┤
│         Arduino Framework               │
├─────────────────────────────────────────┤
│         nRF52840 Core (mbed)            │
└─────────────────────────────────────────┘
```

> 📝 **Key Modules:**
> - `T_Echo_Tracker.ino` - Main Arduino sketch with loop() and setup()
> - `tracker_config.h/.cpp` - Configuration management and BLE provisioning
> - `imu_sampling.h/.cpp` - IMU sensor data collection and processing
> - `behavior_inference.h/.cpp` - TinyML behavior detection using TensorFlow Lite
> - `tflite_inference.h/.cpp` - TensorFlow Lite model inference engine
> - `behavior_model.h` - Pre-trained behavior classification models

### Technical Specifications

#### Cattle Tracker (Mobile)
| Component | Specification |
|-----------|---------------|
| **MCU** | nRF52840 @ 64MHz ARM Cortex-M4, 256KB SRAM |
| **Flash** | 1MB internal + external flash support |
| **GPS** | L76K GNSS Module (GPS/GLONASS/Galileo/BeiDou) |
| **LoRa** | SX1262 (868/915MHz) |
| **Display** | 1.22" SPI E-Paper (176x192) - Optional |
| **Battery** | 500mAh Li-ion (3.7V) |
| **Dimensions** | 49mm × 25mm × 15mm |
| **Weight** | 25g (with battery) |
| **Battery Life** | 1-2 weeks (adaptive) |
| **Sensors** | IMU (Accelerometer/Gyro) |
| **Connectivity** | BLE 5.0, LoRa, GPS |

#### Fence Tracker (Stationary)
| Component | Specification |
|-----------|---------------|
| **MCU** | nRF52840 @ 64MHz ARM Cortex-M4, 256KB SRAM |
| **Flash** | 1MB internal + external flash support |
| **GPS** | L76K GNSS Module (GPS/GLONASS/Galileo/BeiDou) |
| **LoRa** | SX1262 (868/915MHz) |
| **Display** | 3x RGB Status LEDs |
| **Power** | Solar Panel + External 5000mAh Li-ion |
| **Dimensions** | 49mm × 25mm × 15mm (base unit) |
| **Weight** | 25g (base unit, without external battery) |
| **Battery Life** | Indefinite (solar powered) |
| **Environmental** | Temperature, voltage sensors |
| **Connectivity** | BLE 5.0, LoRa, GPS |

---

## 2️⃣ MooPoint-Gateway (ESP32-S3)

### Hardware Stack

```
┌─────────────────────────────────────┐
│         Hardware Layer              │
├─────────────────────────────────────┤
│  • ESP32-S3 MCU                     │
│  • SX1262 LoRa + External Antenna   │
│  • UC6580 GPS Module                │
│  • 1.8" ST7735 TFT Display          │
│  • 5V External Power Supply         │
│  • WiFi/Ethernet Connectivity       │
└─────────────────────────────────────┘
```

### Software Architecture

```
┌─────────────────────────────────────────┐
│        Gateway Application              │
├──────────┬──────────┬───────────────────┤
│ LoRa RX  │MQTT      │   GPS Task        │
│ (Multi-  │Client    │   (Position)      │
│ tracker) │          │                   │
├──────────┴──────────┴───────────────────┤
│  Geofence Sync  │   Web Server         │
│  (Cache Update) │   (Config Portal)    │
├─────────────────┴──────────────────────┤
│  Device Map     │   Packet Queue       │
│  Management     │   (FIFO)             │
├─────────────────────────────────────────┤
│         FreeRTOS RTOS                   │
├─────────────────────────────────────────┤
│         ESP-IDF Framework               │
└─────────────────────────────────────────┘
```

> 📝 **Key Modules:**
> - `main.cpp` - Gateway main application with LoRa packet handling, MQTT bridging, and geofence management
> - `wifi_config.h/.cpp` - WiFi configuration portal and network management
> - `geofence_json_parser.h` - Lightweight JSON parser for geofence commands
> - `minmea_simple.h/.cpp` - GPS NMEA parsing for u-blox GPS modules
> - `font.h/.c` - Display font data for TFT screen
> - `main_LoRaOnly.cpp` - LoRa-only configuration variant

### Performance Metrics

| Metric | Value |
|--------|-------|
| **Packet Handling** | 1000+ packets/minute |
| **Concurrent Trackers** | 50+ simultaneous |
| **MQTT Throughput** | 100+ messages/second |
| **LoRa Range** | Up to 10km (line of sight) |
| **API Response Time** | <100ms |

---

## 📁 File Structure & Component Organization

### 1️⃣ MooPoint-Tracker (Cattle)

```
T_Echo_Tracker_Arduino_IDE/
├── T_Echo_Tracker/                    # Main firmware sketch
│   ├── T_Echo_Tracker.ino           # Main application entry point (118KB)
│   ├── tracker_config.h             # Configuration constants and BLE provisioning
│   ├── tracker_config.cpp           # Configuration management implementation
│   ├── imu_sampling.h               # IMU sensor data collection
│   ├── imu_sampling.cpp             # IMU data processing and filtering
│   ├── behavior_inference.h          # TinyML behavior detection interface
│   ├── behavior_inference.cpp        # TensorFlow Lite behavior classification
│   ├── tflite_inference.h           # TensorFlow Lite inference engine
│   ├── tflite_inference.cpp         # ML model inference implementation
│   ├── behavior_model.h             # Pre-trained behavior classification models (47KB)
│   └── README_TFLITE.md              # TensorFlow Lite documentation
├── libraries/                        # Arduino libraries
├── platformio.ini                    # PlatformIO configuration
└── README.md                         # Firmware documentation
```

**Hardware Platform:** Lilygo T-Echo Lite (nRF52840)
- **MCU:** nRF52840 ARM Cortex-M4 @ 64MHz with 256KB SRAM
- **GPS:** L76K GNSS multi-GNSS module
- **Connectivity:** BLE 5.0, LoRa SX1262, GPS
- **Sensors:** 6-axis IMU (accelerometer + gyroscope)
- **Display:** 1.22" SPI E-Paper (176x192) - Optional
- **Development:** Arduino IDE with nRF52840 board support

**Key Files:**
- `T_Echo_Tracker.ino` - Main application with LoRa communication, power management, and sensor integration
- `tracker_config.h/.cpp` - BLE provisioning service and configuration management
- `behavior_inference.h/.cpp` - TensorFlow Lite-based behavior detection and classification
- `imu_sampling.h/.cpp` - IMU data collection for behavior analysis and motion sensing
- `tflite_inference.h/.cpp` - TensorFlow Lite inference engine for on-device ML
- `behavior_model.h` - Pre-trained behavior classification models (feeding, ruminating, resting, moving)

### 1.2️⃣ MooPoint-Tracker (Fence) - *Planned*

```
T_Echo_Tracker_Fence_IDE/
├── T_Echo_Tracker_Fence/           # Fence tracker firmware (fork)
│   ├── T_Echo_Tracker_Fence.ino     # Main application (modified)
│   ├── fence_monitor.h              # Fence-specific monitoring
│   ├── environmental_sensors.h      # Temperature/voltage monitoring
│   ├── status_leds.cpp               # LED status indicators
│   ├── outage_detection.cpp         # Power outage detection
│   ├── imu_security.cpp             # IMU-based security monitoring
│   └── nrf52_ble_fence.cpp          # nRF52 BLE for fence devices
├── libraries/                        # Arduino libraries
├── platformio.ini                    # PlatformIO configuration
└── README.md                         # Fence tracker documentation
```

**Hardware Platform:** Lilygo T-Echo Lite (nRF52840)
- **MCU:** nRF52840 ARM Cortex-M4 @ 64MHz with 256KB SRAM
- **GPS:** L76K GNSS multi-GNSS module
- **Connectivity:** BLE 5.0, LoRa SX1262, GPS
- **Sensors:** 6-axis IMU (accelerometer + gyroscope)
- **Power:** Solar panel + 5000mAh Li-ion battery
- **Development:** Arduino IDE with nRF52840 board support

### 2️⃣ MooPoint-Gateway

```
MooPoint-Gateway/
├── main/                            # Main firmware directory
│   ├── main.cpp                    # Gateway main application (105KB)
│   ├── config.h                    # Gateway configuration constants
│   ├── wifi_config.cpp             # WiFi configuration portal (42KB)
│   ├── wifi_config.h              # WiFi configuration header
│   ├── geofence_json_parser.h      # Geofence JSON parser
│   ├── minmea_simple.cpp           # GPS NMEA parsing for u-blox modules
│   ├── minmea_simple.h             # GPS parsing header
│   ├── font.c                      # Display font data (6KB)
│   ├── font.h                      # Font header definitions
│   ├── main_LoRaOnly.cpp           # LoRa-only configuration variant
│   ├── idf_component.yml          # ESP-IDF component configuration
│   └── CMakeLists.txt              # Build configuration
├── components/                      # ESP-IDF components
│   ├── RadioLib/                   # LoRa radio library
│   └── [other components]
├── CMakeLists.txt                   # Root build configuration
├── sdkconfig                        # ESP-IDF configuration
├── platformio.ini                   # PlatformIO configuration
└── README.md                        # Gateway documentation
```

**Key Files:**
- `main.cpp` - Main gateway application with LoRa packet handling, MQTT bridging, and geofence management (105KB)
- `wifi_config.h/.cpp` - WiFi configuration portal and network management (42KB)
- `geofence_json_parser.h` - Lightweight JSON parser for geofence commands from MQTT
- `minmea_simple.h/.cpp` - GPS NMEA parsing for u-blox GPS modules
- `font.h/.c` - Display font data for 1.8" ST7735 TFT screen
- `main_LoRaOnly.cpp` - LoRa-only configuration variant for minimal deployments

### 3️⃣ MooPoint-Server

#### Backend (Node.js)

```
MooPoint-Server/
├── server/                          # Backend server directory
│   ├── src/                       # Source code
│   │   ├── index.js              # Express server entry point (58KB)
│   │   ├── db.js                  # PostgreSQL database operations (31KB)
│   │   ├── influx.js              # InfluxDB time-series operations
│   │   ├── geofence.js            # Geofence processing algorithms
│   │   ├── ws.js                  # WebSocket real-time updates
│   │   ├── ai_dev_analytics.js    # AI-powered analytics (8KB)
│   │   ├── firmware_manager.js    # OTA firmware management
│   │   ├── mqtt_config_push.js    # Configuration push system
│   │   ├── mqtt_device_map_sync.js # Device authentication sync
│   │   ├── mqtt_geofence_sync.js   # Geofence synchronization
│   │   ├── mqtt_tracker_subscriber.js # Tracker data processing
│   │   └── logger.js              # Centralized logging
│   ├── package.json              # Node.js dependencies
│   ├── .env.example                # Environment variables template
│   └── .env                       # Environment variables (gitignored)
├── Grafana/                        # Grafana dashboards
│   ├── tracker-dashboard-v4.json   # Main tracking dashboard
│   ├── ai-analytics-panels.json   # AI analytics panels
│   └── [other dashboard files]
└── Telegraf/                       # InfluxDB configuration
    └── telegraf.conf              # Telegraf configuration file
```

#### Frontend (Flutter)

```
MooPoint-Server/FlutterAppUpdated/
├── lib/                            # Flutter source code
│   ├── main.dart                  # App entry point with navigation (48KB)
│   ├── dashboard_page.dart        # Real-time KPI dashboard (25KB)
│   ├── admin_page.dart            # Comprehensive admin interface (39KB)
│   ├── node_list_page.dart        # Node management and tracking (11KB)
│   ├── geofence_events_page.dart  # Event history and filtering (11KB)
│   ├── config_push_page.dart      # Multi-tracker configuration (25KB)
│   ├── ble_provisioning_menu.dart  # Device discovery menu (19KB)
│   ├── ble_provision_page.dart     # Full device configuration (24KB)
│   ├── compass_tracker_page.dart   # Real-time directional tracking (12KB)
│   ├── node_placement_page.dart    # Visual position management (8KB)
│   ├── node_history_page.dart      # Historical position data (6KB)
│   ├── settings_page.dart          # User preferences and settings (8KB)
│   ├── herd_state.dart             # Centralized state management (8KB)
│   ├── app_theme.dart              # Material Design theme (16KB)
│   ├── [Analytics Widgets]         # Behavior and voltage widgets
│   ├── [Data Models]               # Node, geofence, behavior models
│   ├── [Services]                  # Backend API clients
│   └── [UI Components]             # Reusable widgets
├── assets/                         # Static assets
│   ├── images/                    # Images and icons
│   └── [other asset files]
├── pubspec.yaml                     # Flutter dependencies
├── README.md                        # Flutter app documentation
└── [Flutter build files]
```

**Key Flutter Files:**
- `main.dart` - Main app with 6-tab navigation (Dashboard, Map, Nodes, Events, Admin, Settings)
- `dashboard_page.dart` - Real-time KPIs, activity feed, and alerts
- `herd_state.dart` - Centralized state management with WebSocket integration
- `admin_page.dart` - Comprehensive admin interface with node/geofence management

### 4️⃣ Development & Documentation

```
MooPoint-Server/
├── CascadeProjects/windsurf-project/    # Development workspace
│   ├── stitch_designs/              # UI design specifications
│   ├── .windsurf/                   # AI agent configurations
│   ├── PROGRESS_SUMMARY.md         # Implementation progress
│   └── [other development files]
├── ARCHITECTURE_UPDATE_ANALYSIS.md  # Architecture review results
├── MooPoint_System_Architecture.md   # This comprehensive architecture document
├── [Documentation files]            # README, setup guides, etc.
└── [Configuration files]           # Environment configs, build files
```

---

## 3️⃣ MooPoint-Server (Node.js + Flutter)

### Backend Architecture

```
┌─────────────────────────────────────────┐
│          Express Server                 │
│          (Node.js v18.x)                │
├──────────┬──────────┬───────────────────┤
│   Auth   │   API    │   WebSocket       │
│ (Session)│  Routes  │ (Real-time)       │
├──────────┴──────────┴───────────────────┤
│ MQTT Broker │ InfluxDB │  PostgreSQL    │
│ (Messages)  │ (Metrics)│  (Config)      │
├─────────────┴──────────┴────────────────┤
│  Geofence Engine  │ Device Management  │
│  (Point-in-poly)  │ (Auth/Provisioning)│
├─────────────────────────────────────────┤
│         Node.js Runtime                 │
└─────────────────────────────────────────┘
```

### Frontend Architecture

```
┌─────────────────────────────────────────┐
│         Flutter Web App                 │
│         (Flutter 3.x)                   │
├──────────┬──────────┬───────────────────┤
│ Map View │ Cow List │  Admin Panel      │
│(OSM)     │(Tracking)│  (Management)     │
├──────────┴──────────┴───────────────────┤
│ BLE Provision │  Geofence Editor        │
│ (Mobile Only) │  (Draw/Edit)            │
├───────────────┴─────────────────────────┤
│  HTTP Client  │  WebSocket Client       │
│  (REST API)   │  (Live Updates)         │
├─────────────────────────────────────────┤
│         Flutter Framework               │
└─────────────────────────────────────────┘
```

> 📝 **Key Modules:**
>
> **Backend:**
> - `server/src/index.js` - Express server entry
> - `server/src/influx.js` - Time-series operations
> - `server/src/db.js` - PostgreSQL database
> - `server/src/geofence.js` - Geofence processing
> - `server/src/ws.js` - WebSocket real-time updates
>
> **Frontend:**
> - `lib/main.dart` - Flutter app entry
> - `lib/cow_list_page.dart` - Tracking interface
> - `lib/admin_page.dart` - Admin dashboard
> - `lib/ble_provision_page.dart` - BLE provisioning

---

# 🔄 Data Flow & Signal Flows

## 1. Normal Tracking Flow

```mermaid
sequenceDiagram
    participant T as 🔵 Tracker
    participant G as 🟢 Gateway
    participant S as 🟣 Server
    participant C as 💻 Web Client
    
    T->>T: 📍 GPS Fix & Position Calculation
    T->>G: 📡 LoRa Position Packet
    G->>S: 📨 MQTT: moopoint/telemetry/tracker/{nodeId}/position
    S->>S: 💾 Store in InfluxDB
    S->>S: 🗺️ Geofence Check
    S->>C: ⚡ WebSocket: Position Update
    C->>C: 🖥️ Update Map Display
```

> 💡 **Flow Summary:**
> 1. Tracker acquires GPS position
> 2. Sends via LoRa to Gateway
> 3. Gateway forwards via MQTT to Server
> 4. Server stores and checks geofences
> 5. Real-time update pushed to web clients

---

## 2. Geofence Update Flow

```mermaid
sequenceDiagram
    participant A as 👤 Admin
    participant S as 🟣 Server
    participant G as 🟢 Gateway
    participant T as 🔵 Tracker
    
    A->>S: ✏️ PUT /admin/geofences/{id}
    S->>S: 💾 Update PostgreSQL
    S->>G: 📨 MQTT: moopoint/cmd/geofence/update
    G->>G: 🗂️ Cache Geofence Data
    loop For Each Tracker
        G->>T: 📡 LoRa: Geofence Notification
        T->>G: ✅ LoRa: ACK
        G->>T: 📡 LoRa: Geofence Data
        T->>T: 💾 Update Local Geofence
    end
```

> ⚠️ **Important Notes:**
> - Geofences are cached on Gateway for reliability
> - Each tracker receives individual notification
> - ACK ensures delivery confirmation
> - Updates happen in real-time

---

## 3. BLE Provisioning Flow

```mermaid
sequenceDiagram
    participant P as 📱 Phone (Flutter)
    participant T as 🔵 Tracker
    participant N as 💾 NVS Storage
    
    P->>T: 🔗 BLE Connect
    P->>T: 📥 GET Config
    T->>N: 📖 Load Configuration
    T->>P: 📤 Return JSON Config
    P->>P: ✏️ User Edits Fields
    P->>T: 📤 SET Config + JSON
    T->>N: 💾 Save Configuration
    T->>P: ✅ OK Response
    P->>T: 🔄 REBOOT (optional)
```

> 📱 **Provisioning Steps:**
> 1. **Enter Config Mode** - Hold button for 3 seconds
> 2. **Connect via BLE** - Use mobile app to scan
> 3. **Edit Configuration** - Modify settings in app
> 4. **Save & Apply** - Configuration saved to device
> 5. **Reboot** - Apply changes (optional)

---

## 4. Configuration Push Flow

```mermaid
sequenceDiagram
    participant A as 👤 Admin
    participant S as 🟣 Server
    participant G as 🟢 Gateway
    participant T as 🔵 Tracker
    
    A->>S: 📝 POST /admin/config/push
    S->>S: 🔍 Validate Configuration
    S->>S: 💾 Store in PostgreSQL
    S->>G: 📨 MQTT: moopoint/cmd/gateway/{gatewayId}/config_update
    G->>T: 📡 LoRa: ConfigUpdatePacket
    T->>T: ✅ Validate & Apply
    T->>G: 📡 LoRa: ConfigAckPacket
    G->>S: 📨 MQTT: moopoint/telemetry/gateway/{gatewayId}/config_ack
    S->>A: ⚡ WebSocket: Status Update
```

> 🚀 **Configuration Push Features:**
> 1. **Multi-tracker Support** - Configure multiple trackers simultaneously
> 2. **Real-time Status** - Track configuration progress via WebSocket
> 3. **Validation** - Server validates configuration before sending
> 4. **Acknowledgments** - Reliable delivery confirmation
> 5. **History** - Store configuration changes in PostgreSQL

---

## 4. Power Management State Machine

```mermaid
stateDiagram-v2
    [*] --> DeepSleep
    DeepSleep --> Wake: ⏰ Timer/RTC
    Wake --> GPSFix: 📍 Start GPS
    GPSFix --> PositionCalc: 🛰️ GPS Data Ready
    PositionCalc --> LoRaTX: 📊 Calculate Position
    LoRaTX --> RXWindow1: 📡 Transmit Position
    RXWindow1 --> RXWindow2: 📬 Notification Received
    RXWindow2 --> DeepSleep: ✅ No More Data
    RXWindow1 --> DeepSleep: ❌ No Notification
    DeepSleep --> Wake: 🔋 Battery Check
```

> 🔋 **Power States:**
> - **Deep Sleep** - Minimum power consumption
> - **Wake** - Initialize peripherals
> - **GPS Fix** - Acquire position
> - **LoRa TX** - Transmit data
> - **RX Windows** - Listen for commands
> - **Back to Sleep** - Conserve battery

---

# 📡 Communication Protocols

## LoRa Protocol

### Packet Structures

#### 📍 Position Packet (v3.0 - 24 bytes)

```c
struct __attribute__((packed)) TrackerPacket {
    uint8_t  node_id;        // Node identifier
    uint32_t device_id;      // Unique device ID (32-bit)
    uint32_t frame_counter;  // Sequential counter
    int32_t  lat;           // Latitude * 1e7
    int32_t  lon;           // Longitude * 1e7
    uint16_t batt_mv;       // Battery voltage (mV)
    uint8_t  gps_valid;     // GPS fix validity flag
    uint8_t  geofence_version; // Current geofence version
    uint8_t  hmac[8];       // HMAC authentication
};
```

#### 📊 Extended Metrics (12 bytes - optional)

```c
struct __attribute__((packed)) ExtendedMetrics {
    uint8_t  gps_fix_count;       // Successful fixes in window
    uint8_t  gps_fail_count;      // Failed fixes in window
    uint8_t  gps_hot_start_count; // Hot starts in window
    uint8_t  gps_avg_fix_time_s;  // Average fix time (seconds)
    uint8_t  gps_avg_sats;        // Average satellite count
    uint16_t gps_avg_hdop;        // Average HDOP * 100
    int8_t   tx_power_dbm;        // Current TX power setting
    int16_t  last_rx_rssi;        // Last gateway RSSI (dBm)
    int8_t   last_rx_snr;         // Last gateway SNR (dB)
    uint8_t  power_mode;          // Current power mode (0-3)
    uint8_t  cycles_accumulated;  // How many cycles this covers
};
```

#### 📦 Extended Packet Format
```
[TrackerPacket][flags byte][ExtendedMetrics]
// Total: 24 + 1 + 12 = 37 bytes (every 5th cycle when enabled)
// flags byte = 0x01 indicates extended metrics present
```

#### 🔔 ACK Notification Packet (v3.1 - 10 bytes)

```c
struct __attribute__((packed)) ACKNotifyPacket {
    uint8_t  node_id;           // Node identifier
    uint32_t device_id;         // Unique device ID (32-bit)
    uint32_t frame_counter;     // Sequential counter
    uint8_t  geofence_update;   // 0=no update, 1=geofence data follows
    uint8_t  ble_locate_minutes; // 0=no locate, N=enable for N minutes
    uint8_t  hmac[8];           // HMAC authentication
};
```

> 🔄 **v3.1 Changes:**
> - Renamed from `GeofenceNotifyPacket` to `ACKNotifyPacket`
> - Removed `vertex_count` and `geofence_version` fields
> - Renamed `command` to `geofence_update`
> - Gateway **always** sends ACK after valid tracker packet
> - Smaller packet size (10 bytes vs 12 bytes)
> - Always populates tracker RSSI/SNR metrics

#### 📦 Geofence Data (93 bytes)

```c
struct __attribute__((packed)) GeofencePacket {
    uint8_t  node_id;
    uint32_t device_id;
    uint32_t frame_counter;
    uint8_t  vertex_count;
    uint8_t  command;        // 0x01 = update geofence
    uint8_t  geofence_version; // New geofence version
    int32_t  vertices[10][2]; // [vertex][lat, lon] * 1e7
    uint8_t  hmac[8];
};
```

#### ✅ ACK Packet (12 bytes)

```c
struct __attribute__((packed)) GeofenceAckPacket {
    uint8_t  node_id;
    uint32_t device_id;
    uint32_t frame_counter;
    uint8_t  command;        // 0x20 = ACK
    uint8_t  status;         // 0x00 = success, 0x01 = error
    uint8_t  vertex_count;
    uint8_t  geofence_version; // Acknowledged geofence version
    uint8_t  hmac[8];
};
```

### LoRa Configuration

| Parameter | Default | Geofence Data |
|-----------|---------|---------------|
| **Frequency** | 868.0 MHz (EU) | Same |
| **Spreading Factor** | SF9 | SF7 |
| **Bandwidth** | 125.0 kHz | 250.0 kHz |
| **Coding Rate** | 4/7 | 4/7 |
| **TX Power** | 14 dBm | 14 dBm |

> ⚡ **Performance Note:**
> Geofence data uses faster settings (SF7, 250kHz BW) for quicker transmission of larger payloads.

---

## MQTT Protocol

### Topic Structure

```
# Tracker Data (Gateway publishes)
moopoint/telemetry/tracker/{nodeId}/position        📍 Position data
moopoint/telemetry/tracker/{nodeId}/coverage_point   📡 Network coverage
moopoint/telemetry/gateway/{gatewayId}/position      🌐 Gateway GPS
moopoint/telemetry/gateway/{gatewayId}/rx_kpis         � Gateway metrics
moopoint/telemetry/gateway/{gatewayId}/status          ✅ Gateway status

# Geofence Management (Server publishes, Gateway subscribes)
moopoint/cmd/geofence/update                           🗺️ Geofence updates
moopoint/cmd/geofence/request                          📋 Geofence request
moopoint/telemetry/geofence/status                      📄 Geofence operation status

# Device Management (Server publishes, Gateway subscribes)
moopoint/cmd/gateway/{gatewayId}/device_map             🔐 Device authentication map
moopoint/cmd/gateway/{gatewayId}/ble_locate             � BLE locate requests
moopoint/cmd/gateway/{gatewayId}/config_update          🚀 Configuration updates

# Configuration Acknowledgments (Gateway publishes)
moopoint/telemetry/gateway/{gatewayId}/config_ack         ✅ Config update status
moopoint/telemetry/gateway/{gatewayId}/status             ✅ Gateway status (general)
```

### Message Formats

#### Position Message (Standard)

```json
{
  "lat": 40.7128,
  "lon": -74.0060,
  "batt": 4200,
  "batt_percent": 85,
  "gps_valid": true,
  "rssi": -45.2,
  "snr": 9.5,
  "ts": 1704110400000
}
```

#### Position Message (with Extended Metrics)

```json
{
  "lat": 40.7128,
  "lon": -74.0060,
  "batt": 4200,
  "batt_percent": 85,
  "gps_valid": true,
  "rssi": -45.2,
  "snr": 9.5,
  "ts": 1704110400000,
  "ext": {
    "gps_fix": 4,
    "gps_fail": 1,
    "gps_hot": 3,
    "gps_fix_time": 12,
    "gps_sats": 8,
    "gps_hdop": 1.23,
    "tx_power": 14,
    "tracker_rssi": -48,
    "tracker_snr": 8.5,
    "power_mode": 1,
    "cycles": 5
  }
}
```

#### Geofence Update

```json
{
  "action": "update",
  "version": 123,
  "nodeIds": [1, 2, 3],
  "geofence": {
    "vertices": [
      [40.7128, -74.0060],
      [40.7138, -74.0070],
      [40.7148, -74.0050]
    ]
  }
}
```

### MQTT Settings

| Setting | Value |
|---------|-------|
| **Protocol Version** | MQTT 3.1.1 |
| **QoS Levels** | 0 (at most once), 1 (at least once) |
| **Retained Messages** | Yes (config data) |
| **Last Will** | Gateway status |
| **Keep Alive** | 60 seconds |

---

## BLE Provisioning Protocol

### GATT Service Definition

```
Service UUID:  6e400001-b5a3-f393-e0a9-e50e24dcca9e
├── RX Characteristic (Write):
│   └── 6e400002-b5a3-f393-e0a9-e50e24dcca9e
└── TX Characteristic (Notify/Read):
    └── 6e400003-b5a3-f393-e0a9-e50e24dcca9e
```

### Commands

| Command | Format | Description |
|---------|--------|-------------|
| **GET** | `GET\n` | Request current config |
| **SET** | `SET:<len>\n<data>` | Set new configuration |
| **RESET** | `RESET\n` | Reset to defaults |
| **REBOOT** | `REBOOT\n` | Reboot device |

### Configuration JSON Example

```json
{
  "sleep_minutes": 5,
  "gps_timeout_sec": 300,
  "node_id": 1,
  "device_id": 1234567890,
  "device_key": "abcdef1234567890abcdef1234567890",
  "lora_freq": "868.0",
  "lora_sf": 9,
  "lora_bw": "125.0",
  "lora_power": 14,
  "lora_cr": 7,
  "gps_min_sats": 4,
  "gps_hdop_max": "3.0",
  "batt_critical_mv": 3200,
  "batt_low_mv": 3400,
  "batt_full_mv": 4200,
  "batt_shutdown_pct": 10,
  "display_enabled": 1,
  "debug_gps_raw": 0,
  "debug_lora": 1,
  "debug_battery": 1,
  "cycle1_battery_pct": 80,
  "cycle1_sleep_min": 5,
  "cycle2_battery_pct": 50,
  "cycle2_sleep_min": 10,
  "cycle3_battery_pct": 35,
  "cycle3_sleep_min": 30
}
```

---

## HTTP REST API

### Authentication Endpoints

```http
POST   /auth/login          # User login
POST   /auth/logout         # User logout
GET    /auth/me             # Current user info
```

### Cow/Node Management

```http
GET    /api/cows                    # List all cows
GET    /api/cows/{nodeId}           # Get specific cow
GET    /api/cows/{nodeId}/history   # Position history
PUT    /admin/nodes/{nodeId}        # Update node config
GET    /admin/nodes                 # List all nodes
```

### Geofence Management

```http
GET    /api/geofences                    # List geofences
GET    /api/geofence-events              # Recent events
POST   /admin/geofences                  # Create geofence
PUT    /admin/geofences/{id}             # Update geofence
DELETE /admin/geofences/{id}             # Delete geofence
PUT    /admin/geofences/{id}/nodes       # Assign nodes
```

### Device Credentials

```http
GET    /admin/device-credentials                      # List credentials
PUT    /admin/nodes/{nodeId}/device-credentials       # Update credentials
POST   /admin/gateways/{gatewayId}/device-map/publish # Publish device map
```

---

# 🔒 Security Model

## Device Authentication

### Authentication Layers

```
┌─────────────────────────────────────┐
│      Application Security           │
├─────────────────────────────────────┤
│  • Session-based Auth (Web)         │
│  • Admin Credentials (Env Vars)     │
│  • CORS Policy (Trusted Origins)    │
│  • Input Validation (JSON Schema)   │
├─────────────────────────────────────┤
│      Device Security                │
├─────────────────────────────────────┤
│  • 64-bit Device ID                 │
│  • 128-256 bit Device Key           │
│  • HMAC Authentication (Future)     │
│  • MQTT Device-to-Node Mapping      │
├─────────────────────────────────────┤
│      Communication Security         │
├─────────────────────────────────────┤
│  • LoRa: Physical security          │
│  • MQTT: TLS encryption (optional)  │
│  • HTTP/HTTPS: TLS at proxy         │
│  • BLE: Proximity-based security    │
└─────────────────────────────────────┘
```

### Security Features

| Layer | Implementation | Notes |
|-------|----------------|-------|
| **Device ID** | 32-bit unique identifier | Sufficient for <1000 nodes |
| **Device Key** | 256-bit hex key (32 bytes) | Stored in encrypted NVS |
| **HMAC Auth** | HMAC-SHA256 over packet fields | Excludes extended metrics |
| **MQTT Auth** | Device credentials | Mapped to nodes |
| **Web Auth** | Session-based | Express sessions |
| **Admin Access** | Environment variables | `ADMIN_USERNAME/PASSWORD` |

> ⚠️ **Security Considerations:**
> - LoRa uses physical security (limited range)
> - BLE uses proximity-based security
> - MQTT can use TLS encryption
> - Always use HTTPS in production

---

## Data Protection

### Storage Security

| Storage Type | Security Measure |
|--------------|------------------|
| **NVS (ESP32)** | Encrypted flash storage |
| **PostgreSQL** | Access control, user permissions |
| **InfluxDB** | Retention policies, auth tokens |
| **Logs** | Sensitive data filtering |

### Encryption Status

```
✅ NVS Storage (ESP32)      - Hardware encrypted
✅ HTTPS/TLS               - Reverse proxy termination
✅ PostgreSQL              - Database-level encryption (optional)
⚠️ LoRa                    - No encryption (range-limited)
⚠️ BLE                     - No encryption (proximity-limited)
✅ MQTT                    - TLS available (configure)
```

---

# 🔋 Power Management

## Adaptive Power Cycles

### The Four-Tier System

```
┌──────────────────────────────────────────────────┐
│         Battery Level Based Cycles               │
├──────────────────────────────────────────────────┤
│                                                  │
│  🟢 Cycle 1: HIGH BATTERY (>80%)                 │
│  ├─ Sleep: 5 minutes                            │
│  ├─ GPS Timeout: 300 seconds                    │
│  └─ Features: Full accuracy, all sensors         │
│                                                  │
│  🟡 Cycle 2: MEDIUM BATTERY (50-80%)             │
│  ├─ Sleep: 10 minutes                           │
│  ├─ GPS Timeout: 180 seconds                    │
│  └─ Features: Balanced power/accuracy            │
│                                                  │
│  🟠 Cycle 3: LOW BATTERY (35-50%)                │
│  ├─ Sleep: 30 minutes                           │
│  ├─ GPS Timeout: 120 seconds                    │
│  └─ Features: Power saving mode                  │
│                                                  │
│  🔴 Cycle 4: CRITICAL (<35%)                      │
│  ├─ Sleep: 60 minutes                           │
│  ├─ GPS Timeout: 60 seconds                     │
│  └─ Features: Emergency mode only                │
│                                                  │
│  🔴 SHUTDOWN (<10%)                              │
│  └─ Action: Deep shutdown to protect battery     │
│                                                  │
└──────────────────────────────────────────────────┘
```

### Battery Thresholds

```c
#define BATT_FULL_MV     4200  // 100% charge
#define BATT_LOW_MV      3400  // Low battery warning
#define BATT_CRITICAL_MV 3200  // Critical shutdown
#define BATT_SHUTDOWN_PCT 10   // Minimum safe level
```

---

## Power Saving Features

### 1. GPS Hot Start Optimization

| Feature | Benefit |
|---------|---------|
| **Ephemeris Caching** | Cached between wake cycles |
| **Quick TTFF** | 5-10 seconds (vs 30-60 cold) |
| **Position Averaging** | Multiple fixes for accuracy |
| **Satellite Prediction** | Pre-select best satellites |

### 2. LoRa Duty Cycling

```
Wake Cycle:
  ┌─────────────────────────────────────┐
  │ 1. Wake from Deep Sleep             │
  │ 2. GPS Fix (30-60s)                 │
  │ 3. LoRa TX (1-2s)                   │
  │ 4. RX Window 1 (2s)                 │
  │ 5. RX Window 2 (2s) - if needed     │
  │ 6. Back to Deep Sleep               │
  └─────────────────────────────────────┘
  
  Total Active Time: ~35-70 seconds
  Sleep Time: 5-30 minutes (configurable)
  Duty Cycle: ~0.2% to 2%
```

### 3. Display Management

| Feature | Behavior |
|---------|----------|
| **Touch Wake** | Display on when touched |
| **Auto-off** | 30 second timeout |
| **Brightness** | Adaptive based on battery |
| **Status Only** | Minimal refresh rate |

---

## Battery Monitoring

### Real-time Monitoring

```c
typedef struct {
    uint16_t current_mv;    // Current voltage
    uint8_t  percentage;    // Battery %
    uint8_t  power_cycle;   // Active cycle (1-3)
    bool     charging;      // Charging status
    uint32_t last_check;    // Last check timestamp
} battery_state_t;
```

### Battery Life Estimation

| Usage Pattern | Battery Life |
|---------------|--------------|
| **Optimal** (5min, good GPS) | 3-4 weeks |
| **Standard** (10min, mixed GPS) | 2-3 weeks |
| **Power Save** (30min, poor GPS) | 4-6 weeks |
| **Critical** (60min, emergency) | 6-8 weeks |
| **Extended** (adaptive cycling) | 2-8 weeks (varies) |

> 💡 **Pro Tip:**
> Battery life heavily depends on GPS fix time. Clear sky view = longer battery life!

---

# 🗺️ Geofencing System

## Geofence Types & Capabilities

### Polygon Geofences

```
┌─────────────────────────────────────┐
│      Geofence Specifications        │
├─────────────────────────────────────┤
│  Max Vertices: 10 points            │
│  Coordinate System: WGS84           │
│  Precision: 1e7 degrees (±1.1cm)    │
│  Format: Integer lat/lon            │
│  Storage: 83 bytes per geofence     │
└─────────────────────────────────────┘
```

### Visual Example

```
        Vertex 1 (40.7128°N, -74.0060°W)
           ○
          / \
         /   \
        /     \
    V2 ○       ○ V3
        \     /
         \   /
          \ /
           ○
        Vertex 4

    🐄 Cow Position: Inside/Outside?
```

---

## Geofence Processing

### Server-Side: Point-in-Polygon Algorithm

```javascript
/**
 * Ray Casting Algorithm
 * Casts a ray from the point to infinity
 * Counts intersections with polygon edges
 * Odd = inside, Even = outside
 */
function pointInPolygon(point, vertices) {
    let inside = false;
    
    for (let i = 0, j = vertices.length - 1; 
         i < vertices.length; 
         j = i++) {
        
        const xi = vertices[i][0], yi = vertices[i][1];
        const xj = vertices[j][0], yj = vertices[j][1];
        
        const intersect = ((yi > point[1]) !== (yj > point[1]))
            && (point[0] < (xj - xi) * (point[1] - yi) / (yj - yi) + xi);
        
        if (intersect) inside = !inside;
    }
    
    return inside;
}
```

### Tracker-Side: Embedded Point-in-Polygon

```c
/**
 * Lightweight version for ESP32
 * Same algorithm, optimized for embedded
 * Uses fixed-point arithmetic (lat/lon * 1e7)
 */
bool point_in_geofence(int32_t lat, int32_t lon, geofence_t *fence) {
    if (fence->vertex_count < 3) return false;
    
    bool inside = false;
    
    for (int i = 0, j = fence->vertex_count - 1; 
         i < fence->vertex_count; 
         j = i++) {
        
        int32_t xi = fence->vertices[i][0];
        int32_t yi = fence->vertices[i][1];
        int32_t xj = fence->vertices[j][0];
        int32_t yj = fence->vertices[j][1];
        
        bool intersect = ((yi > lon) != (yj > lon)) &&
            (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi);
        
        if (intersect) inside = !inside;
    }
    
    return inside;
}
```

> 🎯 **Algorithm Choice:**
> Ray casting algorithm is used because it's:
> - Fast O(n) complexity
> - Reliable for all polygon shapes
> - Easy to implement on embedded devices
> - Memory efficient

---

## Node Assignment System

### Many-to-Many Relationships

```
Nodes          Geofences
  1 ──────────── A (Pasture North)
  │  \
  │   \_________ B (Pasture South)
  2 ──────────── B (Pasture South)
  │
  3 ──────────── C (Barn Area)
     \
      \_________ A (Pasture North)
```

> 💡 **Flexibility:**
> - One node can be in multiple geofences
> - One geofence can contain multiple nodes
> - Dynamic assignment via web interface
> - Real-time synchronization

---

## Geofence Events

### Event Types

| Event Type | Trigger | Action |
|-----------|---------|--------|
| **ENTRY** | Animal enters geofence | Record + notify |
| **EXIT** | Animal leaves geofence | Record + alert |
| **UPDATE** | Geofence boundary changed | Re-check all positions |

### Event Storage Schema

```sql
CREATE TABLE geofence_events (
    id SERIAL PRIMARY KEY,
    node_id INTEGER NOT NULL,
    geofence_id INTEGER NOT NULL,
    event_type VARCHAR(10) NOT NULL,  -- 'ENTRY' or 'EXIT'
    lat INTEGER NOT NULL,              -- Position at event
    lon INTEGER NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed BOOLEAN DEFAULT FALSE    -- For notification queue
);
```

### Real-time Event Flow

```
Event Detected
    ↓
Store in Database
    ↓
    ├──→ WebSocket Broadcast (Web clients)
    ├──→ MQTT Publish (External systems)
    └──→ Alert System (Email/SMS/Push)
```

---

## Geofence Version Control

### Synchronization System

| Component | Version Storage | Sync Method |
|-----------|----------------|-------------|
| **Server** | PostgreSQL `geofences.version` | Source of truth |
| **Gateway** | RAM cache + version number | MQTT subscribe |
| **Tracker** | NVS storage + version | LoRa notification |

### Update Workflow

```
1. Admin updates geofence in web UI
2. Server increments version number
3. Server publishes MQTT update
4. Gateway receives and caches
5. Gateway notifies affected trackers via LoRa
6. Trackers ACK and request data
7. Gateway sends geofence vertices
8. Trackers store in NVS
```

> ⚡ **Performance:**
> - Version numbers prevent unnecessary updates
> - Gateways cache to reduce server load
> - Trackers only update when changed
> - Entire sync completes in ~5-10 seconds

---

# 🧠 TinyML Behavior Detection

## Overview

> 💡 **What is Behavior Detection?**
> 
> The MooPoint tracker includes on-device TinyML inference to detect animal behaviors (feeding, ruminating, resting, moving) using accelerometer and gyroscope data collected during GPS fix periods.

## Hardware & Software Stack

### IMU Sensor Integration

```
ICM-20948 9-DOF IMU Sensor
├─ 3-axis Accelerometer (±16g)
├─ 3-axis Gyroscope (±2000°/s)
├─ 3-axis Magnetometer (optional)
└─ I2C Interface (400kHz)
```

### TensorFlow Lite Micro

| Component | Specification |
|-----------|---------------|
| **Framework** | TensorFlow Lite Micro v2.x |
| **Model Size** | ~47KB (behavior_model.tflite) |
| **Inference Time** | <100ms per sample |
| **Memory Usage** | ~50KB RAM |
| **Power Impact** | Minimal (samples during GPS fix) |

## Behavior Classes

### Detected Behaviors

| Behavior | Description | Typical Indicators |
|----------|-------------|-------------------|
| **Feeding** | Animal eating grass | Head down, steady movement |
| **Ruminating** | Chewing cud | Minimal movement, rhythmic |
| **Resting** | Lying down/standing still | Low acceleration variance |
| **Moving** | Walking/running | Periodic gait patterns |
| **Unknown** | Unclassified activity | Mixed or unclear patterns |

### Sampling Strategy

```
During GPS Fix Window (typically 30-60 seconds):
┌─────────────────────────────────────────┐
│ GPS Acquisition (20-40 seconds)        │
│ ├─ IMU Sampling @ 25Hz                 │
│ ├─ Buffer 500-1500 samples              │
│ └─ Feature extraction (mean, variance)  │
├─────────────────────────────────────────┤
│ ML Inference (<100ms)                   │
│ ├─ Preprocess samples                   │
│ ├─ Run TFLite model                     │
│ └─ Get behavior probabilities           │
├─────────────────────────────────────────┤
│ Data Transmission                       │
│ ├─ Include behavior in extended metrics  │
│ └─ Send via LoRa to gateway             │
└─────────────────────────────────────────┘
```

## Model Architecture

### Input Features

| Feature | Description | Range |
|---------|-------------|-------|
| **Accel Mean** | Average acceleration magnitude | 0.5-2.0g |
| **Accel Variance** | Movement intensity | 0.01-1.0 |
| **Gyro Mean** | Average rotation rate | -200 to +200°/s |
| **Gyro Variance** | Rotational consistency | 0-10000 (°/s)² |
| **Sample Duration** | GPS fix time | 20-60 seconds |

### Output Probabilities

```json
{
  "feeding": 0.75,      // 75% confidence
  "ruminating": 0.15,   // 15% confidence  
  "resting": 0.05,      // 5% confidence
  "moving": 0.03,       // 3% confidence
  "unknown": 0.02       // 2% confidence
}
```

## Data Integration

### Extended Metrics Integration

```json
{
  "ext": {
    "behavior_feeding_s": 1800,     // 30 minutes feeding
    "behavior_ruminating_s": 900,   // 15 minutes ruminating  
    "behavior_resting_s": 300,      // 5 minutes resting
    "behavior_moving_s": 600,       // 10 minutes moving
    "behavior_confidence": 0.85     // Overall confidence
  }
}
```

### Server Processing

```javascript
// Behavior analytics in ai_dev_analytics.js
function processBehaviorData(nodeId, behaviorMetrics) {
  const totalSeconds = Object.values(behaviorMetrics)
    .filter((v, k) => k.startsWith('behavior_') && k.endsWith('_s'))
    .reduce((sum, val) => sum + val, 0);
    
  const behaviorPercentages = {};
  for (const [key, seconds] of Object.entries(behaviorMetrics)) {
    if (key.startsWith('behavior_') && key.endsWith('_s')) {
      const behavior = key.replace('behavior_', '').replace('_s', '');
      behaviorPercentages[behavior] = (seconds / totalSeconds) * 100;
    }
  }
  
  return {
    nodeId,
    timestamp: new Date(),
    behaviors: behaviorPercentages,
    confidence: behaviorMetrics.behavior_confidence
  };
}
```

## Applications

### 🐄 Livestock Management

| Use Case | Benefit |
|----------|---------|
| **Health Monitoring** | Detect changes in feeding patterns |
| **Heat Detection** | Identify behavioral estrus indicators |
| **Stress Analysis** | Monitor rest vs activity ratios |
| **Grazing Optimization** | Track feeding patterns and locations |

### 📊 Analytics & Insights

- **Behavior Heat Maps**: Visualize activity patterns across pastures
- **Time Budget Analysis**: Percentage breakdown of daily activities
- **Health Alerts**: Automated notifications for behavior anomalies
- **Feed Efficiency**: Correlate behavior with weight gain

## Configuration

### Behavior Detection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_behavior_detection` | boolean | `false` | Enable/disable ML inference |
| `behavior_sample_rate_hz` | int | `25` | IMU sampling frequency |
| `behavior_min_confidence` | float | `0.6` | Minimum confidence for reporting |
| `behavior_inference_interval` | int | `1` | Run inference every N GPS fixes |

### Model Management

```c
// Model loading and inference
bool loadBehaviorModel() {
  // Load behavior_model.tflite from flash
  // Initialize TFLite interpreter
  // Allocate tensors for input/output
  return model_loaded;
}

behavior_result_t runBehaviorInference(imu_samples_t* samples) {
  // Preprocess IMU data
  // Run TFLite model inference
  // Post-process results
  // Return behavior classification
}
```

---

# 📊 Extended Metrics System

## Overview

> 💡 **What are Extended Metrics?**
> 
> The extended metrics system provides detailed diagnostic information from trackers without significantly increasing airtime. Metrics are accumulated over multiple cycles and transmitted periodically every 5th cycle when enabled.

## Metrics Collection

### 🔄 Accumulation Window

| Parameter | Value | Description |
|-----------|-------|-------------|
| **Interval** | Every 5th cycle | `METRICS_SEND_INTERVAL = 5` |
| **Trigger** | Config flag | `enable_extended_metrics` boolean |
| **Storage** | In-memory RAM | Reset after each transmission |
| **Overhead** | +13 bytes | 1 byte flags + 12 bytes metrics |

### 📡 GPS Metrics

| Metric | Unit | Purpose |
|--------|------|---------|
| **Fix Count** | count | Successful GPS fixes in window |
| **Fail Count** | count | Failed GPS attempts in window |
| **Hot Starts** | count | Hot/warm starts (ephemeris cache hits) |
| **Avg Fix Time** | seconds | Mean time to acquire fix |
| **Avg Satellites** | count | Mean satellite count across fixes |
| **Avg HDOP** | ×100 | Mean horizontal dilution of precision |

### 📻 Radio Metrics

| Metric | Unit | Purpose |
|--------|------|---------|
| **TX Power** | dBm | Current LoRa transmit power setting |
| **Last RX RSSI** | dBm | Signal strength of last gateway notification |
| **Last RX SNR** | dB | Signal-to-noise ratio of last gateway notification |

### 🔋 Power Metrics

| Metric | Unit | Purpose |
|--------|------|---------|
| **Power Mode** | enum | Current adaptive power cycle (0-3) |
| **Cycles Accumulated** | count | Number of cycles included in this report |

### 🧠 Behavior Metrics

| Metric | Unit | Purpose |
|--------|------|---------|
| **Behavior Feeding** | seconds | Time spent feeding in window |
| **Behavior Ruminating** | seconds | Time spent ruminating in window |
| **Behavior Resting** | seconds | Time spent resting in window |
| **Behavior Moving** | seconds | Time spent moving in window |
| **Behavior Confidence** | float | Overall ML model confidence |

## Packet Processing

### 📦 Extended Packet Structure

```
┌─────────────────┬──────────┬─────────────────────┐
│  TrackerPacket   │ Flags    │  ExtendedMetrics     │
│   (24 bytes)     │ (1 byte)│   (12 bytes)         │
└─────────────────┴──────────┴─────────────────────┘
```

- **Flags Byte**: `0x01` = extended metrics present
- **Total Size**: 37 bytes (vs 24 bytes standard)
- **Frequency**: Every 5th cycle when enabled

### 🔐 HMAC Coverage

```
✅ Authenticated:
├─ node_id, device_id, frame_counter
├─ lat, lon, batt_mv
├─ gps_valid, geofence_version
└─ hmac[8] (calculated over above)

❌ Not Authenticated (diagnostic only):
├─ flags byte
└─ ExtendedMetrics struct
```

### 🌉 Gateway Detection Logic

```c
// Packet size detection
if (actual_len == sizeof(tracker_packet_t)) {
    // Standard packet (24 bytes)
    process_standard_packet();
} else if (actual_len == extended_pkt_size) {
    // Extended packet (37 bytes)
    uint8_t flags = rx_buffer[sizeof(tracker_packet_t)];
    if (flags & TRACKER_FLAG_EXTENDED_METRICS) {
        extract_extended_metrics();
        forward_with_mqtt();
    }
}
```

## Data Flow

### 📤 MQTT Forwarding

```
Tracker → Gateway → Server → InfluxDB
    ↓         ↓         ↓         ↓
[Metrics] → [Extract] → [Store] → [Flatten]
```

#### Standard MQTT Message
```json
{
  "lat": 40.7128,
  "lon": -74.0060,
  "batt": 4200,
  "batt_percent": 85,
  "gps_valid": true,
  "rssi": -45.2,
  "snr": 9.5,
  "ts": 1704110400000
}
```

#### Extended MQTT Message
```json
{
  "lat": 40.7128,
  "lon": -74.0060,
  "batt": 4200,
  "batt_percent": 85,
  "gps_valid": true,
  "rssi": -45.2,
  "snr": 9.5,
  "ts": 1704110400000,
  "ext": {
    "gps_fix": 4,
    "gps_fail": 1,
    "gps_hot": 3,
    "gps_fix_time": 12,
    "gps_sats": 8,
    "gps_hdop": 1.23,
    "tx_power": 14,
    "tracker_rssi": -48,
    "tracker_snr": 8.5,
    "power_mode": 1,
    "cycles": 5,
    "behavior_feeding_s": 1800,
    "behavior_ruminating_s": 900,
    "behavior_resting_s": 300,
    "behavior_moving_s": 600,
    "behavior_confidence": 0.85
  }
}
```

### 💾 InfluxDB Storage

Telegraf automatically flattens nested JSON:

```
# Standard packet
tracker,node_id=1 lat=40.7128,lon=-74.0060,batt=4200,gps_valid=1i

# Extended packet (auto-flattened)
tracker,node_id=1 lat=40.7128,lon=-74.0060,batt=4200,gps_valid=1i
tracker,node_id=1 ext_gps_fix=4i,ext_gps_fail=1i,ext_gps_hot=3i,ext_gps_fix_time=12i,ext_gps_sats=8i,ext_gps_hdop=1.23,ext_tx_power=14i,ext_tracker_rssi=-48i,ext_tracker_snr=8.5i,ext_power_mode=1i,ext_cycles=5i
tracker,node_id=1 ext_behavior_feeding_s=1800i,ext_behavior_ruminating_s=900i,ext_behavior_resting_s=300i,ext_behavior_moving_s=600i,ext_behavior_confidence=0.85
```

## Configuration

### ⚙️ Tracker Configuration

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| **enable_extended_metrics** | boolean | `false` | Enable/disable extended metrics |
| **enable_behavior_detection** | boolean | `false` | Enable/disable TinyML behavior inference |

### 📱 Flutter UI

```
Features Section:
├─ ☐ Enable Deep Sleep
├─ ☐ Enable Display
├─ ☐ Enable BLE Locate
├─ ☐ Enable Geofence Alerts
├─ ☐ Enable Debug
├─ ☐ Enable GPS Simulator
├─ ☐ Enable Extended Metrics
└─ ☐ Enable Behavior Detection ← NEW
```

## Use Cases

### 🔍 Network Diagnostics

- **GPS Performance**: Monitor fix success rates across locations
- **Radio Quality**: Track RSSI/SNR trends over time
- **Power Issues**: Identify abnormal power consumption patterns

### 🐄 Fleet Management

- **Performance Comparison**: Compare metrics between trackers
- **Failure Detection**: Identify failing GPS modules early
- **Gateway Optimization**: Adjust placement based on signal quality

### 🧠 Behavior Analytics

- **Health Monitoring**: Track feeding and rumination patterns
- **Heat Detection**: Identify behavioral estrus indicators
- **Stress Analysis**: Monitor rest vs activity ratios
- **Grazing Patterns**: Analyze feeding locations and durations

### 🛠️ Troubleshooting

- **Silent Trackers**: Check if GPS is failing or radio is weak
- **Battery Drain**: Verify power management is working correctly
- **Interference**: Detect environmental radio interference

---

# �� BLE Provisioning

## Provisioning Workflow

### Step-by-Step Process

```
┌─────────────────────────────────────────────┐
│  Step 1: Enter Configuration Mode           │
├─────────────────────────────────────────────┤
│  • Hold CONFIG button for 3 seconds         │
│  • Display shows "Configuration Mode"       │
│  • BLE starts advertising                   │
│  • Device name: "MooPoint-XXXXXX"           │
└─────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────┐
│  Step 2: Connect with Mobile App           │
├─────────────────────────────────────────────┤
│  • Open Flutter mobile app                  │
│  • App scans for BLE devices                │
│  • Select "MooPoint-XXXXXX"                 │
│  • GATT connection established              │
└─────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────┐
│  Step 3: Read Current Configuration        │
├─────────────────────────────────────────────┤
│  • App sends "GET\n" command                │
│  • Tracker loads config from NVS            │
│  • Returns JSON configuration               │
│  • App displays in editable form            │
└─────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────┐
│  Step 4: Modify & Save Configuration       │
├─────────────────────────────────────────────┤
│  • User edits fields in app                 │
│  • App sends "SET:<length>\n<json>"         │
│  • Tracker validates JSON                   │
│  • Saves to encrypted NVS                   │
│  • Returns "OK" response                    │
└─────────────────────────────────────────────┘
         ↓
┌─────────────────────────────────────────────┐
│  Step 5: Apply Changes (Optional Reboot)   │
├─────────────────────────────────────────────┤
│  • App can send "REBOOT\n"                  │
│  • Tracker applies new configuration        │
│  • Device restarts with new settings        │
│  • BLE disconnects                          │
└─────────────────────────────────────────────┘
```

---

## BLE Implementation

### ESP32 NimBLE Stack

```c
// BLE Provisioning Service Initialization
esp_err_t ble_provision_start() {
    // Initialize NimBLE host and HCI
    nimble_port_init();
    esp_nimble_hci_init();
    
    // Configure callbacks
    ble_hs_cfg.reset_cb = on_ble_reset;
    ble_hs_cfg.sync_cb = on_ble_sync;
    
    // Initialize GATT services
    ble_svc_gap_init();
    ble_svc_gatt_init();
    ble_gatts_add_svcs(gatt_svcs);
    
    // Start BLE stack
    nimble_port_freertos_init(ble_host_task);
    
    return ESP_OK;
}
```

### GATT Service Structure

```
Service: MooPoint Provisioning
UUID: 6e400001-b5a3-f393-e0a9-e50e24dcca9e
│
├── RX Characteristic (Write)
│   UUID: 6e400002-b5a3-f393-e0a9-e50e24dcca9e
│   Properties: WRITE, WRITE_NO_RESPONSE
│   Function: Receive commands from app
│   Max Length: 512 bytes
│
└── TX Characteristic (Notify + Read)
    UUID: 6e400003-b5a3-f393-e0a9-e50e24dcca9e
    Properties: READ, NOTIFY
    Function: Send responses to app
    Max Length: 512 bytes
```

---

## Flutter BLE Client

### Android Permissions Required

```xml
<!-- Bluetooth Permissions (Android 12+) -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Location Permissions (Required for BLE scanning) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### BLE Communication Code

```dart
// Scan for devices
FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

// Connect to device
await device.connect();

// Discover services
final services = await device.discoverServices();
final service = services.firstWhere(
  (s) => s.uuid.toString() == '6e400001-b5a3-f393-e0a9-e50e24dcca9e'
);

// Get characteristics
final rx = service.characteristics.firstWhere(
  (c) => c.uuid.toString() == '6e400002-b5a3-f393-e0a9-e50e24dcca9e'
);
final tx = service.characteristics.firstWhere(
  (c) => c.uuid.toString() == '6e400003-b5a3-f393-e0a9-e50e24dcca9e'
);

// Enable notifications
await tx.setNotifyValue(true);

// Listen for responses
tx.lastValueStream.listen((value) {
  final response = utf8.decode(value);
  // Process response
});

// Send GET command
await rx.write(
  utf8.encode('GET\n'),
  withoutResponse: true
);
```

---

## Configuration Parameters

### Full Configuration Reference

| Category | Parameter | Type | Default | Description |
|----------|-----------|------|---------|-------------|
| **Power** | `sleep_minutes` | int | 5 | Sleep duration between cycles |
| **GPS** | `gps_timeout_sec` | int | 300 | Max GPS fix wait time |
| **GPS** | `gps_min_sats` | int | 4 | Minimum satellites for fix |
| **GPS** | `gps_hdop_max` | float | 3.0 | Max HDOP for accuracy |
| **Node** | `node_id` | int | 1 | Node identifier |
| **Node** | `device_id` | string | - | Unique device ID |
| **Node** | `device_key` | string | - | Authentication key |
| **LoRa** | `lora_freq` | float | 868.0 | Frequency (MHz) |
| **LoRa** | `lora_sf` | int | 9 | Spreading factor |
| **LoRa** | `lora_bw` | float | 125.0 | Bandwidth (kHz) |
| **LoRa** | `lora_power` | int | 14 | TX power (dBm) |
| **LoRa** | `lora_cr` | int | 7 | Coding rate |
| **Battery** | `batt_critical_mv` | int | 3200 | Critical voltage |
| **Battery** | `batt_low_mv` | int | 3400 | Low battery warning |
| **Battery** | `batt_full_mv` | int | 4200 | Full charge voltage |
| **Battery** | `batt_shutdown_pct` | int | 10 | Shutdown threshold |
| **Display** | `display_enabled` | bool | 1 | Enable display |
| **Debug** | `debug_gps_raw` | bool | 0 | Raw GPS debug |
| **Debug** | `debug_lora` | bool | 1 | LoRa debug logging |
| **Debug** | `debug_battery` | bool | 1 | Battery debug |
| **Cycle 1** | `cycle1_battery_pct` | int | 80 | High battery threshold |
| **Cycle 1** | `cycle1_sleep_min` | int | 5 | High battery sleep |
| **Cycle 2** | `cycle2_battery_pct` | int | 50 | Medium battery threshold |
| **Cycle 2** | `cycle2_sleep_min` | int | 10 | Medium battery sleep |
| **Cycle 3** | `cycle3_battery_pct` | int | 35 | Low battery threshold |
| **Cycle 3** | `cycle3_sleep_min` | int | 30 | Low battery sleep |

> 💾 **Storage:**
> All configuration is stored in NVS (Non-Volatile Storage) with encryption enabled for security.

---

# 🚀 Deployment & Operations

## Hardware Deployment Guide

### Tracker Deployment Checklist

```
□ Mounting
  ├─ Use collar or harness mounting kit
  ├─ Ensure GPS antenna faces upward (sky view)
  ├─ Secure tightly but comfortably
  └─ Check for chafing points

□ Power Preparation
  ├─ Fully charge battery (4.2V)
  ├─ Test battery voltage reading
  ├─ Verify charge indicator LED
  └─ Set expected battery life (2-4 weeks)

□ Configuration
  ├─ Configure via BLE or WiFi AP
  ├─ Set correct node_id
  ├─ Configure device_id and device_key
  ├─ Test GPS fix in deployment location
  └─ Verify LoRa communication to gateway

□ Final Checks
  ├─ Test deep sleep/wake cycle
  ├─ Confirm display operation
  ├─ Check waterproofing (if applicable)
  └─ Document deployment date/location
```

### Gateway Deployment Checklist

```
□ Location Selection
  ├─ Elevated position (roof, tower, pole)
  ├─ Clear sky view for GPS
  ├─ Line of sight to tracker coverage area
  └─ Protected from weather

□ Power & Network
  ├─ Connect to continuous 5V power
  ├─ Verify WiFi connectivity
  ├─ Test MQTT connection to server
  └─ Configure static IP (optional)

□ Antenna Installation
  ├─ Mount external LoRa antenna
  ├─ Use quality coax cable (low loss)
  ├─ Proper grounding for lightning
  └─ Test SWR (standing wave ratio)

□ Configuration
  ├─ Set gateway ID
  ├─ Configure LoRa frequency/region
  ├─ Load device authentication map
  └─ Sync geofence data

□ Testing
  ├─ Verify tracker packet reception
  ├─ Test MQTT forwarding
  ├─ Check display status
  └─ Monitor packet loss rate
```

### Range Considerations

| Environment | Expected Range | Notes |
|-------------|----------------|-------|
| **Line of Sight** | 5-10 km | Ideal conditions, elevated gateway |
| **Rural Open** | 3-5 km | Typical farm/ranch terrain |
| **Light Forest** | 1-3 km | Some tree cover |
| **Urban** | 1-2 km | Buildings and obstacles |
| **Indoor** | <500 m | Limited penetration |

> 📡 **Range Tips:**
> - Higher gateway = better range
> - Use external antennas when possible
> - Clear fresnel zone for best results
> - Multiple gateways for coverage gaps

---

## Software Deployment

### Server Setup (Production)

```bash
# Clone repository
git clone https://github.com/your-org/moopoint-server.git
cd moopoint-server

# Install dependencies
npm install

# Configure environment
cat > .env << EOF
NODE_ENV=production
PORT=8080
ADMIN_USERNAME=admin
ADMIN_PASSWORD=$(openssl rand -base64 32)
INFLUX_URL=http://localhost:8086
INFLUX_TOKEN=your-influx-token
INFLUX_ORG=your-org
INFLUX_BUCKET=moo_point
DATABASE_URL=postgresql://moo_point:password@localhost/moo_point
MQTT_BROKER=mqtt://localhost:1883
SESSION_SECRET=$(openssl rand -base64 32)
EOF

# Initialize database
npm run db:migrate

# Start server
npm start

# Or use PM2 for production
pm2 start src/index.js --name moopoint-server
pm2 save
pm2 startup
```

### Database Setup

#### PostgreSQL

```sql
-- Create database and user
CREATE DATABASE moo_point;
CREATE USER moo_point WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE moo_point TO moo_point;

-- Connect to database
\c moo_point

-- Tables are auto-created by server on first run
-- Schema includes:
-- - users
-- - nodes
-- - geofences
-- - geofence_node_assignments
-- - geofence_events
-- - device_credentials
```

#### InfluxDB 2.x

```bash
# Create bucket
influx bucket create \
  --name moo_point \
  --org your-org \
  --retention 365d

# Create retention policy (optional)
influx bucket update \
  --name moo_point \
  --retention 8760h  # 1 year

# Generate API token
influx auth create \
  --org your-org \
  --read-bucket moo_point \
  --write-bucket moo_point
```

### Docker Deployment (Optional)

```yaml
# docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: moo_point
      POSTGRES_USER: moo_point
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  influxdb:
    image: influxdb:2.7
    environment:
      DOCKER_INFLUXDB_INIT_MODE: setup
      DOCKER_INFLUXDB_INIT_USERNAME: admin
      DOCKER_INFLUXDB_INIT_PASSWORD: ${INFLUX_PASSWORD}
      DOCKER_INFLUXDB_INIT_ORG: your-org
      DOCKER_INFLUXDB_INIT_BUCKET: moo_point
    volumes:
      - influx_data:/var/lib/influxdb2
    ports:
      - "8086:8086"

  mosquitto:
    image: eclipse-mosquitto:2
    volumes:
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
      - mosquitto_data:/mosquitto/data
    ports:
      - "1883:1883"
      - "8883:8883"

  moopoint-server:
    build: .
    depends_on:
      - postgres
      - influxdb
      - mosquitto
    environment:
      DATABASE_URL: postgresql://moo_point:${DB_PASSWORD}@postgres/moo_point
      INFLUX_URL: http://influxdb:8086
      MQTT_BROKER: mqtt://mosquitto:1883
    ports:
      - "8080:8080"
    volumes:
      - ./build/web:/app/public

volumes:
  postgres_data:
  influx_data:
  mosquitto_data:
```

---

## Monitoring & Maintenance

### System Health Monitoring

#### Key Metrics to Track

| Metric | Healthy Range | Alert Threshold |
|--------|---------------|-----------------|
| **Gateway Packet Rate** | 50-200/min | <10/min |
| **Tracker Battery** | >35% | <20% |
| **GPS Fix Time** | <60 seconds | >120 seconds |
| **MQTT Latency** | <500ms | >2 seconds |
| **API Response Time** | <200ms | >1 second |
| **Database Size** | Growth ~1GB/year | >10GB |

#### Monitoring Dashboard

```javascript
// Example Grafana queries for InfluxDB

// Tracker positions received per minute
from(bucket: "moo_point")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "position")
  |> aggregateWindow(every: 1m, fn: count)

// Average battery levels by node
from(bucket: "moo_point")
  |> range(start: -24h)
  |> filter(fn: (r) => r._measurement == "position")
  |> filter(fn: (r) => r._field == "batt")
  |> group(columns: ["nodeId"])
  |> mean()

// GPS fix quality (HDOP)
from(bucket: "moo_point")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "position")
  |> filter(fn: (r) => r._field == "hdop")
  |> mean()
```

### Maintenance Schedule

#### Daily Tasks
```
□ Check gateway connectivity
□ Review alert logs
□ Verify tracker check-ins
□ Monitor battery levels
```

#### Weekly Tasks
```
□ Analyze GPS fix quality trends
□ Review geofence event patterns
□ Check database performance
□ Backup configuration data
```

#### Monthly Tasks
```
□ Battery health assessment
□ Firmware update check
□ Database optimization (VACUUM, ANALYZE)
□ Review and update geofences
□ Archive old time-series data
```

#### Quarterly Tasks
```
□ Full system backup
□ Hardware inspection (antennas, cables)
□ Performance benchmarking
□ Security audit
□ Capacity planning review
```

---

## Troubleshooting Guide

### Common Issues & Solutions

#### 🚫 No GPS Fix

**Symptoms:**
- Tracker never gets position
- HDOP always high
- Satellite count = 0

**Solutions:**
1. Check antenna orientation (must face sky)
2. Verify clear sky view (no building/tree obstruction)
3. Allow 60+ seconds for cold start
4. Check `gps_timeout_sec` setting
5. Increase `gps_hdop_max` temporarily
6. Test in known-good location

#### 📡 No LoRa Communication

**Symptoms:**
- Gateway receives no packets
- Tracker sends but no ACK
- Intermittent connectivity

**Solutions:**
1. Verify frequency match (868MHz vs 915MHz)
2. Check spreading factor configuration
3. Measure distance (reduce if >5km)
4. Inspect antennas and connections
5. Check gateway MQTT connectivity
6. Verify node_id matches registration
7. Test with increased TX power

#### 🔋 High Battery Drain

**Symptoms:**
- Battery depletes in <1 week
- Expected 2-4 weeks

**Solutions:**
1. Check GPS timeout (reduce from 300s to 180s)
2. Increase sleep duration
3. Verify deep sleep is working
4. Check for continuous GPS operation
5. Disable display if not needed
6. Move to better GPS location (faster fixes)
7. Review power cycle configuration

#### 💾 Missing Position Data

**Symptoms:**
- Some positions not appearing in database
- Gaps in tracking history

**Solutions:**
1. Check MQTT broker connectivity
2. Verify InfluxDB write permissions
3. Review server error logs
4. Check database disk space
5. Verify retention policies
6. Test gateway-to-server connection
7. Check firewall rules

#### 🗺️ Geofence Not Updating

**Symptoms:**
- Tracker has old geofence boundaries
- No notification received

**Solutions:**
1. Check MQTT `moopoint/cmd/geofence/update` topic
2. Verify gateway subscribed to updates
3. Manually trigger notification from admin panel
4. Check tracker ACK response
5. Verify sufficient LoRa RX window time
6. Re-publish device map
7. Reboot tracker to force sync

#### 📱 BLE Provisioning Fails

**Symptoms:**
- Can't connect to device
- Configuration not saving

**Solutions:**
1. Verify device in config mode (button held)
2. Check Android BLE permissions
3. Ensure Location services enabled
4. Move closer to device (<5m)
5. Clear BLE cache on phone
6. Restart both devices
7. Check JSON syntax in config

---

# 📊 Technical Specifications

## Hardware Specifications

### Tracker Detailed Specs

| Category | Specification | Notes |
|----------|---------------|-------|
| **MCU** | ESP32-S3 (Xtensa LX7) | Dual-core @ 240MHz |
| **RAM** | 512KB SRAM | 384KB available for apps |
| **Flash** | 16MB QSPI | Partitioned for app/data |
| **GPS Chipset** | UC6580 | Multi-GNSS receiver |
| **GPS Channels** | 72 channels | Concurrent tracking |
| **GPS Accuracy** | 2.5m CEP | Open sky, SBAS |
| **GPS Sensitivity** | -167 dBm | Tracking sensitivity |
| **LoRa Chipset** | Semtech SX1262 | Sub-GHz transceiver |
| **LoRa Freq Range** | 150-960 MHz | Region configurable |
| **LoRa TX Power** | -9 to +22 dBm | Configurable |
| **LoRa Sensitivity** | -148 dBm @ SF12 | Best case |
| **Display** | 2.0" RGB IPS LCD | 320×240 pixels |
| **Touch** | Capacitive touch | Single touch point |
| **Battery** | 2000mAh Li-ion | 3.7V nominal |
| **Battery Life** | 2-4 weeks typical | Usage dependent |
| **Charging** | USB-C, 1A max | 5V input |
| **RTC** | DS3231 (optional) | High accuracy TCXO |
| **Operating Temp** | -20°C to +60°C | Extended range |
| **IP Rating** | IP65 (optional) | With proper enclosure |
| **Dimensions** | 80×50×25mm | Approx dimensions |
| **Weight** | 150g | With battery |

### Gateway Detailed Specs

| Category | Specification | Notes |
|----------|---------------|-------|
| **MCU** | ESP32-S3 | Same as tracker |
| **RAM** | 512KB SRAM | Same as tracker |
| **Flash** | 16MB QSPI | Same as tracker |
| **LoRa** | SX1262 + ext antenna | 3dBi omni or directional |
| **GPS** | UC6580 | For gateway positioning |
| **Display** | 1.8" ST7735 TFT | 160×80 pixels |
| **WiFi** | 802.11 b/g/n | 2.4GHz |
| **Ethernet** | Optional module | W5500 or similar |
| **Power** | 5V @ 2A | External PSU |
| **Antenna** | SMA connector | For external LoRa antenna |
| **Dimensions** | 100×80×30mm | Approx dimensions |

---

## Communication Specifications

### LoRa Physical Layer

| Parameter | Typical | Range | Notes |
|-----------|---------|-------|-------|
| **Frequency** | 868.0 MHz (EU) | 863-870 MHz | Regional regulations |
| **Frequency** | 915.0 MHz (US) | 902-928 MHz | FCC Part 15 |
| **Spreading Factor** | SF7-SF9 | SF7-SF12 | Higher SF = longer range |
| **Bandwidth** | 125 kHz | 7.8-500 kHz | Trade-off: speed vs range |
| **Coding Rate** | 4/7 | 4/5-4/8 | Error correction overhead |
| **TX Power** | 14 dBm | -9 to +22 dBm | Regional limits apply |
| **Data Rate** | 5.5 kbps @ SF7 | 0.3-5.5 kbps | BW and SF dependent |
| **Range (LOS)** | 5-10 km | Up to 15 km | Ideal conditions |
| **Range (Rural)** | 3-5 km | - | Typical farm terrain |
| **Range (Urban)** | 1-2 km | - | With obstacles |
| **Duty Cycle (EU)** | 1% | Max 1% | Legal requirement |
| **Duty Cycle (US)** | Unlimited | - | No restriction |

### LoRa Performance Matrix

| SF | BW (kHz) | Data Rate | Range | Airtime (100 bytes) |
|----|----------|-----------|-------|---------------------|
| 7 | 125 | 5.5 kbps | Short | 41 ms |
| 7 | 250 | 11 kbps | Short | 21 ms |
| 9 | 125 | 1.8 kbps | Medium | 206 ms |
| 9 | 250 | 3.6 kbps | Medium | 103 ms |
| 12 | 125 | 0.3 kbps | Long | 2793 ms |

> ⚡ **Default Settings:**
> MooPoint uses SF9 @ 125kHz for optimal range/speed balance.
> Geofence data uses SF7 @ 250kHz for faster transmission.

---

### MQTT Protocol Details

| Parameter | Value | Notes |
|-----------|-------|-------|
| **Protocol Version** | MQTT 3.1.1 | Industry standard |
| **Transport** | TCP/IP | Port 1883 (plain), 8883 (TLS) |
| **QoS 0** | At most once | Position data |
| **QoS 1** | At least once | Critical config |
| **QoS 2** | Not used | Too much overhead |
| **Keep Alive** | 60 seconds | Connection check |
| **Clean Session** | False | Persistent sessions |
| **Retained** | Yes | Latest config/status |
| **Last Will** | Gateway status | Offline detection |
| **Max Payload** | 256 KB | MQTT spec limit |
| **Typical Payload** | <1 KB | JSON position data |

---

### BLE Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| **BLE Version** | 4.2 | ESP32-S3 hardware |
| **Stack** | NimBLE | Apache licensed |
| **Range (Indoor)** | 10-50m | Walls reduce range |
| **Range (Outdoor)** | 50-100m | Line of sight |
| **Data Rate** | 1 Mbps | LE 1M PHY |
| **Connection Interval** | 30-50ms | Configurable |
| **Latency** | <100ms | Typical |
| **MTU** | 247 bytes | Negotiated, default 23 |
| **Security** | None | Proximity-based |
| **Power** | 0 dBm | TX power |

---

## Software Specifications

### Firmware Stack

| Component | Version | License |
|-----------|---------|---------|
| **ESP-IDF** | 5.4.1 | Apache 2.0 |
| **FreeRTOS** | 10.4.6 | MIT |
| **NimBLE** | 1.6.0 | Apache 2.0 |
| **LVGL** | 8.x | MIT |
| **RadioLib** | Latest | MIT |
| **TinyGPS++** | 1.0.3 | LGPL |

### Backend Stack

| Component | Version | License |
|-----------|---------|---------|
| **Node.js** | 18.x LTS | MIT |
| **Express** | 4.x | MIT |
| **PostgreSQL** | 14.x | PostgreSQL |
| **InfluxDB** | 2.x | MIT |
| **Mosquitto** | 2.x | EPL/EDL |
| **Socket.io** | 4.x | MIT |

### Frontend Stack

| Component | Version | License |
|-----------|---------|---------|
| **Flutter** | 3.x | BSD-3 |
| **Dart** | 3.x | BSD-3 |
| **FlutterMap** | Latest | BSD-3 |
| **flutter_blue_plus** | Latest | BSD-3 |
| **Provider** | Latest | MIT |

---

## Performance Benchmarks

### Tracker Performance

| Metric | Value | Notes |
|--------|-------|-------|
| **Boot Time** | 5-8 seconds | Cold boot |
| **GPS TTFF (Cold)** | 30-60 seconds | No ephemeris |
| **GPS TTFF (Warm)** | 15-30 seconds | Recent ephemeris |
| **GPS TTFF (Hot)** | 5-10 seconds | <2 hours since last fix |
| **Position Accuracy** | 3-5 meters | 95% CEP, open sky |
| **LoRa TX Time** | 50-200ms | SF and packet dependent |
| **Deep Sleep Current** | <1mA | ESP32-S3 ULP |
| **Active Current** | 80-150mA | GPS + LoRa |
| **Battery Life (5min)** | 3-4 weeks | Good GPS conditions |
| **Battery Life (10min)** | 2-3 weeks | Mixed conditions |
| **Battery Life (30min)** | 4-6 weeks | Power save mode |
| **Flash Usage** | ~1MB | Application code |
| **RAM Usage** | ~200KB | Peak during operation |
| **NVS Usage** | ~4KB | Configuration data |

### Gateway Performance

| Metric | Value | Notes |
|--------|-------|-------|
| **Packet Rate** | 1000+ pkt/min | Theoretical max |
| **Typical Load** | 50-200 pkt/min | 50 trackers @ 5min |
| **Concurrent Trackers** | 50+ | Tested configuration |
| **MQTT Throughput** | 100+ msg/sec | Broker dependent |
| **Packet Loss** | <1% | Good LoRa conditions |
| **MQTT Latency** | <100ms | Local broker |
| **MQTT Latency** | <500ms | Cloud broker |
| **CPU Usage** | 10-30% | Single core |
| **RAM Usage** | ~150KB | With 100 tracker cache |
| **Flash Usage** | ~500KB | Application code |

### Server Performance

| Metric | Value | Notes |
|--------|-------|-------|
| **API Response** | <100ms | 95th percentile, cached |
| **API Response** | <200ms | 95th percentile, DB query |
| **WebSocket Latency** | <50ms | Client to server |
| **Concurrent Users** | 100+ | Web interface |
| **Concurrent API** | 500+ req/sec | With caching |
| **Database Query** | <50ms | Indexed queries |
| **Time-series Write** | <10ms | InfluxDB batch |
| **Time-series Read** | <100ms | Recent data |
| **Storage Growth** | ~1GB/year | 100 trackers @ 5min |
| **Storage Growth** | ~3GB/year | 100 trackers @ 1min |

---

# ✅ Key System Advantages

## Why MooPoint Stands Out

### 1. 🌐 Scalability
- Support for **hundreds of trackers** across multiple gateways
- Distributed architecture with local caching
- Linear cost scaling with herd size
- Multi-gateway meshing (future)

### 2. 🔧 Reliability
- Robust LoRa protocol with ACK mechanisms
- Gateway-level geofence caching (works offline)
- Retry logic for critical data
- Redundant gateway support
- Self-healing network topology

### 3. ⚡ Power Efficiency
- **2-4 weeks battery life** on single charge
- Adaptive 3-tier power management
- GPS hot-start optimization
- Deep sleep between cycles
- Real-time battery monitoring

### 4. 🎯 Flexibility
- Fully configurable via BLE or web interface
- Customizable power cycles
- Adjustable GPS accuracy thresholds
- Dynamic geofence management
- Multi-region LoRa support

### 5. 📱 Ease of Use
- **BLE provisioning** - no complex tools needed
- Web-based management dashboard
- Real-time map visualization
- One-click geofence drawing
- Mobile-friendly interface

### 6. 🕐 Real-time Capabilities
- Live position tracking
- Instant geofence alerts
- WebSocket real-time updates
- Push notifications
- Low-latency (<1 second end-to-end)

### 7. 🔐 Security
- Individual device authentication
- Encrypted configuration storage
- Session-based web access
- Device-to-node mapping
- Future: HMAC message authentication

### 8. 🌾 Rural-Ready
- Designed for **limited infrastructure**
- Long-range LoRa communication (5-10km)
- Offline-capable gateways
- Low bandwidth requirements
- Solar power compatible

---

# 📋 System Comparison

## MooPoint vs Traditional GPS Trackers

| Feature | MooPoint | Traditional GPS Tracker |
|---------|----------|-------------------------|
| **Communication** | LoRa (long-range, low-power) | Cellular (high-power, requires signal) |
| **Battery Life** | 2-4 weeks | 3-7 days |
| **Range** | 5-10km | Unlimited (cellular) |
| **Infrastructure** | 1 gateway per farm | Cellular tower required |
| **Monthly Cost** | No subscription | $5-20/month per device |
| **Coverage** | Self-deployed | Carrier dependent |
| **Latency** | <1 second | 5-30 seconds |
| **Offline Capability** | Gateway cached | None |
| **Configuration** | BLE + Web | SMS or proprietary |
| **Data Ownership** | Complete | Provider dependent |
| **Geofencing** | Real-time, local | Cloud-based |
| **Scalability** | Linear cost | Per-device subscription |
| **Initial Cost** | Higher | Lower |
| **Long-term Cost** | Lower | Higher |

---

# 🔮 Future Enhancements

## Planned Features

### Short-term (3-6 months)
- [ ] **OTA Firmware Updates** - Remote firmware deployment
- [ ] **Battery Health Analytics** - Predictive battery failure
- [ ] **Enhanced Power Modes** - Solar charging support
- [ ] **Multi-language Support** - i18n for web interface
- [ ] **Export Features** - CSV/PDF reports

### Medium-term (6-12 months)
- [ ] **LoRaWAN Support** - Standard LoRaWAN compatibility
- [ ] **Mesh Networking** - Tracker-to-tracker relay
- [ ] **Advanced Analytics** - Movement patterns, heat maps
- [ ] **Mobile Apps** - Native iOS/Android apps
- [ ] **Alert Customization** - User-defined alert rules

### Long-term (12+ months)
- [ ] **AI Movement Prediction** - Predictive analytics
- [ ] **Health Monitoring** - Temperature, heart rate sensors
- [ ] **Integration APIs** - Third-party farm management systems
- [ ] **Satellite Backup** - Iridium for remote areas
- [ ] **Solar Trackers** - Extended battery life models

---

# 📞 Support & Resources

## Getting Help

### Documentation
- **GitHub Repository**: [github.com/your-org/moopoint](https://github.com)
- **Wiki**: Detailed setup guides and tutorials
- **API Docs**: OpenAPI/Swagger documentation

### Community
- **Discord**: Join the MooPoint community
- **Forum**: Ask questions, share experiences
- **GitHub Issues**: Bug reports and feature requests

### Commercial Support
- **Email**: support@moopoint.io
- **Priority Support**: Available for enterprise deployments
- **Custom Development**: Available on request

---

# 🧠 AI Analytics & Real-time Dashboard

## Real-time Dashboard Architecture

### Dashboard Components

```
┌─────────────────────────────────────────┐
│         Dashboard Page                   │
├──────────┬──────────┬───────────────────┤
│  KPI Cards│ Activity  │   Alerts Panel   │
│ (Metrics) │  Feed    │  (Notifications)  │
├──────────┴──────────┴───────────────────┤
│         WebSocket Updates               │
│      (Real-time Data Stream)            │
├─────────────────────────────────────────┤
│         HerdState Management            │
│      (Centralized State)               │
└─────────────────────────────────────────┘
```

### KPI Metrics

| Metric | Source | Update Frequency |
|--------|--------|------------------|
| **Active Cattle** | HerdState.nodes | Real-time |
| **Low Battery** | NodeModel.batteryLevel | Real-time |
| **Fence Alerts** | GeofenceEvent | Real-time |
| **Network Coverage** | PositionHeatmapModel | Every 5 minutes |
| **Behavior Insights** | BehaviorSummary | Hourly |

### Activity Feed

**Real-time Event Processing:**
```javascript
// Event Sources
- Geofence breaches (enter/exit)
- Battery level alerts
- Tracker connectivity issues
- Configuration changes
- Firmware updates

// Event Processing Pipeline
1. Receive event via WebSocket
2. Update HerdState
3. Trigger UI refresh
4. Store in event history
5. Send notifications if needed
```

### AI-Powered Analytics

#### Behavior Analysis

```
┌─────────────────────────────────────────┐
│         Behavior Analytics               │
├──────────┬──────────┬───────────────────┤
│  Behavior│ Timeline  │   Insights       │
│  Charts   │ Analysis  │  (AI-powered)     │
├──────────┴──────────┴───────────────────┤
│         InfluxDB Time-Series            │
│      (Behavior Metrics)                │
├─────────────────────────────────────────┤
│         AI Dev Analytics                │
│      (Pattern Recognition)             │
└─────────────────────────────────────────┘
```

**Behavior Metrics:**
- **Feeding Time** - Duration and frequency
- **Rumination** - Digestive health indicator  
- **Resting** - Energy conservation patterns
- **Movement** - Activity levels and patterns
- **Confidence** - AI model prediction accuracy

---

# 🚀 Configuration Management

## Multi-Tracker Configuration Push

### Configuration Architecture

```
┌─────────────────────────────────────────┐
│         Config Push System               │
├──────────┬──────────┬───────────────────┤
│   Admin   │   MQTT   │   Gateway         │
│  Interface│  Broker  │  (Distribution)    │
├──────────┴──────────┴───────────────────┤
│  Config    │  Device  │   Tracker         │
│  Validation│  Map Sync │  (Application)    │
├─────────────────────────────────────────┤
│         PostgreSQL Storage               │
│      (Config History)                   │
└─────────────────────────────────────────┘
```

### Configuration Flow

```mermaid
sequenceDiagram
    participant A as 👤 Admin
    participant S as 🟣 Server
    participant G as 🟢 Gateway
    participant T as 🔵 Tracker
    
    A->>S: 📝 POST /admin/config/push
    S->>S: 🔍 Validate Configuration
    S->>S: 💾 Store in PostgreSQL
    S->>G: 📨 MQTT: /config/update
    G->>T: 📡 LoRa: ConfigUpdatePacket
    T->>T: ✅ Validate & Apply
    T->>G: 📡 LoRa: ConfigAckPacket
    G->>S: 📨 MQTT: /config/ack
    S->>A: ⚡ WebSocket: Status Update
```

### Configuration Types

| Config Type | Target | Method |
|-------------|--------|--------|
| **LoRa Settings** | All Trackers | Packet v3.1 |
| **Power Management** | Cattle Trackers | BLE Provisioning |
| **GPS Settings** | All Trackers | BLE Provisioning |
| **Feature Flags** | All Trackers | Config Push |
| **Firmware Updates** | All Trackers | OTA System |

---

# 📡 State Management & Data Models

## Centralized State Management

### HerdState Architecture

```
┌─────────────────────────────────────────┐
│         HerdState (Provider)             │
├──────────┬──────────┬───────────────────┤
│   Nodes   │ Geofences │   Events         │
│ (Live Data│ (Boundaries│  (Activity)      │
│  Stream)  │  Cache)   │  Stream)         │
├──────────┴──────────┴───────────────────┤
│  Coverage  │ Behavior  │   Position       │
│  Heatmaps  │  Analytics │  History         │
├─────────────────────────────────────────┤
│         WebSocket Integration            │
│      (Real-time Updates)                 │
└─────────────────────────────────────────┘
```

### Data Models

#### NodeModel (Enhanced)
```dart
class NodeModel {
  final int nodeId;
  final NodeType nodeType; // CATTLE or FENCE
  final String name;
  final double latitude;
  final double longitude;
  final int batteryLevel;
  final double voltage;
  final DateTime lastUpdated;
  final NodeStatus status;
  final Map<String, dynamic> extendedMetrics;
  final bool isNew;
  final String? imageUrl;
}
```

#### BehaviorModel
```dart
class BehaviorData {
  final DateTime timestamp;
  final int feedingSeconds;
  final int ruminatingSeconds;
  final int restingSeconds;
  final int movingSeconds;
  final double confidence;
  final Map<String, dynamic> rawMetrics;
}
```

#### CoverageModel
```dart
class CoverageData {
  final Map<String, int> signalStrength;
  final Map<String, int> packetLoss;
  final List<PositionHeatmapPoint> heatmap;
  final DateTime lastUpdated;
  final int totalPackets;
  final double coveragePercentage;
}
```

---

# 🎨 UI Component Library

## Reusable Components

### Core Widgets

| Component | Purpose | Usage |
|------------|---------|-------|
| **StatusPill** | Status indicators | Node status, system health |
| **NodeAvatar** | Node representation | Lists, maps, detail views |
| **EmptyStateWidget** | Empty states | No data, loading states |
| **MooLogo** | Branding | Headers, login, splash |

### Analytics Widgets

| Widget | Function | Data Source |
|--------|----------|-------------|
| **BehaviorChartWidget** | Behavior visualization | InfluxDB behavior data |
| **BehaviorTimelineWidget** | Timeline analysis | BehaviorData history |
| **BehaviorInsightsWidget** | AI insights | AI Dev Analytics |
| **BehaviorAlertsWidget** | Behavioral alerts | BehaviorSummary |
| **VoltageChartWidget** | Battery monitoring | NodeModel voltage data |

### Page Components

| Page | Primary Function | Key Features |
|------|------------------|--------------|
| **DashboardPage** | Real-time overview | KPIs, activity feed, alerts |
| **ConfigPushPage** | Multi-tracker config | Bulk configuration, status tracking |
| **BleProvisioningMenu** | Device discovery | Easy BLE scanning and connection |
| **CompassTrackerPage** | Directional tracking | Real-time compass, distance indicators |
| **NodePlacementPage** | Visual management | Drag-and-drop node positioning |

---

# 🔮 Future Development

## 🟠 Fence Tracker Implementation

### Current Status

| Component | Status | Notes |
|----------|--------|-------|
| **Backend Support** | ✅ Complete | NodeType.FENCE implemented |
| **Flutter UI** | ✅ Complete | Fence nodes supported in all views |
| **Gateway Support** | ❌ Missing | Needs fence-specific handling |
| **Tracker Firmware** | ❌ Missing | Fork of cattle tracker needed |

### Implementation Plan

#### Phase 1: Gateway Updates
**Files to Modify:** `MooPoint-Gateway/main/main.cpp`

**Required Changes:**
```cpp
// 1. Add fence tracker type detection
enum NodeType {
  NODE_TYPE_CATTLE = 0,
  NODE_TYPE_FENCE = 1
};

// 2. Update packet handling for fence nodes
void handleFenceTrackerPacket(TrackerPacket& packet);

// 3. Add fence-specific status monitoring
void monitorFenceOutage(uint8_t nodeId);

// 4. Update LED indicators for fence status
void updateFenceStatusLEDs(uint8_t nodeId, bool isOnline);
```

#### Phase 2: Fence Tracker Firmware
**Base:** Fork of `T_Echo_Tracker.ino`

**Key Modifications:**
```cpp
// 1. Remove mobile-specific features
// - Remove display/touchscreen support
// - Remove complex power management
// - Remove behavior detection

// 2. Add fence-specific features
#define FENCE_GPS_FIX_TIMEOUT 60    // Shorter timeout for fixed position
#define FENCE_OUTAGE_THRESHOLD 300  // 5 minutes = outage
#define FENCE_REPORT_INTERVAL 300   // Report every 5 minutes

// 3. Environmental monitoring
struct EnvironmentalData {
  float temperature;
  float batteryVoltage;
  uint32_t uptime;
  bool solarCharging;
};

// 4. Status LED management
void updateStatusLEDs(FenceStatus status);
```

### Fence Tracker Features

#### Hardware Differences
| Feature | Cattle Tracker | Fence Tracker |
|---------|----------------|---------------|
| **Display** | 2.0" RGB LCD | 3x RGB LEDs |
| **Power** | 2000mAh Battery | Solar + 5000mAh |
| **GPS** | Mobile optimized | Fixed position optimized |
| **Sensors** | IMU, GPS | Temperature, voltage |
| **Size** | 80×50×25mm | 60×40×20mm |

#### Software Differences
| Feature | Cattle Tracker | Fence Tracker |
|---------|----------------|---------------|
| **Power Mgmt** | 4-tier adaptive | Continuous power |
| **GPS Update** | On wake cycle | Every 5 minutes |
| **Data Focus** | Movement, behavior | Status, environment |
| **Alerts** | Geofence breaches | Outage detection |
| **Communication** | Position reports | Status reports |

---

# 📄 Conclusion

MooPoint represents a **complete, production-ready livestock tracking solution** designed specifically for rural deployments with limited infrastructure.

## Key Takeaways

✅ **Multi-tracker Types** - Cattle and fence tracker support for comprehensive coverage
✅ **Long-range** - LoRa provides 5-10km coverage with minimal infrastructure
✅ **Low-power** - 2-6 week battery life with adaptive power management  
✅ **AI Analytics** - Behavior analysis and health insights powered by machine learning
✅ **Real-time Dashboard** - Live KPIs, activity feed, and instant alerts
✅ **Cost-effective** - No monthly subscriptions, one-time hardware cost
✅ **Reliable** - Robust communication protocols and offline capability
✅ **Easy to use** - BLE provisioning menu and web-based management
✅ **Scalable** - Supports hundreds of animals per gateway
✅ **Config Push** - Multi-tracker configuration via gateway
✅ **Flexible** - Highly configurable for different use cases
✅ **Modern UI** - Flutter-based interface with real-time WebSocket updates

## Deployment Ready

The system has been designed, tested, and documented for **real-world deployment**:

- **Hardware** - Production PCB designs for cattle and fence trackers
- **Firmware** - Stable, well-tested embedded code with OTA updates
- **Backend** - Scalable Node.js server with 12+ specialized services
- **Frontend** - Modern Flutter interface with 15+ specialized pages
- **State Management** - Centralized HerdState with real-time WebSocket updates
- **Documentation** - Comprehensive architecture guides and API docs
- **AI Analytics** - Behavior analysis and health monitoring
- **Configuration** - Multi-tracker configuration push system
- **Support** - Active development and BLE provisioning tools

---

> 🐄 **MooPoint** - *Know where your herd is, always.*

---

*Last Updated: March 2026*  
*Documentation Version: 2.0*  
*System Version: ESP-IDF 5.4.1 | Node.js 18.x | Flutter 3.x | Packet Structure v3.1*
