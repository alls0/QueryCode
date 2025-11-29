import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_question_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_events_screen.dart';
import 'auth_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';

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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryDark,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey.shade400),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text("feedback_subject".tr(),
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: primaryDark)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: feedbackTypes.map((type) {
                        bool isSelected = selectedType == type;
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          selectedColor: primaryBlue.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: isSelected ? primaryBlue : Colors.grey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: bgLight,
                          side: BorderSide(
                            color:
                                isSelected ? primaryBlue : Colors.transparent,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          onSelected: (bool selected) {
                            if (selected) {
                              setModalState(() => selectedType = type);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: feedbackController,
                      maxLength: 500,
                      maxLines: 4,
                      onChanged: (val) {
                        if (inputErrorText != null) {
                          setModalState(() => inputErrorText = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: "feedback_placeholder".tr(),
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: bgLight,
                        errorText: inputErrorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: primaryBlue, width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: Colors.red.shade300, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                        child: Text(
                            selectedRating > 0
                                ? "$selectedRating ${"feedback_stars".tr()}"
                                : "feedback_rate".tr(),
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 12))),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < selectedRating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 36,
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                "feedback_send".tr(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: primaryColor),
                const SizedBox(width: 12),
                Text("infoTitle".tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text("infoP1".tr(), style: const TextStyle(color: iconColor)),
                  const SizedBox(height: 16),
                  Text("infoP2".tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: textColor)),
                  Divider(color: Colors.grey.shade200),
                  Text("infoP3".tr(), style: const TextStyle(color: iconColor)),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text("closeButton".tr(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: primaryColor)),
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
          content: Text("auth_login_required_title"
              .tr()), // "Giriş yapmalısınız" yerine "Çıkış yapıldı" mesajı verilebilir veya bu text generic kullanılabilir
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
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
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      color: Color(0xFF1A202C),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "auth_login_required_title".tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "auth_login_required_desc".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "cancel".tr(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "auth_login".tr(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
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
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(bottom: 12), // Alt alta boşluk
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
          child: Icon(icon, color: iconColor, size: 22),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        surfaceTintColor: Colors.white,
                        color: Colors.white,
                        onSelected: (String value) {
                          if (value == 'TR')
                            context.setLocale(const Locale('tr'));
                          else if (value == 'EN')
                            context.setLocale(const Locale('en'));
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'TR', child: Text('🇹🇷 Türkçe')),
                          const PopupMenuItem(
                              value: 'EN', child: Text('🇬🇧 English')),
                        ],
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(bottom: 12),
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
                          child: const Icon(Icons.language,
                              color: Color(0xFF4A5568), size: 22),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
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
                                      padding: const EdgeInsets.only(
                                          left: 12, right: 8),
                                      child: Text(
                                        username,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                          fontSize: 15,
                                        ),
                                      ),
                                    );
                                  }
                                  // Yüklenirken veya veri yoksa sadece ikon görünür
                                  return const SizedBox(width: 8);
                                },
                              ),

                              // --- ÇIKIŞ BUTONU ---
                              GestureDetector(
                                onTap: () => _signOut(context),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.logout_rounded,
                                      color: Colors.red.shade400, size: 20),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
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
                                const Icon(Icons.login_rounded,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "auth_login".tr(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
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
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.outfit(
                          fontSize: 44,
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
                    const SizedBox(height: 20),
                    Container(
                      width: 190,
                      height: 190,
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
                      padding: const EdgeInsets.all(20),
                      child: Image.asset('assets/images/logo4.png'),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "homeTitle".tr(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 24,
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
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 26),
                    const SizedBox(width: 12),
                    Text(
                      "newQuestionButton".tr(),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side:
                            BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "scanQRButton".tr(),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _handleMyEventsClick(context),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: primaryColor, size: 28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
