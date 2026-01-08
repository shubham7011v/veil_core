import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/local_game_engine.dart';
import '../domain/models/offline_models.dart';

class LocalServerService {
  final LocalGameEngine _engine;
  HttpServer? _server;
  final Map<String, WebSocket> _clients = {};
  final _stateSubscriptions = <String, StreamSubscription>{};

  LocalServerService(this._engine);

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<void> start({int port = 8080}) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      print(
        'Local Server started on ${_server!.address.address}:${_server!.port}',
      );

      _server!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then(_handleNewConnection);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });

      // Listen to engine updates and broadcast
      _engine.stateStream.listen(_broadcastState);
    } catch (e) {
      print('Failed to start local server: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    for (var ws in _clients.values) {
      ws.close();
    }
    _clients.clear();
    for (var sub in _stateSubscriptions.values) {
      sub.cancel();
    }
    _stateSubscriptions.clear();
  }

  void _handleNewConnection(WebSocket ws) {
    String? clientId;

    ws.listen(
      (data) {
        try {
          final message = json.decode(data as String);
          final type = message['type'];
          final payload = message['data'];

          switch (type) {
            case 'AUTH':
              clientId =
                  payload['token'] ??
                  'guest_${DateTime.now().millisecondsSinceEpoch}';
              final name = payload['name'] ?? 'Player';
              _clients[clientId!] = ws;

              // 1. Send Auth OK
              _sendTo(clientId!, 'AUTH_OK', {'playerId': clientId});

              // 2. Add to engine
              _engine.addPlayer(clientId!, name);
              break;

            case 'START_GAME':
            case 'START_PRIVATE_GAME':
              _engine.start();
              break;

            case 'PLAY_CARDS':
              if (clientId == null) return;
              final cardIds = List<String>.from(payload['cardIds']);
              final rankName = payload['declaredRank'] as String;
              final rank = OfflineRank.values.firstWhere(
                (r) => r.name == rankName,
              );
              _engine.playCards(clientId!, cardIds, rank);
              break;

            case 'CHALLENGE':
              if (clientId == null) return;
              _engine.challenge(clientId!);
              break;

            case 'PASS':
              if (clientId == null) return;
              _engine.pass(clientId!);
              break;

            case 'LEAVE_ROOM':
              if (clientId != null) {
                _clients.remove(clientId);
                _engine.removePlayer(clientId!);
                ws.close();
              }
              break;
          }
        } catch (e) {
          print('Error handling local ws message: $e');
        }
      },
      onDone: () {
        if (clientId != null) {
          _clients.remove(clientId);
          _engine.removePlayer(clientId!);
        }
      },
      onError: (e) {
        print('Local WS Error: $e');
        if (clientId != null) {
          _clients.remove(clientId);
          _engine.removePlayer(clientId!);
        }
      },
    );
  }

  void _broadcastState(OfflineGameState state) {
    for (var entry in _clients.entries) {
      final cid = entry.key;
      final ws = entry.value;

      final publicData = state.toPublicJson();

      // Add private data for this specific client
      final player = state.playerMap[cid];
      if (player != null) {
        publicData['myHand'] = player.hand.map((c) => c.toJson()).toList();
      } else {
        publicData['myHand'] = [];
      }

      _sendRaw(ws, 'GAME_STATE', publicData);
    }
  }

  void _sendTo(String clientId, String type, dynamic data) {
    final ws = _clients[clientId];
    if (ws != null) {
      _sendRaw(ws, type, data);
    }
  }

  void _sendRaw(WebSocket ws, String type, dynamic data) {
    try {
      ws.add(json.encode({'type': type, 'data': data}));
    } catch (e) {
      print('Error sending to local client: $e');
    }
  }
}
