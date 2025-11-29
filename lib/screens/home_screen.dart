import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // EKLENDİ
import 'create_question_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_events_screen.dart';
import 'auth_screen.dart'; // EKLENDİ
import 'package:easy_localization/easy_localization.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // --- Geri Bildirim Modal (Mevcut kod aynen korundu) ---
  void _showFeedbackModal(BuildContext context) {
    // Tasarım Renkleri
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
                                  // Eğer kullanıcı giriş yapmışsa ID'sini de ekleyelim
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
                                    'userId': user?.uid, // Opsiyonel
                                    'userEmail': user?.email, // Opsiyonel
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

    // --- LOGOUT FONKSİYONU ---
    Future<void> _signOut(BuildContext context) async {
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Çıkış yapıldı")),
      );
    }

    // --- GEÇMİŞ KONTROLÜ ---
  // --- GEÇMİŞ KONTROLÜ (MODERN TASARIM) ---
    void _handleMyEventsClick(BuildContext context) {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // Kullanıcı giriş yapmamışsa -> MODERN DIALOG GÖSTER
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent, // Arkaplanı şeffaf yapıyoruz ki kendi şeklimizi verelim
            insetPadding: const EdgeInsets.symmetric(horizontal: 24), // Kenar boşlukları
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24), // Yuvarlak köşeler
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // İçerik kadar yer kapla
                children: [
                  // 1. İKON ALANI
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded, // Kilitli kişi ikonu
                      color: const Color(0xFF1A202C), // Primary Blue
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. BAŞLIK
                  Text(
                    "auth_login_required_title".tr(), // "Giriş Yapmalısınız"
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A202C), // Primary Dark
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. AÇIKLAMA
                  Text(
                    "auth_login_required_desc".tr(), // "Bu özelliği kullanmak için..."
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5, // Satır arası boşluk okunabilirlik için
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. BUTONLAR (YAN YANA)
                  Row(
                    children: [
                      // Vazgeç Butonu
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
                      
                      // Giriş Yap Butonu
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (ctx) => const AuthScreen()),
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
        // Kullanıcı giriş yapmışsa
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const MyEventsScreen()));
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- ÜST BAR (Dil, Feedback, Info, AUTH) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sol Taraf: Dil Seçimi
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.language,
                              color: iconColor, size: 20),
                          const SizedBox(width: 8),
                          Text("language".tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: iconColor, size: 18),
                        ],
                      ),
                    ),
                  ),

                  // Sağ Taraf: İkonlar Grubu
                  Row(
                    children: [
                      // Feedback
                      GestureDetector(
                        onTap: () => _showFeedbackModal(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded,
                              color: iconColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Info
                      GestureDetector(
                        onTap: () => showInfoDialog(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Icon(Icons.info_outline_rounded,
                              color: iconColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // --- AUTH DURUMUNA GÖRE İKON ---
                      StreamBuilder<User?>(
                        stream: FirebaseAuth.instance.authStateChanges(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            // Giriş yapılmış: Çıkış butonu (veya profil)
                            return GestureDetector(
                              onTap: () => _signOut(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.red.shade100),
                                ),
                                child: Icon(Icons.logout_rounded,
                                    color: Colors.red.shade400, size: 24),
                              ),
                            );
                          } else {
                            // Giriş yapılmamış: Giriş butonu
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const AuthScreen())),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor, // Koyu renk
                                  shape: BoxShape.circle,
                                  border: Border.all(color: primaryColor),
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 24),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 50),

              // --- LOGO ALANI ---
              Center(
                child: Column(
                  children: [
                    const Text(
                      "Query Code",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color.fromARGB(255, 255, 255, 255),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 109, 107, 107)
                                .withOpacity(0.22),
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
                      style: const TextStyle(
                        fontSize: 24,
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // --- ANA BUTONLAR ---
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

                  // --- HISTORY BUTONU GÜNCELLENDİ ---
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
