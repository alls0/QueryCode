import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ

class ThankYouScreen extends StatelessWidget {
  const ThankYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Tasarım Renkleri
    const Color primaryColor = Color(0xFF1A202C);
    const Color bgColor = Color(0xFFF8FAFC);
    const Color successColor = Color(0xFF38A169); // Yumuşak Yeşil

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32.0.r), // .r
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24.r), // .r
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                        color: successColor.withOpacity(0.1),
                        blurRadius: 20.r, // .r
                        spreadRadius: 5.r) // .r
                  ],
                ),
                child: Icon(Icons.check_rounded,
                    color: successColor, size: 64.sp), // .sp
              ),
              SizedBox(height: 32.h), // .h
              Text(
                "thanks_title".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 28.sp, // .sp
                    fontWeight: FontWeight.w800,
                    color: primaryColor),
              ),
              SizedBox(height: 12.h), // .h
              Text(
                "thanks_subtitle".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16.sp, color: Colors.grey.shade600), // .sp
              ),
              SizedBox(height: 48.h), // .h
              if (!kIsWeb)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                        horizontal: 48.w, vertical: 20.h), // .w .h
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.r)), // .r
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text("thanks_button_mobile".tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
