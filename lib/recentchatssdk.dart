import 'dart:convert';
import 'package:crosschatsdk/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RecentChatsSDK {
  final String currentUserId;
  final List<User> users; // Change the type to List<User>
  final String apiKey;

  RecentChatsSDK(
      {required this.currentUserId, required this.users, required this.apiKey});

  Future<List<dynamic>> fetchData() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.0.2.2:9090/conversation/$currentUserId'),
        headers: {'x-secret-key': apiKey}, // Add the secret key header
      );
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        return responseData;
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (error) {
      print('Error: $error');
      // Handle error
      return [];
    }
  }

  Widget buildRecentChatsList(
      BuildContext context, List<dynamic> conversations) {
    return RefreshIndicator(
      onRefresh: () => fetchData(), // Method to handle refresh
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 0, 0, 0),
                borderRadius: BorderRadius.only(
                    // topLeft: Radius.circular(30.0),
                    //topRight: Radius.circular(30.0),
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
                      (participantId) => participantId != currentUserId,
                      orElse: () => null,
                    );
                    final senderName =
                        otherParticipantId ?? ''; // Use participant ID directly
                    final messageContent =
                        lastMessage != null ? lastMessage['content'] : '';
                    final messageTimestamp = lastMessage['timestamp'];
                    '';
                    final conversationId =
                        conversation['_id']; // Conversation ID

                    // Find the user by name in the list of users
                    final User? sender =
                        users.firstWhere((user) => user.name == senderName);

                    // Use the sender's image URL if found, otherwise use a default image
                    final String senderImageUrl = sender?.imageUrl ?? '';

                    return Dismissible(
                      key: Key(
                          conversationId), // Unique key for each conversation
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 20.0),
                        color: Colors.red, // Background color for delete action
                        child: Icon(Icons.delete, color: Colors.white),
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
                                currentUserId: currentUserId,
                                conversationId: conversationId,
                                senderName: senderName,
                                clickedUserId: '',
                                senderImageUrl:
                                    senderImageUrl, // Use user image URL
                                isImage: false,
                              ),
                            ),
                          ).then((_) => fetchData());
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                              top: 5.0, bottom: 5.0, right: 20.0),
                          padding: EdgeInsets.symmetric(
                              vertical: 10.0, horizontal: 20.0),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(255, 22, 43, 81),
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
                                    radius: 35.0,
                                    backgroundImage: AssetImage(
                                        senderImageUrl), // Use user image
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        senderName,
                                        style: TextStyle(
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.bold,
                                          color: const Color.fromARGB(
                                              255, 246, 242, 242),
                                        ),
                                      ),
                                      SizedBox(height: 5.0),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.45,
                                        child: Text(
                                          messageContent,
                                          style: TextStyle(
                                            fontSize: 15.0,
                                            fontWeight: FontWeight.bold,
                                            color: const Color.fromARGB(
                                                255, 195, 199, 201),
                                          ),
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                      color: const Color.fromARGB(
                                          255, 246, 244, 244),
                                    ),
                                  ),
                                  SizedBox(height: 5.0),
                                  Text(
                                    ' ',
                                    style: TextStyle(
                                      color: Colors.white,
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
      ),
    );
  }

  void deleteConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://10.0.2.2:9090/conversations/$conversationId'),
      );
      if (response.statusCode == 200) {
        print('Conversation deleted successfully');
        // fetchData();
      } else {
        print('Failed to delete conversation');
      }
    } catch (error) {
      print('Error deleting conversation: $error');
    }
  }
}

void deleteConversation(String conversationId) async {
  try {
    final response = await http.delete(
      Uri.parse('http://10.0.2.2:9090/conversations/$conversationId'),
      headers: {
        'x-secret-key':
            '7b2613ea2fd6bb949db6d600da8e13bcb3974166', // Include the API key in the request headers
      },
    );
    if (response.statusCode == 200) {
      print('Conversation deleted successfully');
      // fetchData();
    } else {
      print('Failed to delete conversation');
    }
  } catch (error) {
    print('Error deleting conversation: $error');
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

  get isOnline => true;
}
