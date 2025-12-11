# Fall Detection Mobile App

Flutter mobile application for detecting falls using device accelerometer data.

## Features

- **Server Connection Tester** - Test server connectivity before running tests
- **Real-time Fall Detection** - Monitors accelerometer data continuously
- **Mock Testing** - Three test modes for development:
  - Random Data - Generates random accelerometer values
  - Fall Detected - Simulates a realistic fall pattern
  - No Fall - Simulates normal movement
- **Countdown Timer** - 3-second grace period after fall detection
- **Server Communication** - Sends data to server for analysis
- **Configurable** - Easy configuration for server URL and settings

## Prerequisites

- Flutter SDK (latest stable version)
- Android Studio or Xcode
- Physical device with accelerometer (emulator for UI testing only)

## Installation

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure server URL:**

   Edit `lib/config.dart` and update the server URL:
   ```dart
   static const String serverUrl = 'http://YOUR_SERVER_IP:3030';
   ```

   For development on the same network:
   ```dart
   static const String serverUrl = 'http://192.168.0.100:3030';
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── config.dart                    - App configuration (server URL, intervals, etc.)
├── main.dart                      - App entry point (23 lines)
├── models/
│   └── app_state.dart            - State management models and enums
├── screens/
│   └── home_screen.dart          - Main home screen with fall detection logic
├── services/
│   └── api_service.dart          - Server communication
├── utils/
│   └── mock_data_generator.dart  - Mock data generation for testing
└── widgets/
    ├── test_buttons.dart         - Test mode selection buttons
    ├── recording_view.dart       - Real-time recording UI
    ├── fall_detected_view.dart   - Fall alert UI
    ├── help_called_view.dart     - Help confirmation UI
    └── connection_tester.dart    - Server connection testing widget
```

## Configuration

All app settings are in `lib/config.dart`:

```dart
class AppConfig {
  // Server Configuration
  static const String serverUrl = 'http://192.168.0.100:3030';
  
  // App Settings
  static const int fallDetectionCountdown = 3;        // seconds
  static const int bufferDurationSeconds = 20;        // Keep 20 seconds of data
  static const int realTimeUpdateInterval = 5;        // Send data every 5 seconds
  static const int sensorFrequencyHz = 10;            // Sensor samples per second
  static int get maxDataPoints => 200;                // 20 seconds at 10Hz
  
  // Debug mode
  static const bool debugMode = false;
}
```

### Data Buffer Behavior

The app maintains a **rolling 20-second buffer** in memory:
- **Buffer Size**: 200 data points (20 seconds at 10 Hz sampling rate)
- **Update Cycle**: Every 5 seconds, sends the entire 20-second buffer to server
- **Rolling Window**: When buffer exceeds 200 points, oldest samples are automatically removed
- **Example**: At 25 seconds, the buffer contains data from second 5-25 (oldest 5 seconds removed)

This ensures:
- ✅ Always have context before a potential fall
- ✅ Efficient memory usage (fixed 200-point buffer)
- ✅ Continuous monitoring without data loss
- ✅ Server gets overlapping data for better analysis

## Usage

### Testing Server Connection

Before running any tests, verify the server is reachable:

1. **Open the app** on your device
2. **Look at the "Server Connection" card** at the top
3. **Tap "Test Connection"** button
4. **Check the status**:
   - ✅ Green: Server is running and reachable
   - ❌ Red: Connection failed - check server URL and network
   - ⏱️ Gray: Testing in progress

The connection tester will:
- Show the current server URL
- Test the `/health` endpoint
- Display success/error messages
- Timeout after 5 seconds if unreachable

### Testing Fall Detection

1. **Open the app** on your device
2. **Choose a test type:**
   - **Random Data** - Sends random accelerometer values (for testing server connection)
   - **Fall Detected** - Simulates fall pattern that should trigger detection
   - **No Fall** - Simulates normal movement that shouldn't trigger detection
3. **Wait for countdown** (3 seconds)
4. **Confirm wellbeing** or let timer expire to send data

### Real-time Monitoring

1. **Tap "Start Real-Time Recording"**
2. App will continuously collect accelerometer data
3. Data is automatically sent to server every 5 seconds
4. **Tap "Stop Recording"** when done

## How It Works

### Fall Detection Flow

```
1. User starts test or real-time monitoring
   ↓
2. App collects accelerometer data (X, Y, Z axes)
   ↓
3. Data formatted as CSV:
   Time, X-accel, Y-accel, Z-accel, Absolute-accel
   ↓
4. Data sent to server (POST /fall-detection/receive-data)
   ↓
5. Server analyzes data and detects falls
   ↓
6. Server sends Discord notification if fall detected
```

### Mock Data Generation

- **Random Data**: Normal walking pattern (X: 0.5-1.5, Y: 1.5-2.5, Z: 9.5-10.5 m/s²)
- **Fall Pattern**:
  - Phase 1 (0-0.8s): Standing
  - Phase 2 (0.8-1.5s): Free fall (low values)
  - Phase 3 (1.5-2.0s): Impact approaching
  - Phase 4 (2.0-2.3s): Impact (Z = 0.0)
  - Phase 5 (2.3-3.0s): Recovery
- **No Fall**: Stays within normal movement range

## API Communication

The app communicates with the server using the following endpoints:

### 1. Health Check

**Endpoint:** `GET /health`

**Purpose:** Test server connectivity and status

**Response:**
```json
{
  "status": "ok",
  "service": "Fall Detection Server",
  "timestamp": "2025-11-30T14:30:00.123Z"
}
```

### 2. Fall Detection Data

**Endpoint:** `POST /fall-detection/receive-data`

**Headers:** `Content-Type: text/csv`

**Body:**
```csv
"Time (s)","Acceleration x (m/s^2)","Acceleration y (m/s^2)","Acceleration z (m/s^2)","Absolute acceleration (m/s^2)","Gyroscope x (rad/s)","Gyroscope y (rad/s)","Gyroscope z (rad/s)","Gyroscope magnitude (rad/s)"
0.0,0.50,1.23,9.81,9.95,0.012,-0.034,0.008,0.037
0.1,0.52,1.25,9.80,9.94,0.015,-0.031,0.011,0.036
...
```

**Response:**
```json
{
  "message": "CSV data saved and analyzed successfully",
  "filename": "acceleration-data-2025-11-30T14-30-00-123Z.csv",
  "timestamp": "2025-11-30T14:30:00.123Z",
  "dataLength": 1234,
  "fallDetected": true
}
```

## Troubleshooting

### Cannot connect to server

1. Ensure server is running (`npm start` in server directory)
2. Check that device and server are on same network
3. Update server URL in `lib/config.dart` with correct IP
4. For Android: Check network permissions in `AndroidManifest.xml`
5. For iOS: Check `Info.plist` for network permissions

### Accelerometer not working

1. **Use a physical device** - emulators don't have real accelerometers
2. Check device permissions for sensors
3. Ensure app has necessary permissions

### Debug Mode

Set `debugMode = true` in `config.dart` to see detailed logging:
```dart
static const bool debugMode = true;
```

This will print:
- API requests and responses
- Data point counts
- Error messages

## Development

### Code Organization

The app follows a clean, modular architecture:

- **models/**: Data structures and state management
- **screens/**: Full-page views (home screen)
- **widgets/**: Reusable UI components (buttons, views)
- **services/**: External communication (API)
- **utils/**: Helper functions and utilities
- **config.dart**: Centralized configuration

### Best Practices

1. **Update server URL** before deploying
2. **Set debugMode = false** in production
3. **Test on physical device** with real accelerometer
4. **Ensure server is accessible** from device's network

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  sensors_plus: latest    # Accelerometer access
  http: latest            # HTTP requests
```

## Changes from v1.0

**v3.0 - Major Refactoring:**
- **Main entry point**: Reduced from 420 lines to 23 lines
- **Modular architecture**: Split into models, screens, widgets, services, utils
- **Separation of concerns**: UI widgets separated from business logic
- **Reusable components**: Created 4 separate widget files for different states
- **State management**: Dedicated models directory with AppState enum
- **Better maintainability**: Each file has single responsibility
- **Easier testing**: Components can be tested independently
- **Cleaner dependencies**: Simplified pubspec.yaml (from 92 to 24 lines)

**v2.0 - Initial Cleanup:**
- Extracted configuration to separate file
- Moved API calls to service layer
- Moved mock data generation to utility
- Removed debug print statements (now optional via config)
- Better code organization and separation of concerns
- Improved naming conventions (private methods with `_`)
- Added Material 3 design

## License

ISC
