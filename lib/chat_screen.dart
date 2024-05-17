import 'dart:core';

import 'package:crosschatsdk/recentchatssdk.dart';
import 'package:crosschatsdk/videocall.dart';
import 'package:crosschatsdk/voicecall.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:path/path.dart' as path;
import 'package:auto_scroll/auto_scroll.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String senderName;

  final _appID =
      "d79ab7f5156d4cd1a683fe6e24506a6f"; // Replace with your Agora App ID

  ChatScreen(
      {required this.conversationId,
      required this.senderName,
      required String currentUserId,
      required String clickedUserId,
      required bool isImage,
      required String senderImageUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController _textEditingController = TextEditingController();
  bool _isRecording = false;
  String? filePath;
  bool _isComposing = false;
  bool _isLongPressing = false;
  bool isImage = false;
  int? selectedMessageIndex;
  String? selectedEmoji; // Variable to store the selected emoji
  List<dynamic> messages = [];
  String currentUserId = 'participant1';
  Map<String, int> lastMessageIndexMap = {}; // Declare lastMessageIndexMap here

  String _filePath = '';
  late IO.Socket socket;
  late AutoScrollController _autoScrollerController;
  final ScrollController _scrollController =
      ScrollController(); // Add ScrollController

  // Define the list of reactions
  List<String> reactions = [
    '😊',
    '😂',
    '😍',
    '👍',
    '👏',
    '❤️',
    '🔥',
    '🎉',
    '🤔'
  ];

  List<dynamic> previousMessages = [];

  get Record => false;
  Future<void> fetchLastMessage() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:8080/conversations/${widget.conversationId}/messages?last=true'),
      headers: {
        'x-secret-key':
            '80e01067bd82ddb68ce5091bd07c8e1946ef4626', // Include the API key in the request headers
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      List<dynamic> lastMessage = responseData['messages'] ?? [];
      setState(() {
        messages =
            lastMessage; // Update the messages with the last message only
      });
    } else {
      throw Exception('Failed to load last message');
    }
  }

  @override
  void initState() {
    super.initState();
    connectToSocket();
    _textEditingController = TextEditingController();
    // Fetch the last messages when the screen initializes
    fetchLastMessages().then((_) {
      // Scroll to the bottom when the last messages are fetched
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
    _autoScrollerController = AutoScrollController();
    // Fetch previous sent messages when the screen initializes
    fetchPreviousSentMessages();
    // Add a listener to detect when the user scrolls to the top of the list
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels == 0) {
          // Start fetching previous messages when scrolled to the top
          fetchPreviousMessages();
        }
      }
    });
  }

  Future<void> fetchPreviousSentMessages() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:8080/conversations/${widget.conversationId}/messages?sender=${widget.senderName}'),
      headers: {
        'x-secret-key':
            '80e01067bd82ddb68ce5091bd07c8e1946ef4626', // Include the API key in the request headers
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      List<dynamic> previousSentMessages = responseData['messages'] ?? [];
      setState(() {
        messages.addAll(
            previousSentMessages); // Add previous sent messages to the list of messages
      });
    } else {
      throw Exception('Failed to load previous messages');
    }
  }

  Future<void> fetchLastMessages() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:8080/conversations/${widget.conversationId}/messages?last=true'),
      headers: {
        'x-secret-key':
            '80e01067bd82ddb68ce5091bd07c8e1946ef4626', // Include the API key in the request headers
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      List<dynamic> lastMessage = responseData['messages'] ?? [];
      setState(() {
        messages =
            lastMessage; // Update the messages with the last message only
      });
    } else {
      throw Exception('Failed to load last messages');
    }
  }

  // Méthode pour charger les messages précédents
  Future<void> fetchPreviousMessages() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:/conversations/${widget.conversationId}/messages?before=${messages.last['timestamp']}'),
      headers: {
        'x-secret-key':
            '80e01067bd82ddb68ce5091bd07c8e1946ef4626', // Include the API key in the request headers
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      List<dynamic> fetchedPreviousMessages = responseData['messages'] ?? [];
      setState(() {
        previousMessages = fetchedPreviousMessages;
        messages.addAll(
            previousMessages); // Ajouter les messages précédents à la liste de messages
      });
    } else {
      throw Exception('Failed to load previous messages');
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    _scrollController.dispose(); // Dispose of ScrollController
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchLastMessage();
  }

  Future<void> fetchMessages() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:8080/conversations/${widget.conversationId}/messages'),
      headers: {
        'x-secret-key':
            '80e01067bd82ddb68ce5091bd07c8e1946ef4626', // Include the API key in the request headers
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      setState(() {
        messages = responseData['messages'] ?? []; // Added null check here
      });
    } else {
      throw Exception('Failed to load messages');
    }
  }

  void connectToSocket() {
    socket = IO.io('http://10.0.2.2:8080', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket.io server');
      // Join conversation-specific socket room
      socket.emit('join_conversation', widget.conversationId);
    });

    socket.onDisconnect((_) {
      print('Disconnected from socket.io server');
    });

    // Use dynamic event name based on conversation ID
    socket.on('new_message_${widget.conversationId}', (data) {
      print('New message received: $data');
      setState(() {
        messages.add(data);
      });
      _scrollToBottom(); // Scroll to bottom when new message is received
      fetchMessages();
    });
  }

  void sendMessage(String message, String t) {
    socket.emit('new_message_${widget.conversationId}', {
      'sender': currentUserId,
      'content': message,
      'conversation': widget.conversationId,
      'type': t
    });
    _scrollToBottom();
  }

  Future<String?> sendAttachment(String filePath) async {
    String fileName = path.basename(filePath);
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'http://10.0.2.2:8080/conversations/${widget.conversationId}/attachments'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', filePath,
        filename: fileName));

    try {
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 201) {
        // Lire la réponse HTTP pour extraire l'URL de l'attachement
        String responseString = await response.stream.bytesToString();
        // Convertir la réponse en JSON
        Map<String, dynamic> jsonResponse = json.decode(responseString);
        // Récupérer l'URL de l'attachement à partir de la réponse JSON
        String? attachmentUrl = jsonResponse['url'];
        sendMessage(attachmentUrl.toString(), "attachment");
        print('Attachment sent successfully. URL: $attachmentUrl');
        _scrollToBottom();
        fetchMessages();
        return attachmentUrl;
      } else {
        // Erreur lors de l'envoi de l'attachement
        print('Failed to send attachment. Status code: ${response.statusCode}');
        return null;
      }
    } catch (error) {
      // Gérer les erreurs qui se produisent pendant la requête HTTP
      print('Error sending attachment: $error');
      return null;
    }
  }

  // Function to send a POST request to add emoji to a message
  Future<void> addEmojiToMessage(String messageId, String emoji) async {
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8080/messages/$messageId/emoji'),
      body: json.encode({'emoji': emoji}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      // Emoji added successfully, you can update UI or perform any necessary actions
      print('Emoji added successfully');
    } else {
      // Handle error
      print('Failed to add emoji');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _displayAttachments() async {
    try {
      final response = await http.get(Uri.parse(
          'http://10.0.2.2:8080/conversations/${widget.conversationId}/attachments'));

      if (response.statusCode == 200) {
        List<dynamic> attachments = json.decode(response.body);
        // Update UI to display attachments
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Attachments'),
              content: SingleChildScrollView(
                child: Column(
                  children: attachments.map((attachment) {
                    return Image.network(
                      attachment[
                          'url'], // Assuming 'url' field contains attachment URL
                      width: 200, // Adjust width as needed
                      height: 200, // Adjust height as needed
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      } else {
        throw Exception('Failed to load attachments');
      }
    } catch (error) {
      print('Error fetching attachments: $error');
      // Handle error
    }
  }

  Widget _buildMessage({
    required String senderId,
    required String currentUserId,
    required String avatarUrl,
    required String message,
    required String time,
    required MessageType messageType,
    required String messageId,
    required List<String> emojis,
    required bool isLastMessageFromUser,
  }) {
    bool isMe = senderId == currentUserId;
    bool showAvatar = !isMe && isLastMessageFromUser;
    Color backgroundColor = isMe
        ? Color.fromARGB(255, 40, 46, 51)
        : Color.fromARGB(255, 91, 109, 222);
    Color textColor = isMe ? Colors.white : Colors.black;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Color.fromARGB(255, 2, 2, 2), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  avatarUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                // Handle tapping on a message
              },
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isMe ? 20 : 0),
                    topRight: Radius.circular(isMe ? 0 : 20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromARGB(255, 59, 39, 69).withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (messageType == MessageType.text)
                        Text(
                          message,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                      if (messageType == MessageType.attachment)
                        Image.network(
                          message,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      SizedBox(height: 5),
                      if (emojis.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: emojis.map((emoji) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  emoji,
                                  style: TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      SizedBox(height: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!isMe)
            GestureDetector(
              onTap: () {
                _showReactionsDialog(messageId);
              },
              child: Container(
                margin: EdgeInsets.only(left: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.fromARGB(255, 245, 245, 245).withOpacity(0.2),
                ),
                child: Icon(
                  Icons.add_reaction,
                  color: const Color.fromARGB(255, 9, 9, 9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Color.fromARGB(139, 152, 78, 186)!, // Light grey border
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.photo),
              onPressed: _selectAttachment,
              color: const Color.fromARGB(
                  255, 91, 92, 93), // Blue color for the photo icon
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _textEditingController,
                  onChanged: (String text) {
                    setState(() {
                      _isComposing = text.isNotEmpty;
                    });
                  },
                  onSubmitted: _isComposing ? _handleSubmitted : null,
                  style: TextStyle(color: Colors.black87), // Black text color
                  decoration: InputDecoration.collapsed(
                    hintText: 'Send a message...',
                    hintStyle: TextStyle(
                        color: const Color.fromARGB(
                            255, 57, 56, 56)), // Light grey hint text
                  ),
                ),
              ),
            ),
            InkWell(
              // InkWell for send
              onTap: () {
                String message = _textEditingController.text;
                if (message.isNotEmpty) {
                  sendMessage(message, "text");
                  _textEditingController.clear();
                  _scrollToBottom();
                  fetchMessages();
                }
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      Color.fromARGB(85, 25, 22, 103), // Blue background color
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.white, // White icon color
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.mic),
              onPressed: () async {
                if (!_isRecording) {
                  // Start recording
                  bool? hasPermission = await Record.hasPermission();
                  if (hasPermission != null && hasPermission) {
                    String? path = await Record.start(
                      path: 'audio.m4a', // Specify the file path
                    );
                    if (path != null) {
                      setState(() {
                        _isRecording = true;
                      });
                      _showRecordingDialog(
                          context); // Show the recording dialog
                    }
                  }
                } else {
                  // Stop recording
                  bool stopped = await Record.stop();
                  if (stopped) {
                    setState(() {
                      _isRecording = false;
                    });
                    Navigator.pop(context); // Close the recording dialog
                    // Handle sending the recorded audio message
                  }
                }
              },

              color: _isRecording
                  ? Colors.red
                  : const Color.fromARGB(
                      255, 47, 46, 46), // Red for recording, grey for default
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmitted(String text) {
    _textEditingController.clear();
    setState(() {
      _isComposing = false;
    });
    // Implement functionality to send messages
  }

  // Function to show reactions dialog
  void _showReactionsDialog(String messageId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Reaction'),
          content: SingleChildScrollView(
            child: Column(
              children: List.generate(
                reactions.length,
                (index) {
                  return ListTile(
                    title: Text(reactions[index]),
                    onTap: () {
                      // Call function to add emoji to the message
                      addEmojiToMessage(messageId, reactions[index]);
                      Navigator.pop(context); // Close the dialog
                      fetchMessages();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // Function to add a reaction
  void _addReaction(String reaction) {
    setState(() {
      if (selectedMessageIndex != null &&
          selectedMessageIndex! < messages.length) {
        // Add the reaction to the selected message
        messages[selectedMessageIndex!].reactions.add(reaction);
        print("ssssssssss");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String avatarUrl =
        "https://www.google.com/url?sa=i&url=https%3A%2F%2Fvariety.com%2F2022%2Ffilm%2Fnews%2Favatar-disney-plus-removal-1235348400%2F&psig=AOvVaw09ohfGgt-FHYmZzlH402ZG&ust=1715201232481000&source=images&cd=vfe&opi=89978449&ved=0CBEQjRxqFwoTCKCUkNK0_IUDFQAAAAAdAAAAABAE";
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          elevation: 0, // Remove the default shadow
          backgroundColor: Colors.transparent, // Make the app bar transparent
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(134, 77, 17, 174), // Top color
                  Color.fromARGB(255, 169, 178, 185), // Bottom color
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20), // Adjust the radius as needed
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                widget.senderName,
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Title text color
                ),
              ),
              SizedBox(width: 8), // Add some spacing between name and avatar
              CircleAvatar(
                backgroundImage: NetworkImage(
                    avatarUrl), // Replace currentUserImageUrl with the URL of the current user's profile picture
                radius: 12, // Adjust the size as needed
              ),
              SizedBox(
                  width:
                      8), // Add some spacing between avatar and connection indicator
              Icon(
                Icons.circle, // Add the connection indicator icon here
                color: Color.fromARGB(
                    255, 21, 246, 0), // Change color based on connection status
                size: 12, // Adjust the size as needed
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.video_call),
              onPressed: () {
                // Navigate to the video call screen or trigger video call action
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => VideoCallScreen(
                            conversationId: '',
                          )), // Replace VideoCallScreen() with your actual video call screen
                );
              },
              color: const Color.fromARGB(255, 11, 11, 11), // Icon color
            ),
            IconButton(
              icon: Icon(Icons.call),
              onPressed: () {
                // Navigate to the voice call screen or trigger voice call action
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => VoiceCallScreen(
                            conversationId: '',
                          )), // Replace VoiceCallScreen() with your actual voice call screen
                );
              },

              color: const Color.fromARGB(255, 0, 0, 0), // Icon color
            ),
            PopupMenuButton(
              itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                PopupMenuItem(
                  child: Text('Attachments'),
                  onTap: _displayAttachments,
                ),
                PopupMenuItem(
                  child: Text('Mute notifications'),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AutoScroller(
              controller: _autoScrollerController, // Assign the controller
              lengthIdentifier: messages.length,
              anchorThreshold: 24,
              startAnchored: false,
              builder: (context, controller) {
                // Reverse the order of messages
                List<dynamic> reversedMessages = List.from(messages.reversed);
                return ListView.builder(
                  reverse: true, // Set reverse to true for auto-scrolling
                  itemCount: reversedMessages.length,
                  itemBuilder: (context, index) {
                    final message = reversedMessages[index];
                    List<String> emojis = message['emojis'] != null
                        ? List<String>.from(message['emojis'])
                        : [];
                    MessageType messageType = message['type'] == 'text'
                        ? MessageType.text
                        : MessageType.attachment;
                    // Determine if it's the last message from another user
                    bool isLastMessageFromUser =
                        lastMessageIndexMap[message['sender']] == index;
                    return _buildMessage(
                      senderId: message['sender'],
                      currentUserId: currentUserId,
                      avatarUrl: 'assets/images/avatar.png',
                      message: message['content'] ?? '',
                      time: message['timestamp'] ?? '',
                      messageType: messageType,
                      messageId: message['_id'] ?? '',
                      emojis: emojis,
                      isLastMessageFromUser: isLastMessageFromUser,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
          // Display the selected emoji
          if (selectedEmoji != null)
            Container(
              padding: EdgeInsets.all(8.0),
              alignment: Alignment.center,
              child: Text(
                selectedEmoji!,
                style: TextStyle(fontSize: 24.0),
              ),
            ),
        ],
      ),
    );
  }

  void _showRecordingDialog(BuildContext context) {
    bool isRecording = false; // Track whether recording is in progress
    Color iconColor = Colors.black; // Initialize the icon color

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Stack(
        alignment: Alignment.bottomCenter,
        children: [
          GestureDetector(
            onTapDown: (_) {
              // When user taps down, set isRecording to true and update icon color to red
              setState(() {
                isRecording = true;
                iconColor = Colors.red;
              });
            },
            onTapUp: (_) {
              // When user releases tap, set isRecording to false and update icon color to black
              setState(() {
                isRecording = false;
                iconColor = Colors.black;
              });
            },
            onTapCancel: () {
              // Handle tap cancel event if needed
            },
            child: Container(
              color: const Color.fromARGB(0, 119, 114,
                  114), // Set the color to transparent to capture tap events
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Positioned(
            bottom: 20.0, // Adjust bottom padding as needed
            left: 0,
            right: 0,
            child: AlertDialog(
              contentPadding: EdgeInsets.all(10.0), // Adjust padding as needed
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Recording...', // Change dialog text to "Recording..."
                    style: TextStyle(fontSize: 16.0),
                  ),
                  SizedBox(height: 10.0), // Add some vertical spacing
                  StreamBuilder<int>(
                    stream:
                        Stream<int>.periodic(Duration(seconds: 1), (x) => x),
                    builder: (context, snapshot) {
                      return Text(
                        'Duration: ${snapshot.data ?? 0} seconds', // Display the duration
                        style: TextStyle(fontSize: 14.0),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40.0, // Adjust bottom padding as needed
            left: 20.0,
            child: GestureDetector(
              onTapDown: (_) {
                // When user taps down, set isRecording to true and update icon color to red
                setState(() {
                  isRecording = true;
                  iconColor = Colors.red;
                });
              },
              onTapUp: (_) {
                // When user releases tap, set isRecording to false and update icon color to black
                setState(() {
                  isRecording = false;
                  iconColor = Colors.black;
                });
              },
              onTapCancel: () {
                // Handle tap cancel event if needed
              },
              child: Icon(
                Icons.mic,
                size: 50,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String? filePath = result.files.single.path;
      if (filePath != null) {
        sendAttachment(filePath);
      }
    }
  }
}

class Message {
  final User sender;
  final String
      time; // Would usually be type DateTime or Firebase Timestamp in production apps
  final String text;
  final bool isLiked;
  final bool unread;
  final String reaction;
  final MessageType type;

  Message({
    required this.sender,
    required this.time,
    required this.text,
    required this.isLiked,
    required this.unread,
    required this.reaction,
    required this.type,
  });

  bool get isRead => true;

  get reactions => ['😊', '😂', '😍', '👍', '👏', '❤️', '🔥', '🎉', '🤔'];
}

// Enum to represent message types
enum MessageType {
  text,
  attachment,
}

class RefreshedChatScreen extends StatefulWidget {
  final String conversationId;
  final String senderName;

  RefreshedChatScreen({required this.conversationId, required this.senderName});

  @override
  _RefreshedChatScreenState createState() => _RefreshedChatScreenState();
}

class _RefreshedChatScreenState extends State<RefreshedChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChatScreen(
        conversationId: widget.conversationId,
        senderName: widget.senderName,
        currentUserId: 'participant1',
        clickedUserId: 'participant2',
        senderImageUrl: 'assets/images/james.jpg',
        isImage: false,
      ),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => RefreshedChatScreen(
          conversationId: '12345', // Replace with actual conversation ID
          senderName: 'John Doe', // Replace with actual sender name
        ),
      ),
    ),
  );
}
