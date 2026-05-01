import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roam_io/services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentDisplayName();
  }

  Future<void> _loadCurrentDisplayName() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final profile = await ProfileService().getProfile(uid);

  if (!mounted) return;

  setState(() {
    _displayNameController.text = profile?.displayName ?? '';
  });
}

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await ProfileService().updateDisplayName(uid, _displayNameController.text.trim());
      // Optionally update Firebase Auth displayName too:
      await FirebaseAuth.instance.currentUser?.updateDisplayName(_displayNameController.text.trim());
      Navigator.pop(context); // Go back after saving
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Display Name')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: InputDecoration(labelText: 'Display Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter a name' : null,
              ),
              SizedBox(height: 20),
              _loading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _save,
                      child: Text('Save'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}