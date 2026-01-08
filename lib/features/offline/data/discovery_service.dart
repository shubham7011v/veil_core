import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveryService {
  static const int _port = 44444; // Discovery port
  static const String _broadcastMsg = 'VEIL_HOST';

  RawDatagramSocket? _socket;
  Timer? _broadcastTimer;
  final _discoveredHostsController = StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get discoveredHosts => _discoveredHostsController.stream;
  final Set<String> _hosts = {};

  Future<void> startBroadcasting(String hostName) async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.broadcastEnabled = true;

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final payload = json.encode({
        'msg': _broadcastMsg,
        'name': hostName,
        'port': 8080, // Default game server port
      });
      final data = utf8.encode(payload);
      _socket!.send(data, InternetAddress('255.255.255.255'), _port);
    });
  }

  Future<void> startListening() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = _socket!.receive();
        if (dg != null) {
          try {
            final data = utf8.decode(dg.data);
            final payload = json.decode(data);
            if (payload['msg'] == _broadcastMsg) {
              final hostIp = dg.address.address;
              final name = payload['name'] ?? 'Unknown Host';
              final hostInfo = '$name|$hostIp|${payload['port']}';

              if (!_hosts.contains(hostInfo)) {
                _hosts.add(hostInfo);
                _discoveredHostsController.add(Set.from(_hosts));
              }
            }
          } catch (e) {
            // Ignore malformed packets
          }
        }
      }
    });
  }

  void stop() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _hosts.clear();
  }

  Future<String?> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
