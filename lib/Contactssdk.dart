import 'dart:convert';
import 'package:crosschatsdk/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ContactsSDK {
  final List<dynamic> users;
  final String currentUserId;
  final String apiKey;

  // Customizable parameters with default values
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final double avatarRadius;
  final TextStyle userNameTextStyle;

  ContactsSDK({
    required this.users,
    required this.currentUserId,
    required this.apiKey,
    this.backgroundColor = const Color.fromARGB(255, 22, 43, 81),
    this.textColor = Colors.blueGrey,
    this.iconColor = Colors.green,
    this.avatarRadius = 35.0,
    this.userNameTextStyle = const TextStyle(
      color: Colors.blueGrey,
      fontSize: 16.0,
      fontWeight: FontWeight.w600,
    ),
  });

  Future<void> createOrGetConversation(
      String clickedUserId, BuildContext context) async {
    try {
      print(
          'Attempting to create or get conversation for user: $clickedUserId');
      final response = await http.get(
        Uri.parse(
            'http://10.0.2.2:8080/conversation/$currentUserId/$clickedUserId'),
        headers: {
          'x-secret-key': apiKey, // Include the API key in the request headers
        },
      );
      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
      if (response.statusCode == 200) {
        print('Conversation exists or was created successfully');
        final responseData = json.decode(response.body);
        final conversationId = responseData['_id'];

        final senderImageUrl =
            users.firstWhere((user) => user.name == clickedUserId).imageUrl;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              currentUserId: currentUserId,
              clickedUserId: clickedUserId,
              conversationId: conversationId,
              senderName: clickedUserId,
              senderImageUrl: senderImageUrl,
              isImage: false,
            ),
          ),
        );
      } else {
        print('Failed to create or get conversation');
        throw Exception('Failed to create or get conversation');
      }
    } catch (error) {
      print('Error: $error');
    }
  }
}

class FavouriteContacts extends StatelessWidget {
  final ContactsSDK contactsSDK;

  FavouriteContacts({Key? key, required this.contactsSDK});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
            ),
          ),
          Container(
            height: 120.0,
            color: contactsSDK
                .backgroundColor, // Use the customizable background color
            child: ListView.builder(
              padding: EdgeInsets.only(left: 10.0),
              scrollDirection: Axis.horizontal,
              itemCount: contactsSDK.users.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Material(
                        color: contactsSDK
                            .backgroundColor, // Use the customizable background color
                        child: InkWell(
                          onTap: () {
                            print(
                                'Image tapped for user ID: ${contactsSDK.users[index].id}');
                            contactsSDK.createOrGetConversation(
                              contactsSDK.users[index].name.toString(),
                              context,
                            );
                          },
                          child: CircleAvatar(
                            radius: contactsSDK
                                .avatarRadius, // Use the customizable avatar radius
                            backgroundImage:
                                AssetImage(contactsSDK.users[index].imageUrl),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            contactsSDK.users[index].name,
                            style: contactsSDK
                                .userNameTextStyle, // Use the customizable text style
                          ),
                          SizedBox(width: 5.0),
                          Icon(
                            Icons.circle,
                            size: 12.0,
                            color: contactsSDK
                                .iconColor, // Use the customizable icon color
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
