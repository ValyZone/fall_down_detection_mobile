import 'dart:math';

/// Generates mock accelerometer and gyroscope data for testing
class MockDataGenerator {
  static final Random _random = Random();

  /// Generates random accelerometer + gyroscope data (normal movement)
  static String generateRandomData(double time) {
    final ax = (0.5 + _random.nextDouble()).toStringAsFixed(2);
    final ay = (1.5 + _random.nextDouble()).toStringAsFixed(2);
    final az = (9.5 + _random.nextDouble()).toStringAsFixed(2);
    final absAcc = _calculateAbsoluteAcceleration(ax, ay, az);
    
    // Normal gyro: small random rotations
    final gx = (_random.nextDouble() * 0.1 - 0.05).toStringAsFixed(3);
    final gy = (_random.nextDouble() * 0.1 - 0.05).toStringAsFixed(3);
    final gz = (_random.nextDouble() * 0.1 - 0.05).toStringAsFixed(3);
    final gyroMag = _calculateGyroscopeMagnitude(gx, gy, gz);
    
    return '$time\t$ax\t$ay\t$az\t$absAcc\t$gx\t$gy\t$gz\t$gyroMag';
  }

  /// Generates mock data that simulates a fall event
  static String generateFallData(double time) {
    String ax, ay, az, gx, gy, gz;

    if (time <= 0.8) {
      // Normal standing position
      ax = (0.5 + _random.nextDouble() * 0.5).toStringAsFixed(2);
      ay = (1.0 + _random.nextDouble() * 0.5).toStringAsFixed(2);
      az = (9.6 + _random.nextDouble() * 0.4).toStringAsFixed(2);
      // Minimal rotation
      gx = (_random.nextDouble() * 0.05).toStringAsFixed(3);
      gy = (_random.nextDouble() * 0.05).toStringAsFixed(3);
      gz = (_random.nextDouble() * 0.05).toStringAsFixed(3);
    } else if (time <= 1.5) {
      // Free fall - high rotation as person tumbles
      ax = (0.3 + _random.nextDouble() * 0.4).toStringAsFixed(2);
      ay = (0.8 + _random.nextDouble() * 0.6).toStringAsFixed(2);
      az = (0.1 + _random.nextDouble() * 0.3).toStringAsFixed(2);
      // Significant rotation during fall
      gx = (1.5 + _random.nextDouble() * 2.0).toStringAsFixed(3);
      gy = (1.0 + _random.nextDouble() * 1.5).toStringAsFixed(3);
      gz = (0.8 + _random.nextDouble() * 1.2).toStringAsFixed(3);
    } else if (time <= 2.0) {
      // Near-zero (approaching impact)
      ax = (0.1 + _random.nextDouble() * 0.2).toStringAsFixed(2);
      ay = (0.2 + _random.nextDouble() * 0.3).toStringAsFixed(2);
      az = (0.0 + _random.nextDouble() * 0.1).toStringAsFixed(2);
      // Rotation continuing
      gx = (1.0 + _random.nextDouble() * 1.5).toStringAsFixed(3);
      gy = (0.8 + _random.nextDouble() * 1.0).toStringAsFixed(3);
      gz = (0.5 + _random.nextDouble() * 0.8).toStringAsFixed(3);
    } else if (time <= 2.3) {
      // Impact (Z-axis = 0.0)
      ax = (0.1 + _random.nextDouble() * 0.3).toStringAsFixed(2);
      ay = (0.3 + _random.nextDouble() * 0.4).toStringAsFixed(2);
      az = '0.0';
      // Sudden stop in rotation at impact
      gx = (0.2 + _random.nextDouble() * 0.3).toStringAsFixed(3);
      gy = (0.1 + _random.nextDouble() * 0.2).toStringAsFixed(3);
      gz = (0.0 + _random.nextDouble() * 0.1).toStringAsFixed(3);
    } else {
      // Post-fall recovery
      ax = (0.6 + _random.nextDouble() * 0.6).toStringAsFixed(2);
      ay = (1.0 + _random.nextDouble() * 0.8).toStringAsFixed(2);
      az = (8.0 + _random.nextDouble() * 2.0).toStringAsFixed(2);
      // Minimal rotation when lying down
      gx = (_random.nextDouble() * 0.08).toStringAsFixed(3);
      gy = (_random.nextDouble() * 0.08).toStringAsFixed(3);
      gz = (_random.nextDouble() * 0.05).toStringAsFixed(3);
    }

    final absAcc = _calculateAbsoluteAcceleration(ax, ay, az);
    final gyroMag = _calculateGyroscopeMagnitude(gx, gy, gz);
    return '$time\t$ax\t$ay\t$az\t$absAcc\t$gx\t$gy\t$gz\t$gyroMag';
  }

  /// Generates mock data that should NOT trigger fall detection
  static String generateNoFallData(double time) {
    final ax = (0.6 + _random.nextDouble() * 0.8).toStringAsFixed(2);
    final ay = (1.0 + _random.nextDouble() * 1.0).toStringAsFixed(2);
    final az = (8.5 + _random.nextDouble() * 2.0).toStringAsFixed(2);
    final absAcc = _calculateAbsoluteAcceleration(ax, ay, az);
    
    // Normal walking gyro: small rotations
    final gx = (_random.nextDouble() * 0.15 - 0.075).toStringAsFixed(3);
    final gy = (_random.nextDouble() * 0.15 - 0.075).toStringAsFixed(3);
    final gz = (_random.nextDouble() * 0.12 - 0.06).toStringAsFixed(3);
    final gyroMag = _calculateGyroscopeMagnitude(gx, gy, gz);
    
    return '$time\t$ax\t$ay\t$az\t$absAcc\t$gx\t$gy\t$gz\t$gyroMag';
  }

  /// Calculates absolute acceleration from x, y, z components
  static String _calculateAbsoluteAcceleration(
      String ax, String ay, String az) {
    final x = double.parse(ax);
    final y = double.parse(ay);
    final z = double.parse(az);
    return sqrt(x * x + y * y + z * z).toStringAsFixed(2);
  }

  /// Calculates gyroscope magnitude from x, y, z components
  static String _calculateGyroscopeMagnitude(
      String gx, String gy, String gz) {
    final x = double.parse(gx);
    final y = double.parse(gy);
    final z = double.parse(gz);
    return sqrt(x * x + y * y + z * z).toStringAsFixed(3);
  }
}
