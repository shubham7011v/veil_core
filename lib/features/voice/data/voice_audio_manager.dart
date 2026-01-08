import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/engine/engine.dart';

class VoiceAudioManager {
  // Singleton
  static final VoiceAudioManager _instance = VoiceAudioManager._internal();
  factory VoiceAudioManager() => _instance;
  VoiceAudioManager._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  VoiceSessionHandler? _signaling;
  Function(String message, dynamic error)? _onError;

  bool _isMicEnabled = true;

  Future<void> initialize(
    VoiceSessionHandler signaling, {
    Function(String message, dynamic error)? onError,
  }) async {
    _onError = onError;
    try {
      // Ensure any existing resources are cleaned up to prevent leaks
      await dispose();
      _isMicEnabled = true; // Reset mic state for new session

      _signaling = signaling;
      await _requestPermissions();
      await _createPeerConnection();
      await _getUserMedia();
      await _connect();
    } catch (e) {
      debugPrint("VoiceAudioManager initialization failed: $e");
      _onError?.call("Voice initialization failed", e);
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _createPeerConnection() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(config, {});

    _peerConnection!.onIceCandidate = (candidate) {
      try {
        if (_signaling != null) {
          _signaling!.sendVoiceICE({
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          });
        }
      } catch (e) {
        debugPrint("Error sending IceCandidate: $e");
      }
    };

    _peerConnection!.onTrack = (event) {
      try {
        if (event.track.kind == 'audio') {
          event.streams[0].getAudioTracks()[0].enabled = true;
        }
      } catch (e) {
        debugPrint("Error handling remote track: $e");
      }
    };
  }

  Future<void> _getUserMedia() async {
    final mediaConstraints = {'audio': true, 'video': false};

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _localStream!.getAudioTracks()[0].enabled = _isMicEnabled;

      _peerConnection!.addTrack(
        _localStream!.getAudioTracks()[0],
        _localStream!,
      );
    } catch (e) {
      debugPrint("Error getting user media: $e");
    }
  }

  Future<void> _connect() async {
    if (_peerConnection == null) return;

    // Create Offer
    RTCSessionDescription offer = await _peerConnection!.createOffer({});
    await _peerConnection!.setLocalDescription(offer);

    // Send Offer
    if (_signaling != null) {
      _signaling!.sendVoiceSDP({'sdp': offer.sdp, 'type': offer.type});
    }
  }

  Future<void> handleOffer(Map<String, dynamic> data) async {
    // We are the offerer usually, but if server re-negotiates we might get offer.
    // But primarily we get ANSWER.
    // If we get an OFFER, we answer.
    final sdp = RTCSessionDescription(data['sdp'], data['type']);
    await _peerConnection!.setRemoteDescription(sdp);
    final answer = await _peerConnection!.createAnswer({});
    await _peerConnection!.setLocalDescription(answer);
    _signaling!.sendVoiceSDP({'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> handleAnswer(Map<String, dynamic> data) async {
    final sdp = RTCSessionDescription(data['sdp'], data['type']);
    await _peerConnection!.setRemoteDescription(sdp);
  }

  Future<void> handleCandidate(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      );
      await _peerConnection?.addCandidate(candidate);
    } catch (e) {
      debugPrint("Error handling candidate: $e");
    }
  }

  void toggleMic() {
    if (_localStream != null) {
      _isMicEnabled = !_isMicEnabled;
      _localStream!.getAudioTracks()[0].enabled = _isMicEnabled;
    }
  }

  Future<void> dispose() async {
    _isMicEnabled = false; // Disable mic logic

    // Stop tracks first
    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        try {
          track.stop();
        } catch (e) {
          debugPrint("Error stopping track: $e");
        }
      }
    }

    try {
      await _localStream?.dispose();
    } catch (e) {
      debugPrint("Error disposing local stream: $e");
    }

    try {
      await _peerConnection?.close(); // use close() before dispose()
      await _peerConnection?.dispose();
    } catch (e) {
      debugPrint("Error disposing peer connection: $e");
    }

    _localStream = null;
    _peerConnection = null;
  }
}
