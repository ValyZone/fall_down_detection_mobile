# Fall Detection Mobile App

Flutter mobile application that detects motorcycle crashes using accelerometer and gyroscope sensors.

## How It Works

The app uses a **3-State Finite State Machine (FSM)** to detect crashes:

```
1. MONITORING → Continuously records sensor data in a circular buffer
   ↓ (Impact detected: SVM > 3.5g)

2. STATIONARITY CHECK → Waits for device to become motionless
   ↓ (Device becomes still: low variance + low rotation)

3. UPLOAD → Sends buffer data to server for analysis
   ↓ (Server analyzes with 3-phase algorithm)

→ Back to MONITORING
```

### Detection Criteria

**Impact Detection:**
- Sensor Vector Magnitude (SVM) exceeds **3.5g** (34.335 m/s²)
- Triggers transition to stationarity check state

**Stationarity Detection:**
- Accelerometer standard deviation < **0.5 m/s²** (over 1 second)
- AND gyroscope magnitude < **0.1 rad/s**
- Confirms device is at rest after crash

**Result:**
- If both conditions met → uploads data to server
- Server performs sophisticated 3-phase crash analysis
- Discord notification sent if crash confirmed

## Setup

### Prerequisites
- Flutter SDK (latest stable)
- Physical device with sensors (emulator won't work)
- Backend server running

### Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure server URL:**

   Edit `lib/config.dart`:
   ```dart
   static const String serverUrl = 'http://YOUR_SERVER_IP:3030';
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Configuration

All settings in `lib/config.dart`:

```dart
// Server
static const String serverUrl = 'http://192.168.0.100:3030';

// Detection Parameters
static const int impactWindowSeconds = 10;          // Time to detect stationarity
static const int postImpactCollectionSeconds = 5;   // Extra data after stationarity
static const double impactThreshold = 34.335;       // 3.5g in m/s²
static const double varianceThreshold = 0.5;        // For motionless detection
static const double gyroscopeThreshold = 0.1;       // rad/s for rotation
static const int bufferCapacity = 1000;             // ~20s at 50Hz

// Debug
static const bool debugMode = true;  // Set false in production
```

## Usage

### Test Server Connection
1. Open app
2. Tap **"Test Connection"** in the Server Connection card
3. Verify green checkmark appears

### Real-Time Monitoring
1. Tap **"Start Real-Time Recording"**
2. App monitors sensors continuously
3. On impact → checks for stationarity → uploads if still
4. Tap **"Stop Recording"** when done

### Mock Testing
Use the test buttons to send pre-generated data:
- **Positive Alarm** - Simulated crash data (should detect)
- **False Positive Alarm** - Non-crash data (should not detect)

## Architecture

```
lib/
├── config.dart                        # All configuration
├── main.dart                          # App entry point
├── models/
│   ├── fsm_state.dart                # FSM states (Monitoring/StationarityCheck/Upload)
│   ├── state_transition_event.dart   # FSM transition events
│   ├── sensor_data.dart              # Sensor reading model
│   └── ring_buffer.dart              # Circular buffer implementation
├── services/
│   ├── fall_detector_service.dart    # FSM orchestration
│   ├── sensor_service.dart           # Sensor data collection
│   └── api_service.dart              # Server communication
├── screens/
│   └── home_screen.dart              # Main UI
├── widgets/
│   ├── recording_view.dart           # Recording state UI
│   ├── connection_tester.dart        # Server connection widget
│   └── test_buttons.dart             # Mock test buttons
└── utils/
    ├── sensor_math.dart              # SVM calculations
    └── mock_data_generator.dart      # Test data generation
```

## Data Flow

```
Sensors (50 Hz)
     ↓
SensorService (circular buffer, impact/stationarity detection)
     ↓
FallDetectorService (FSM state management)
     ↓
ApiService (CSV upload to server)
     ↓
Server (3-phase crash analysis)
     ↓
Discord Notification (if crash confirmed)
```

## Circular Buffer

- **Capacity:** 1000 samples (~20 seconds at 50Hz)
- **Behavior:** Oldest data removed when full
- **Purpose:** Always have crash context when upload triggered
- **Upload:** Freezes entire buffer and sends to server

## API Communication

### POST /fall-detection/receive-data
Sends CSV data to server for analysis.

**Headers:** `Content-Type: text/csv`

**Body Format:**
```csv
"Time (s)","Acceleration x (m/s^2)","Acceleration y (m/s^2)","Acceleration z (m/s^2)","Absolute acceleration (m/s^2)","Gyroscope x (rad/s)","Gyroscope y (rad/s)","Gyroscope z (rad/s)","Gyroscope magnitude (rad/s)"
0.0,0.50,1.23,9.81,9.95,0.012,-0.034,0.008,0.037
```

**Response:**
```json
{
  "fallDetected": true,
  "filename": "acceleration-data-2025-12-14T10-30-00-000Z.csv",
  "timestamp": "2025-12-14T10:30:00.000Z"
}
```

### GET /health
Health check endpoint.

### GET /mock-data/{type}
Fetches mock data (`positive` or `false-positive`).

## Troubleshooting

**Can't connect to server:**
- Verify server is running
- Check device and server on same network
- Update `serverUrl` in config.dart with correct IP

**Sensors not working:**
- Must use physical device (emulator has no real sensors)
- Check app permissions

**Debug logging:**
Set `debugMode = true` in config.dart to see detailed logs.

## Dependencies

```yaml
dependencies:
  sensors_plus: ^6.0.1    # Accelerometer + gyroscope
  http: ^1.2.2            # HTTP requests
```

## License

ISC
