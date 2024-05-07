import 'package:flutter/material.dart';
import 'package:agora_uikit/agora_uikit.dart';

class VideoCallScreen extends StatefulWidget {
  final String conversationId;

  VideoCallScreen({required this.conversationId});

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late AgoraClient client;

  @override
  void initState() {
    super.initState();
    // Initialize AgoraClient with the provided conversationId
    client = AgoraClient(
      agoraConnectionData: AgoraConnectionData(
        appId: "d79ab7f5156d4cd1a683fe6e24506a6f",
        channelName: widget.conversationId,
      ),
      enabledPermission: [
        Permission.camera,
        Permission.microphone,
      ],
    );
    // Initialize AgoraClient after initState completes
    initAgora();
  }

  void initAgora() async {
    await client.initialize();
    // Set state to rebuild the widget with initialized client
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Check if client is initialized before building the UI
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

    // If client is initialized, build the video call UI
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            AgoraVideoViewer(client: client),
            AgoraVideoButtons(client: client),
          ],
        ),
      ),
    );
  }
}
