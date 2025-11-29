import 'package:flutter/material.dart';
import 'answering_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ

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
            padding: EdgeInsets.symmetric(horizontal: 28.w), // .w
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r), // .r
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20.r, // .r
                            offset: Offset(0, 10.h)) // .h
                      ],
                    ),
                    child: Image.asset('assets/images/logo4.png',
                        width: 80.w, height: 80.w), // .w
                  ),
                  SizedBox(height: 32.h), // .h
                  Text(
                    "nickname_welcome".tr(),
                    style: TextStyle(
                      fontSize: 26.sp, // .sp
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h), // .h
                  Text(
                    "nickname_prompt".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16.sp, color: Colors.grey.shade600), // .sp
                  ),
                  SizedBox(height: 40.h), // .h

                  // Input Alanı
                  TextFormField(
                    controller: _nicknameController,
                    cursorColor: _primaryColor,
                    style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16.sp), // .sp
                    decoration: InputDecoration(
                      hintText: "nickname_hint".tr(),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.person_outline_rounded,
                          color: Colors.grey.shade400, size: 24.sp), // .sp
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r), // .r
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r), // .r
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20.r), // .r
                          borderSide:
                              BorderSide(color: _primaryColor, width: 1.5)),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 20.h, horizontal: 20.w), // .h .w
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return "nickname_validation".tr();
                      }
                      return null;
                    },
                  ),

                  SizedBox(height: 24.h), // .h

                  // Buton
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: Size(double.infinity, 64.h), // .h
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r)), // .r
                    ),
                    onPressed: _submitNickname,
                    child: Text(
                      "nickname_button".tr(),
                      style: TextStyle(
                          fontSize: 18.sp, fontWeight: FontWeight.bold), // .sp
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
