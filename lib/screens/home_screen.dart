import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_question_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_events_screen.dart';
import 'auth_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // --- Geri Bildirim Modal ---
  void _showFeedbackModal(BuildContext context) {
    final Color primaryDark = const Color(0xFF1A202C);
    final Color primaryBlue = const Color(0xFF3182CE);
    final Color bgLight = const Color(0xFFF8FAFC);

    final TextEditingController feedbackController = TextEditingController();
    int selectedRating = 0;
    String selectedType = 'feedback_suggestion'.tr();
    List<String> feedbackTypes = [
      'feedback_suggestion'.tr(),
      'feedback_bug'.tr(),
      'feedback_other'.tr()
    ];

    String? inputErrorText;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24.r)), // .r Eklendi
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24.w, // .w Eklendi
                right: 24.w, // .w Eklendi
                top: 24.h, // .h Eklendi
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "feedback_title".tr(),
                          style: TextStyle(
                            fontSize: 20.sp, // .sp Eklendi
                            fontWeight: FontWeight.bold,
                            color: primaryDark,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close,
                              color: Colors.grey.shade400, size: 24.sp),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h), // .h Eklendi
                    Text("feedback_subject".tr(),
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryDark,
                            fontSize: 14.sp)), // Font boyutu eklendi
                    SizedBox(height: 12.h), // .h Eklendi
                    Wrap(
                      spacing: 10.w, // .w Eklendi
                      runSpacing: 10.h,
                      children: feedbackTypes.map((type) {
                        bool isSelected = selectedType == type;
                        return ChoiceChip(
                          label: Text(type,
                              style: TextStyle(fontSize: 12.sp)), // Font boyutu
                          selected: isSelected,
                          selectedColor: primaryBlue.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryBlue : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12.sp,
                          ),
                          backgroundColor: bgLight,
                          side: BorderSide(
                            color:
                                isSelected ? primaryBlue : Colors.transparent,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8.r)), // .r Eklendi
                          onSelected: (bool selected) {
                            if (selected) {
                              setModalState(() => selectedType = type);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 24.h), // .h Eklendi
                    TextField(
                      controller: feedbackController,
                      maxLength: 500,
                      maxLines: 4,
                      onChanged: (val) {
                        if (inputErrorText != null) {
                          setModalState(() => inputErrorText = null);
                        }
                      },
                      style: TextStyle(fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: "feedback_placeholder".tr(),
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14.sp),
                        filled: true,
                        fillColor: bgLight,
                        errorText: inputErrorText,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16.r), // .r Eklendi
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide:
                              BorderSide(color: primaryBlue, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide(
                              color: Colors.red.shade300, width: 1.5),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Center(
                        child: Text(
                            selectedRating > 0
                                ? "$selectedRating ${"feedback_stars".tr()}"
                                : "feedback_rate".tr(),
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12.sp))), // .sp Eklendi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 36.sp, // .sp Eklendi
                            color: const Color(0xFFFFD700),
                          ),
                          onPressed: () {
                            setModalState(() {
                              selectedRating = index + 1;
                              inputErrorText = null;
                            });
                          },
                        );
                      }),
                    ),
                    SizedBox(height: 24.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          padding: EdgeInsets.symmetric(
                              vertical: 16.h), // .h Eklendi
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(14.r), // .r Eklendi
                          ),
                          elevation: 0,
                        ),
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (feedbackController.text.trim().isEmpty &&
                                    selectedRating == 0) {
                                  setModalState(() {
                                    inputErrorText =
                                        "feedback_error_message".tr();
                                  });
                                  return;
                                }

                                setModalState(() => isLoading = true);

                                try {
                                  final user =
                                      FirebaseAuth.instance.currentUser;

                                  await FirebaseFirestore.instance
                                      .collection('feedbacks')
                                      .add({
                                    'type': selectedType,
                                    'message': feedbackController.text.trim(),
                                    'rating': selectedRating,
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'platform':
                                        Theme.of(context).platform.toString(),
                                    'userId': user?.uid,
                                    'userEmail': user?.email,
                                  });

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text("feedback_thank_you".tr()),
                                        backgroundColor: primaryBlue,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isLoading = false);
                                  debugPrint("Hata: $e");
                                }
                              },
                        child: isLoading
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: const CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                "feedback_send".tr(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp, // .sp Eklendi
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1A202C);
    const Color cardColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8FAFC);
    const Color textColor = Color(0xFF2D3748);
    const Color iconColor = Color(0xFF4A5568);

    // --- Info Dialog ---
    void showInfoDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: cardColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r)),
            title: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: primaryColor, size: 24.sp),
                SizedBox(width: 12.w),
                Text("infoTitle".tr(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 18.sp)),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text("infoP1".tr(),
                      style: TextStyle(color: iconColor, fontSize: 14.sp)),
                  SizedBox(height: 16.h),
                  Text("infoP2".tr(),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 14.sp)),
                  Divider(color: Colors.grey.shade200, height: 24.h),
                  Text("infoP3".tr(),
                      style: TextStyle(color: iconColor, fontSize: 14.sp)),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text("closeButton".tr(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 14.sp)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }

    // --- Logout Fonksiyonu ---
    Future<void> _signOut(BuildContext context) async {
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("auth_login_required_title".tr()),
          backgroundColor: Colors.grey,
        ),
      );
    }

    // --- Geçmiş Etkinlikler Kontrolü ---
    void _handleMyEventsClick(BuildContext context) {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_person_rounded,
                      color: const Color(0xFF1A202C),
                      size: 40.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    "auth_login_required_title".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "auth_login_required_desc".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            "cancel".tr(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (ctx) => const AuthScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A202C),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            "auth_login".tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const MyEventsScreen()));
      }
    }

    // Ortak Küçük Buton Tasarımı (Sol menü için)
    Widget buildMiniButton(
        {required IconData icon, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44.w,
          height: 44.w, // Kare olması için w kullanmak daha güvenli olabilir
          margin: EdgeInsets.only(bottom: 12.h), // Alt alta boşluk
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 22.sp),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- ÜST BAR (Sol: Menü, Sağ: Auth) ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Yukarı hizala
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // SOL TARAF: Dikey Menü (Dil, Info, Feedback)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Dil Seçimi
                      PopupMenuButton<String>(
                        offset: Offset(0, 40.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r)),
                        surfaceTintColor: Colors.white,
                        color: Colors.white,
                        onSelected: (String value) {
                          if (value == 'TR')
                            context.setLocale(const Locale('tr'));
                          else if (value == 'EN')
                            context.setLocale(const Locale('en'));
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                              value: 'TR',
                              child: Text('🇹🇷 Türkçe',
                                  style: TextStyle(fontSize: 14.sp))),
                          PopupMenuItem(
                              value: 'EN',
                              child: Text('🇬🇧 English',
                                  style: TextStyle(fontSize: 14.sp))),
                        ],
                        child: Container(
                          width: 44.w,
                          height: 44.w,
                          margin: EdgeInsets.only(bottom: 12.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.language,
                              color: const Color(0xFF4A5568), size: 22.sp),
                        ),
                      ),

                      // 2. Info Butonu
                      buildMiniButton(
                        icon: Icons.info_outline_rounded,
                        onTap: () => showInfoDialog(context),
                      ),

                      // 3. Feedback Butonu
                      buildMiniButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        onTap: () => _showFeedbackModal(context),
                      ),
                    ],
                  ),

                  // SAĞ TARAF: Auth (Login veya User+Logout)
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, authSnapshot) {
                      if (authSnapshot.hasData && authSnapshot.data != null) {
                        // --- GİRİŞ YAPILMIŞSA ---
                        final User user = authSnapshot.data!;

                        return Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30.r),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // --- KULLANICI ADINI ÇEKME ---
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .get(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData &&
                                      snapshot.data!.exists) {
                                    Map<String, dynamic> data = snapshot.data!
                                        .data() as Map<String, dynamic>;
                                    String username =
                                        data['username'] ?? 'User';

                                    return Padding(
                                      padding: EdgeInsets.only(
                                          left: 12.w, right: 8.w),
                                      child: Text(
                                        username,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    );
                                  }
                                  // Yüklenirken veya veri yoksa sadece ikon görünür
                                  return SizedBox(width: 8.w);
                                },
                              ),

                              // --- ÇIKIŞ BUTONU ---
                              GestureDetector(
                                onTap: () => _signOut(context),
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.logout_rounded,
                                      color: Colors.red.shade400, size: 20.sp),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        // --- GİRİŞ YAPILMAMIŞSA ---
                        return GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const AuthScreen())),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.w, vertical: 12.h),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20.r),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.login_rounded,
                                    color: Colors.white, size: 20.sp),
                                SizedBox(width: 8.w),
                                Text(
                                  "auth_login".tr(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),

              // --- LOGO ALANI (Biraz daha yukarı kaydı) ---
              SizedBox(height: 20.h),
              Center(
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 44.sp, // BÜYÜK FONT ÖLÇEKLENDİ
                          height: 1.2,
                          letterSpacing: -1.0,
                        ),
                        children: [
                          TextSpan(
                            text: 'Query',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const TextSpan(
                            text: 'Code',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Container(
                      width: 190.w, // LOGO BOYUTU ÖLÇEKLENDİ
                      height: 190.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.22),
                            blurRadius: 5,
                            spreadRadius: 8,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(20.r),
                      child: Image.asset('assets/images/logo4.png'),
                    ),
                    SizedBox(height: 32.h),
                    Text(
                      "homeTitle".tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24.sp,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // --- ANA BUTONLAR (Mevcut kod aynen korundu) ---
              ElevatedButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const CreateQuestionScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 26.sp),
                    SizedBox(width: 12.w),
                    Text(
                      "newQuestionButton".tr(),
                      style: TextStyle(
                          fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const QrScannerScreen())),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        side:
                            BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 24.sp),
                          SizedBox(width: 8.w),
                          Text(
                            "scanQRButton".tr(),
                            style: TextStyle(
                                fontSize: 16.sp, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: () => _handleMyEventsClick(context),
                    child: Container(
                      width: 64.w,
                      height: 64
                          .w, // Butonların yüksekliğiyle orantılı olması için h yerine w kullanılabilir veya tersi. 64.h
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: Icon(Icons.history_rounded,
                          color: primaryColor, size: 28.sp),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
