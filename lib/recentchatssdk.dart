import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crosschatsdk/chat_screen.dart'; // Ensure you have this import correctly

class RecentChatsSDK extends StatefulWidget {
  final String currentUserId;
  final List<User> users;
  final String apiKey;
  final Color backgroundColor;
  final Color chatBackgroundColor;
  final Color chatTextColor;
  final Color deleteIconColor;
  final Color deleteBackgroundColor;
  final double avatarRadius;
  final TextStyle senderNameTextStyle;
  final TextStyle messageTextStyle;
  final TextStyle timestampTextStyle;

  RecentChatsSDK({
    required this.currentUserId,
    required this.users,
    required this.apiKey,
    this.backgroundColor = const Color.fromARGB(255, 0, 0, 0),
    this.chatBackgroundColor = const Color.fromARGB(255, 22, 43, 81),
    this.chatTextColor = const Color.fromARGB(255, 246, 242, 242),
    this.deleteIconColor = Colors.white,
    this.deleteBackgroundColor = Colors.red,
    this.avatarRadius = 35.0,
    this.senderNameTextStyle = const TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.bold,
      color: Color.fromARGB(255, 246, 242, 242),
    ),
    this.messageTextStyle = const TextStyle(
      fontSize: 15.0,
      fontWeight: FontWeight.bold,
      color: Color.fromARGB(255, 195, 199, 201),
    ),
    this.timestampTextStyle = const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 15.0,
      color: Color.fromARGB(255, 246, 244, 244),
    ),
  });

  @override
  _RecentChatsSDKState createState() => _RecentChatsSDKState();
}

class _RecentChatsSDKState extends State<RecentChatsSDK> {
  late Future<List<dynamic>> _conversations;

  @override
  void initState() {
    super.initState();
    _conversations = fetchData();
  }

  Future<List<dynamic>> fetchData() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8080/conversation/${widget.currentUserId}'),
        headers: {
          'x-secret-key': widget.apiKey,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (error) {
      print('Error: $error');
      return [];
    }
  }

  void deleteConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:8080/conversations/$conversationId'),
        headers: {
          'x-secret-key': widget.apiKey,
        },
      );
      if (response.statusCode == 200) {
        print('Conversation deleted successfully');
        setState(() {
          _conversations = fetchData();
        });
      } else {
        print('Failed to delete conversation');
      }
    } catch (error) {
      print('Error deleting conversation: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => fetchData().then((data) => setState(() {
            _conversations = Future.value(data);
          })),
      child: FutureBuilder<List<dynamic>>(
        future: _conversations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading chats',
                style: TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No recent chats',
                style: TextStyle(color: Colors.white),
              ),
            );
          } else {
            return buildRecentChatsList(context, snapshot.data!);
          }
        },
      ),
    );
  }

  Widget buildRecentChatsList(
      BuildContext context, List<dynamic> conversations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30.0),
                topRight: Radius.circular(30.0),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30.0),
                topRight: Radius.circular(30.0),
              ),
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (BuildContext context, int index) {
                  final conversation = conversations[index];
                  final lastMessage = conversation['messages'].isNotEmpty
                      ? conversation['messages'].last
                      : null;
                  final participants = conversation['participants'];
                  final otherParticipantId = participants.firstWhere(
                    (participantId) => participantId != widget.currentUserId,
                    orElse: () => null,
                  );
                  final senderName =
                      otherParticipantId ?? ''; // Use participant ID directly
                  final messageContent =
                      lastMessage != null ? lastMessage['content'] : '';
                  final messageTimestamp = lastMessage['timestamp'];
                  final conversationId = conversation['_id']; // Conversation ID

                  // Find the user by name in the list of users
                  final User? sender = widget.users
                      .firstWhere((user) => user.name == senderName);

                  // Use the sender's image URL if found, otherwise use a default image
                  final String senderImageUrl =
                      sender?.imageUrl ?? 'default_image.png';

                  return Dismissible(
                    key:
                        Key(conversationId), // Unique key for each conversation
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20.0),
                      color: widget
                          .deleteBackgroundColor, // Background color for delete action
                      child: Icon(Icons.delete, color: widget.deleteIconColor),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) {
                      return showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Confirm Delete'),
                            content: Text(
                                'Are you sure you want to delete your conversation with $senderName?'),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () => Navigator.of(context)
                                    .pop(false), // Cancel delete
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context)
                                    .pop(true), // Confirm delete
                                child: Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) {
                      // Implement delete action here if confirmed
                      deleteConversation(conversationId);
                    },
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              currentUserId: widget.currentUserId,
                              conversationId: conversationId,
                              senderName: senderName,
                              clickedUserId: '',
                              senderImageUrl:
                                  senderImageUrl, // Use user image URL
                              isImage: false,
                            ),
                          ),
                        ).then((_) => fetchData().then((data) => setState(() {
                              _conversations = Future.value(data);
                            })));
                      },
                      child: Container(
                        margin:
                            EdgeInsets.only(top: 5.0, bottom: 5.0, right: 20.0),
                        padding: EdgeInsets.symmetric(
                            vertical: 10.0, horizontal: 20.0),
                        decoration: BoxDecoration(
                          color: widget.chatBackgroundColor,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(20.0),
                            bottomRight: Radius.circular(20.0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: widget.avatarRadius,
                                  backgroundImage: AssetImage(
                                      senderImageUrl), // Use user image
                                ),
                                SizedBox(width: 10.0),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: widget.senderNameTextStyle,
                                    ),
                                    SizedBox(height: 5.0),
                                    Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.45,
                                      child: Text(
                                        messageContent,
                                        style: widget.messageTextStyle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  messageTimestamp,
                                  style: widget.timestampTextStyle,
                                ),
                                SizedBox(height: 5.0),
                                Text(
                                  ' ',
                                  style: TextStyle(
                                    color: widget.chatTextColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class User {
  final int id;
  final String name;
  final String imageUrl;

  User({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  bool get isOnline => true;
}
