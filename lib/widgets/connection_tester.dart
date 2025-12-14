import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config.dart';

class ConnectionTester extends StatefulWidget {
  const ConnectionTester({super.key});

  @override
  State<ConnectionTester> createState() => _ConnectionTesterState();
}

class _ConnectionTesterState extends State<ConnectionTester> {
  bool _testing = false;
  String? _statusMessage;
  bool? _isConnected;

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _statusMessage = 'Testing connection...';
      _isConnected = null;
    });

    final result = await ApiService.checkServerHealth();

    setState(() {
      _testing = false;
      _isConnected = result['success'] as bool;
      _statusMessage = result['message'] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.router, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Server Connection',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConfig.serverUrl,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_find),
                label: Text(_testing ? 'Testing...' : 'Test Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isConnected == true
                      ? Colors.green[50]
                      : _isConnected == false
                          ? Colors.red[50]
                          : Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isConnected == true
                        ? Colors.green
                        : _isConnected == false
                            ? Colors.red
                            : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isConnected == true
                          ? Icons.check_circle
                          : _isConnected == false
                              ? Icons.error
                              : Icons.info,
                      color: _isConnected == true
                          ? Colors.green
                          : _isConnected == false
                              ? Colors.red
                              : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 14,
                          color: _isConnected == true
                              ? Colors.green[900]
                              : _isConnected == false
                                  ? Colors.red[900]
                                  : Colors.grey[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
