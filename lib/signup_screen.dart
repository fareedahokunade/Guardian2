import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'otp_screen.dart'; // Ensure this import path is correct

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_screen.dart'; // Ensure this import path is correct

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController(); // Name controller

  void _verifyPhoneNumber() async {
    final String phoneNumber = _phoneController.text.trim();
    final String name = _nameController.text.trim(); // Get the name input

    if (phoneNumber.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Name and phone number cannot be empty")));
      return;
    }

    // Trigger phone number verification
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification
        await _auth.signInWithCredential(credential).then((userCredential) async {
          if (userCredential.user != null) {
            print("Phone number automatically verified and user signed in: ${userCredential.user?.phoneNumber}");

            // Upload the name and phone number to Firestore
            await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.phoneNumber).set({
              'name': name,
              'phone': phoneNumber,
            });
          }
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification failed: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        // Navigate to OTP screen immediately after the code is sent
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              name: name,
              phoneNumber: phoneNumber,
              verificationId: verificationId,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Auto-retrieval time out
        print("Verification code auto retrieval timeout");
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(height: 50),
                // If you have a logo image, use this:
                /*
                Image.asset(
                  'assets/logo.png',
                  width: 150,
                  height: 150,
                ),
                */
                // If you don't have a logo image, style the text as a logo:
                Text(
                  'Guardian',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple, // Choose your color
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 50),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                SizedBox(height: 20),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed:_verifyPhoneNumber,
                  child: Text('Verify Phone Number'),
                  style: ElevatedButton.styleFrom(
                    primary: Colors.deepPurple, // Button color
                    onPrimary: Colors.white, // Text color
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
