import 'package:crosschatsdk/videocall.dart';
import 'package:crosschatsdk/voicecall.dart';
import 'package:flutter/material.dart';

import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:path/path.dart' as path;

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

enum MessageType {
  text,
  attachment,
  voice,
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
  String _filePath = '';
  late IO.Socket socket;
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
  Future<void> fetchLastMessage() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:9090/conversations/${widget.conversationId}/messages?last=true'),
      headers: {
        'x-secret-key':
            '7b2613ea2fd6bb949db6d600da8e13bcb3974166', // Include the API key in the request headers
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
    fetchLastMessage(); // Charger initialement le dernier message
    connectToSocket();
    _textEditingController = TextEditingController();
    // Ajouter un écouteur pour détecter le début du défilement vers le haut
    _scrollController.addListener(() {
      if (_scrollController.position.atEdge) {
        if (_scrollController.position.pixels == 0) {
          // Début du défilement vers le haut
          fetchPreviousMessages(); // Charger les messages précédents
        }
      }
    });
  }

// Méthode pour charger les messages précédents
  Future<void> fetchPreviousMessages() async {
    final response = await http.get(
      Uri.parse(
          'http://10.0.2.2:9090/conversations/${widget.conversationId}/messages?before=${messages.last['timestamp']}'),
      headers: {
        'x-secret-key':
            '7b2613ea2fd6bb949db6d600da8e13bcb3974166', // Include the API key in the request headers
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
          'http://10.0.2.2:9090/conversations/${widget.conversationId}/messages'),
      headers: {
        'x-secret-key':
            '7b2613ea2fd6bb949db6d600da8e13bcb3974166', // Include the API key in the request headers
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
    socket = IO.io('http://10.0.2.2:9090', <String, dynamic>{
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
          'http://10.0.2.2:9090/conversations/${widget.conversationId}/attachments'),
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
      Uri.parse('http://10.0.2.2:9090/messages/$messageId/emoji'),
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
          'http://10.0.2.2:9090/conversations/${widget.conversationId}/attachments'));

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
    final bool isMe = senderId == currentUserId;
    final bool showAvatar = !isMe && isLastMessageFromUser;
    final Color backgroundColor = isMe ? Colors.blue : Colors.grey;
    final Color textColor = isMe ? Colors.white : Colors.black;
    final CrossAxisAlignment crossAxisAlignment =
        isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final MainAxisAlignment mainAxisAlignment =
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start;

    double fontSize = 16.0; // Taille de police par défaut
    double containerWidth =
        MediaQuery.of(context).size.width; // Largeur par défaut

    if (message.length <= 5) {
      // Si le message est très court, occuper environ 1/5 de la largeur de l'écran
      containerWidth = MediaQuery.of(context).size.width * (1 / 6);
    } else if (message.length <= 10) {
      // Si le message est court, occuper environ 2/5 de la largeur de l'écran
      containerWidth = MediaQuery.of(context).size.width * (1 / 5);
    } else if (message.length <= 20) {
      // Si le message est de longueur moyenne, occuper environ 3/5 de la largeur de l'écran
      containerWidth = MediaQuery.of(context).size.width * (2 / 5);
    } else if (message.length <= 50) {
      // Si le message est assez long, occuper environ 4/5 de la largeur de l'écran
      containerWidth = MediaQuery.of(context).size.width * (4 / 5);
    }

    if (message.length > 50) {
      // Si le message est très long, occuper toute la largeur de l'écran
      containerWidth = MediaQuery.of(context).size.width;
    }

    if (message.length > 50) {
      // Si le message est long, réduire la taille de la police
      fontSize = 14.0;
    }
    if (messageType == MessageType.attachment) {
      // Pour les pièces jointes, définir la largeur du conteneur sur environ 2/3 de la largeur de l'écran
      containerWidth = MediaQuery.of(context).size.width * (1 / 4);
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (showAvatar)
            CircleAvatar(
              radius: 15.0,
              backgroundImage: AssetImage(avatarUrl),
            ),
          Row(
            mainAxisAlignment: mainAxisAlignment,
            children: [
              Container(
                width:
                    containerWidth, // Définir la largeur du conteneur de message en fonction de la longueur du message
                child: Container(
                  padding: EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 30.0 : 0.0),
                      topRight: Radius.circular(isMe ? 0.0 : 30.0),
                      bottomLeft: Radius.circular(30.0),
                      bottomRight: Radius.circular(30.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (messageType == MessageType.text)
                        Text(
                          message,
                          textAlign: isMe
                              ? TextAlign.right
                              : TextAlign
                                  .left, // Texte aligné à droite pour l'utilisateur actuel, à gauche pour les autres
                          style: TextStyle(
                            color: textColor,
                            fontSize:
                                fontSize, // Utilisation de la taille de police calculée
                          ),
                        ),
                      if (messageType == MessageType.attachment)
                        Image.network(
                          message,
                          width: 200,
                          height: 200,
                        ),
                      SizedBox(height: 5.0),
                      if (emojis
                          .isNotEmpty) // Placer les emojis sous le message
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Wrap(
                            spacing: 4.0,
                            runSpacing: 2.0,
                            children: emojis.map((emoji) {
                              return Text(
                                emoji,
                                style: TextStyle(fontSize: 16.0),
                              );
                            }).toList(),
                          ),
                        ),
                      Text(
                        time,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isMe)
                IconButton(
                  icon: Icon(Icons.add_reaction),
                  onPressed: () {
                    _showReactionsDialog(messageId);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color.fromARGB(255, 0, 0, 0).withOpacity(1),
            width: 1.0,
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        height: 70.0,
        color: Color.fromARGB(255, 17, 22, 53),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.photo),
              onPressed: _selectAttachment,
              color: Theme.of(context).canvasColor,
            ),
            Expanded(
              child: TextField(
                controller: _textEditingController,
                onChanged: (String text) {
                  setState(() {
                    _isComposing = text.isNotEmpty;
                  });
                },
                onSubmitted: _isComposing ? _handleSubmitted : null,
                style: TextStyle(
                    color: Colors.white), // Set the text color to white
                decoration: InputDecoration.collapsed(
                  hintText: 'Send a message...',
                  hintStyle: TextStyle(
                      color: Colors
                          .blue[200]), // Set the hint text color to blue-white
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.send),
              onPressed: () {
                String message = _textEditingController.text;
                if (message.isNotEmpty) {
                  sendMessage(message, "text");
                  _textEditingController.clear();
                  _scrollToBottom();
                  fetchMessages();
                }
              },
              color: Theme.of(context).canvasColor,
            ),
            GestureDetector(
              onLongPressStart: (_) {
                setState(() {
                  _isRecording = true; // Start recording
                  _showRecordingDialog(context); // Show recording dialog
                });
              },
              onLongPressEnd: (_) {
                setState(() {
                  _isRecording = false; // Stop recording
                  Navigator.of(context).pop(); // Dismiss recording dialog
                });
              },
              child: IconButton(
                icon: Icon(Icons.mic),
                onPressed: () {
                  // Handle short press if needed
                },
                color:
                    _isRecording ? Colors.red : Theme.of(context).canvasColor,
              ),
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
    // Create a map to store the index of the last message from each sender
    Map<String, int> lastMessageIndexMap = {};

    // Populate the map with the index of the last message from each sender
    for (int i = 0; i < messages.length; i++) {
      String senderId = messages[i]['sender'];
      lastMessageIndexMap[senderId] = i;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              widget.senderName,
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: () {
              // Navigate to video call screen when tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VideoCallScreen(conversationId: widget.conversationId),
                ),
              );
            },
            borderRadius:
                BorderRadius.circular(30), // Adjust the value as needed
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.video_call,
                color: Theme.of(context).canvasColor,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              // Navigate to voice call screen when tapped
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VoiceCallScreen(conversationId: widget.conversationId),
                ),
              );
            },
            borderRadius:
                BorderRadius.circular(30), // Adjust the value as needed
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                Icons.call,
                color: Theme.of(context).canvasColor,
              ),
            ),
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
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: false,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
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
                  senderId: message['sender'], // Add senderId parameter
                  currentUserId: currentUserId, // Add currentUserId parameter
                  avatarUrl: 'assets/images/1.png', // Adjust as needed
                  message: message['content'] ?? '',
                  time: message['timestamp'] ?? '',
                  messageType: messageType,
                  messageId: message['_id'] ?? '',
                  emojis: emojis,
                  isLastMessageFromUser: isLastMessageFromUser, // Pass the flag
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Stack(
        alignment: Alignment.bottomCenter,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black.withOpacity(0.4),
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
