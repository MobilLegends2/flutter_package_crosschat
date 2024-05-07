import 'package:flutter/material.dart';
import 'package:agora_uikit/agora_uikit.dart';

class VoiceCallScreen extends StatefulWidget {
  final String conversationId;

  VoiceCallScreen({required this.conversationId});

  @override
  _VoiceCallScreenState createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  late AgoraClient client;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    client = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: "d79ab7f5156d4cd1a683fe6e24506a6f",
        channelName: widget.conversationId,
      ),
      enabledPermission: [
        Permission.microphone,
      ],
    );
    initAgora();
  }

  void initAgora() async {
    await client.initialize();
    setState(() {});
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      // client.controller.muteLocalAudioStream(_muted);
    });
  }

  void _hangUp() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (client == null || !client.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading...'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Call'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    FloatingActionButton(
                      onPressed: _hangUp,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.call_end),
                    ),
                    FloatingActionButton(
                      onPressed: _toggleMute,
                      child: Icon(_muted ? Icons.mic_off : Icons.mic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
