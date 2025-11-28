import 'package:flutter/material.dart';
import 'answering_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class NicknameEntryScreen extends StatefulWidget {
  final String eventId;

  const NicknameEntryScreen({super.key, required this.eventId});

  @override
  State<NicknameEntryScreen> createState() => _NicknameEntryScreenState();
}

class _NicknameEntryScreenState extends State<NicknameEntryScreen> {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Tasarım Renkleri
  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _bgColor = const Color(0xFFF8FAFC);

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
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Image.asset('assets/images/logo.png',
                        width: 80, height: 80),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    "nickname_welcome".tr(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "nickname_prompt".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 40),

                  // Input Alanı
                  TextFormField(
                    controller: _nicknameController,
                    cursorColor: _primaryColor,
                    style: TextStyle(
                        color: _primaryColor, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "nickname_hint".tr(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              BorderSide(color: _primaryColor, width: 1.5)),
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

                  const SizedBox(height: 24),

                  // Buton
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 64),
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
    );
  }
}
