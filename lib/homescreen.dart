import 'dart:io';

import 'package:flutter/material.dart';
import 'package:another_audio_recorder/another_audio_recorder.dart';
import 'package:guardian/main.dart';

import 'package:location/location.dart' hide PermissionStatus;
import 'package:path/path.dart' as path;


import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profilescreen.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

class HomePage extends StatefulWidget {
  final String panicWord;

  HomePage({Key? key, required this.panicWord}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  Location _location = Location();
  bool _isRecording = false;
  String? _localRecordingPath;
  List<String> _emergencyContacts = [];
  int _panicWordCount = 0;
  String name = "";
  List<String> _safetyAreas = ["113 - Traffic Accidents", '997 - Anti-Corruption', '3512 -Gender Based Violence', "112 - Emergency", "116 - Child Help Line", "3511 - Abuse By Police Officer", "118 - Traffic Police"]; // Example safety areas


  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _requestPermissions();

  }



  Future<void> _requestPermissions() async {
    await [Permission.location, Permission.microphone, Permission.storage].request();
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    bool available = await _speech.initialize();
    if (available) {
      _startListening();
    } else {
      print("The user has denied the use of speech recognition.");
    }
  }



  void _startListening() {

    _speech.listen(
      onResult: (result) {
        if (result.recognizedWords.toLowerCase() == widget.panicWord.toLowerCase() && !_isRecording) {
          _panicWordCount++;
          _performPanicAction(_panicWordCount);
        }
      },
    );
    setState(() => _isListening = true);
  }

  Future<void> _stopRecording() async {
    if (_recorder != null && _isRecording) {
      // Stop the recorder
      await _recorder!.stop();
      setState(() {
        _isRecording = false; // Update the recording state
      });
    }
  }

  Future<void> _sendRecordingToEmergencyContacts() async {
    // Ensure recording is stopped and file is available
    await _stopRecording();

    // Fetch emergency contacts
    List<String> recipients = await _fetchEmergencyContacts();

    if (recipients.isNotEmpty && _localRecordingPath != null) {
      // Assuming sendEmail method can handle attachments
      await sendRecording(
        recipients,
        "Emergency Alert!",
        "Please find the attached recording for the emergency alert.",
        File(_localRecordingPath!), // Pass the recorded file as an attachment
      );
    } else {
      print("No recipients found or recording path is null.");
    }
  }
  Future<void> sendRecording(List<String> recipients, String subject, String body, File attachment) async {
    String username = 'tennhy.okunade@gmail.com';
    String password = 'nrgm bjmg mtie vyqk';

    // Note: For Gmail, you might need to enable "Less secure app access"
    // or create an App Password if 2-Step Verification is enabled.
    final smtpServer = gmail(username, password);

    // Create the message
    final message = mailer.Message()
      ..from = mailer.Address(username, 'Admin')
      ..recipients.addAll(recipients) // Add recipients from the list
      ..subject = subject
      ..text = body;

    final message1 = mailer.Message()
      ..from = mailer.Address(username, 'Admin')
      ..recipients.addAll(["leinyuyraissa12@gmail.com"]) // Add recipients from the list
      ..subject = subject
      ..text = body;

    final file = File(_localRecordingPath!);
    final fileAttachment = mailer.FileAttachment(file)
      ..fileName = path.basename(file.path); // Use the 'path' package to get the file name

    message.attachments.add(fileAttachment);
    message1.attachments.add(fileAttachment);// Plain text body

    try {
      // Send the email
      final sendReport = await mailer.send(message, smtpServer);
      final sendReport1 = await mailer.send(message1, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on mailer.MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }



  Future<void> _performPanicAction(int count) async {
    switch (count) {
      case 1:
        await _requestPermissions();
        _fetchEmergencyContacts();
        _sendAlert();
        _startRecording();// Ensure _sendAlert is awaited
        break;
      case 2:

      // Implement Panic Action 2
        break;
      case 3:

      // Implement Panic Action 3
        break;
      default:
        print("Panic actions completed");
        _panicWordCount = 0; // Reset the counter
        break;
    }
  }
  AnotherAudioRecorder? _recorder;

  Future<void> _startRecording() async {

    // Request necessary permissions first
    bool hasPermissions = await AnotherAudioRecorder.hasPermissions ?? false;
    if (!hasPermissions) {
      // Show error or request permissions
      return;
    }

    // Get the directory where the recording will be saved
    Directory appDocDirectory = Directory('/storage/emulated/0/Download');

    // Create a file path for the recording
    String filePath = '${appDocDirectory.path}/${DateTime.now().millisecondsSinceEpoch}.wav';
    print (filePath);

    // Initialize the recorder
    _recorder = AnotherAudioRecorder(filePath, audioFormat: AudioFormat.WAV);
    await _recorder!.initialized;

    // Start recording
    await _recorder!.start();
    setState(() {
      _isRecording = true;
      _localRecordingPath = filePath; // Save the file path if you need to access the recording later
    });
  }

  Future<String?> _uploadRecording(String? filePath) async {
    if (filePath == null) return null;
    File file = File(filePath);
    String fileName = 'recordings/${DateTime.now().millisecondsSinceEpoch}.wav';
    TaskSnapshot snapshot = await FirebaseStorage.instance.ref(fileName).putFile(file);
    String downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<List<String>> _fetchEmergencyContacts() async {
    User? user = FirebaseAuth.instance.currentUser;
    List<String> contacts = [];

    if (user != null && user.phoneNumber != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.phoneNumber).get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        if (data.containsKey('contacts') && data['contacts'] is List) {
          contacts = List<String>.from(data['contacts']);

          name = data['name'];
        }
      }
    }

    return contacts;
  }




  Future<void> sendEmail(List<String> recipients, String subject, String body) async {
    // Configure the SMTP server settings. Using Gmail as an example:
    String username = 'tennhy.okunade@gmail.com';
    String password = 'nrgm bjmg mtie vyqk';

    // Note: For Gmail, you might need to enable "Less secure app access"
    // or create an App Password if 2-Step Verification is enabled.
    final smtpServer = gmail(username, password);

    // Create the message
    final message = mailer.Message()
      ..from = mailer.Address(username, 'Admin')
      ..recipients.addAll(recipients) // Add recipients from the list
      ..subject = subject
      ..text = body; // Plain text body

    try {
      // Send the email
      final sendReport = await mailer.send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());
    } on mailer.MailerException catch (e) {
      print('Message not sent.');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
    }
  }


  Future<void> _sendAlert() async {
    LocationData location = await _location.getLocation();
    String body = "Emergency! I'm at ${location.latitude}, ${location
        .longitude}. I think I'm in danger.";
    List<
        String> recipients = await _fetchEmergencyContacts(); // List of email addresses
    String subject = 'Emergency Alert from $name!';
    sendEmail(recipients, subject, body);
    sendEmail(["leinyuyraissa12@gmail.com"], subject, body);
    // Logic to send `message` to `_emergencyContacts`
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Guardian"),
        backgroundColor: Colors.deepPurple,
        actions: <Widget>[
          _buildPopupMenu(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        _panicWordCount++;
                        _performPanicAction(_panicWordCount);
                      },
                      child: Text('PANIC',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.black,
                        textStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ),
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: _stopPanicActions,
                      child: Icon(Icons.stop, size: 40),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.black,
                        shape: CircleBorder(),
                        padding: EdgeInsets.all(20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(

                itemCount: _safetyAreas.length,
                itemBuilder: (context, index) {
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      title: Text(_safetyAreas[index]),
                      leading: Icon(Icons.location_on, color: Colors.deepPurple),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _stopPanicActions() async {
    _stopRecording();
    _sendRecordingToEmergencyContacts();
    _uploadRecording(_localRecordingPath);


    // Stop recording and other panic actions
    _panicWordCount = 0; // Reset panic word count
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
        break;
      case 'home':
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage(panicWord: widget.panicWord)));
        break;
      case 'logout':
        FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MyApp()));

        // Navigate to login screen or handle log out
        break;
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}