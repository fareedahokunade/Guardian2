import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'homescreen.dart';
import 'main.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _userName = ''; // Added for user's name
  String _userPhone = ''; // Added for user's phone number
  String? _userLocation = 'Unknown';
  String _recognizedWord = '';
  int _confirmationCount = 0;
  String _confirmedPanicCode = 'Record Panic Code';
  final List<String> _attemptedCodes = [];

  Future<void> _requestPermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  final List<TextEditingController> _contactControllers = List.generate(3, (index) => TextEditingController());
  bool _editMode = false;



  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _requestPermission();
    _fetchExistingData();
  }


  Future<void> _fetchExistingData() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot userData = await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).get();

      if (userData.exists) {
        Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['name'] ?? ''; // Fetch and set user's name
          _userPhone = user.phoneNumber ?? '';


          _confirmedPanicCode = data['panicCode'] ?? 'Record Panic Code';
          List<dynamic> contacts = data['contacts'] ?? [];
          for (int i = 0; i < _contactControllers.length && i < contacts.length; i++) {
            _contactControllers[i].text = contacts[i];
          }
        });
      }
      else {
        // Handle the case where user data does not exist in Firestore
        print('User data does not exist in Firestore');
      }
    } else {
      // Handle the case where there is no authenticated user
      print('No authenticated user found');
    }
  }


  void _listenForPanicCode() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _recognizedWord = result.recognizedWords;
            if (result.finalResult && _recognizedWord.isNotEmpty) {
              _isListening = false;
              _speech.stop();
              _attemptedCodes.add(_recognizedWord);

              if (_attemptedCodes.length == 3) {
                if (_attemptedCodes.toSet().length == 1) { // All attempts are the same
                  _confirmedPanicCode = _recognizedWord;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Panic code confirmed: $_confirmedPanicCode")));
                  _editMode = false; // Exit edit mode after confirming the code
                  _attemptedCodes.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Panic code not matched. Please try again.")));
                  _attemptedCodes.clear(); // Reset attempts
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please say the panic code again.")));
              }
            }
          });
        },
      );
    } else {
      setState(() => _isListening = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Speech recognition not available.")));
    }
  }

  Widget _buildContactField(int index) {
    return TextField(
      controller: _contactControllers[index],
      decoration: InputDecoration(
        labelText: 'Emergency Contact ${index + 1}',
        suffixIcon: _editMode
            ? IconButton(
          icon: Icon(Icons.clear),
          onPressed: () => _contactControllers[index].clear(),
        )
            : null,
      ),
      readOnly: !_editMode,
    );
  }
  void _saveDataToFirestore() async {
    // Get the current user from FirebaseAuth
    User? user = FirebaseAuth.instance.currentUser;
    String? phoneNumber = user?.phoneNumber; // User's phone number

    if (phoneNumber != null) {
      CollectionReference users = FirebaseFirestore.instance.collection('users');

      await users.doc(phoneNumber).update({
        'panicCode': '$_confirmedPanicCode',
        'contacts': _contactControllers.map((controller) => controller.text).toList(),
      }).then((_) {
        print("Data saved successfully!");
        // Navigate to HomePage or show a success message
      }).catchError((error) {
        print("Failed to save data: $error");
        // Handle the error, e.g., show an error message
      });
    } else {
      print("No authenticated user found.");
      // Handle the case where there is no authenticated user
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile Setup"),
        backgroundColor: Colors.deepPurple,
        actions: [
            _buildPopupMenu(),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => setState(() {
              _editMode = !_editMode;
              if (_editMode) {
                _attemptedCodes.clear(); // Clear previous attempts when entering edit mode
              }
            }),
          ),

        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4.0,
              child: ListTile(
                leading: Icon(Icons.account_circle, size: 50),
                title: Text(_userName), // Replace with actual user name variable
                subtitle: Text("Phone: $_userPhone"), // Replace with actual phone number and location variables
              ),
            ),
            InkWell(
              onTap: _editMode ? _listenForPanicCode : null, // Allow recording only in edit mode
              child: Chip(
                label: Text(_confirmedPanicCode),
                avatar: Icon(_isListening ? Icons.mic : Icons.mic_none),
              ),
            ),
            ...List.generate(3, (index) => _buildContactField(index)),
            if (_editMode)
              ElevatedButton(
                onPressed: () {
                  // Save the contacts and panic code
                  _saveDataToFirestore();
                  print("Panic Code: $_confirmedPanicCode");
                  _contactControllers.forEach((controller) => print("Contact: ${controller.text}"));
                  setState(() => _editMode = false);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => HomePage(panicWord: '$_confirmedPanicCode',)),
                  );// Exit edit mode after saving
                },
                child: Text('Save'),
              ),
          ],
        ),
      ),
    );
  }


  @override
  void dispose() {
    _contactControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      onSelected: _handleMenuSelection,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'profile',
          child: Text('Profile'),
        ),
        PopupMenuItem<String>(
          value: 'home',
          child: Text('HomeScreen'),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Text('Log Out'),
        ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'profile':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen()),
        );
        break;
      case 'home':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(panicWord: '')), // Adjust panicWord as needed
        );
        break;
      case 'logout':
        FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyApp()));
        // Navigate to login screen or handle log out as needed
        break;
    }
  }
}

