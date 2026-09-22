import '../l10n/localized_material.dart';

import '../services/usb_clock_service.dart';

/// USB 棋钟测试页面
class UsbClockTestScreen extends StatefulWidget {
  const UsbClockTestScreen({super.key});

  @override
  State<UsbClockTestScreen> createState() => _UsbClockTestScreenState();
}

class _UsbClockTestScreenState extends State<UsbClockTestScreen> {
  final _usbService = UsbClockService.instance;

  UsbClockButton? _lastButton;
  UsbClockConnectionState _connectionState = UsbClockConnectionState.disconnected;
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    // 监听按钮事件
    _usbService.buttonEvents.listen((event) {
      setState(() {
        _lastButton = event.button;
        _eventLog.insert(0, '${DateTime.now().toString().substring(11, 23)} - Button: ${event.button.name}');
        if (_eventLog.length > 20) {
          _eventLog.removeLast();
        }
      });
    });

    // 监听连接状态
    _usbService.connectionStateEvents.listen((state) {
      setState(() {
        _connectionState = state;
        _eventLog.insert(0, '${DateTime.now().toString().substring(11, 23)} - Connection: ${state.name}');
        if (_eventLog.length > 20) {
          _eventLog.removeLast();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USB Clock Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 连接状态
            Card(
              color: _connectionState == UsbClockConnectionState.connected
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Connection Status',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectionState.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _connectionState == UsbClockConnectionState.connected
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 最后按下的按钮
            Card(
              color: _lastButton == UsbClockButton.left
                  ? Colors.blue.shade100
                  : _lastButton == UsbClockButton.right
                      ? Colors.orange.shade100
                      : Colors.grey.shade200,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Last Button Pressed',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastButton?.name.toUpperCase() ?? 'NONE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _lastButton == UsbClockButton.left
                            ? Colors.blue
                            : _lastButton == UsbClockButton.right
                                ? Colors.orange
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 控制按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _usbService.setActiveSide(UsbClockButton.left),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Set LEFT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _usbService.setActiveSide(UsbClockButton.right),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Set RIGHT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 事件日志
            const Text(
              'Event Log',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: _eventLog.isEmpty
                    ? const Center(child: Text('No events yet'))
                    : ListView.builder(
                        itemCount: _eventLog.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 4.0,
                            ),
                            child: Text(
                              _eventLog[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
