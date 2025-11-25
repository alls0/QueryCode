import 'package:flutter/material.dart';
import 'answering_screen.dart';
import 'package:easy_localization/easy_localization.dart'; // YENİ: Paketi import et

class NicknameEntryScreen extends StatefulWidget {
  final String eventId;

  const NicknameEntryScreen({super.key, required this.eventId});

  @override
  State<NicknameEntryScreen> createState() => _NicknameEntryScreenState();
}

class _NicknameEntryScreenState extends State<NicknameEntryScreen> {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _submitNickname() {
    if (_formKey.currentState!.validate()) {
      final nickname = _nicknameController.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AnsweringScreen(
            eventId: widget.eventId,
            nickname: nickname,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF2D3748);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(192, 58, 142, 202),
              Color.fromARGB(255, 219, 225, 232)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png',
                        width: 80, height: 80),
                    const SizedBox(height: 20),
                    Text(
                      "nickname_welcome".tr(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "nickname_prompt".tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: accentColor),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 16,
                            offset: const Offset(4, 7),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _nicknameController,
                        decoration: InputDecoration(
                          hintText: "nickname_hint".tr(),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 20),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "nickname_validation".tr();
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: _submitNickname,
                      child: Text(
                        "nickname_button".tr(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
