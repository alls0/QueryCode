import 'package:flutter/material.dart';
import 'create_question_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_events_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- YENİ RENK PALETİ ---
    const Color primaryColor = Color(0xFF1A202C); // Koyu Antrasit (Neredeyse Siyah)
    const Color cardColor = Colors.white;
    const Color backgroundColor = Color(0xFFF8FAFC); // Çok Açık Gri Zemin
    const Color textColor = Color(0xFF2D3748);
    const Color iconColor = Color(0xFF4A5568);

    // Bilgi Diyaloğu (Aynı mantık, sadece renkler güncellendi)
    void showInfoDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: cardColor,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: primaryColor),
                const SizedBox(width: 12),
                Text("infoTitle".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text("infoP1".tr(), style: const TextStyle(color: iconColor)),
                  const SizedBox(height: 16),
                  Text("infoP2".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  Divider(color: Colors.grey.shade200),
                  Text("infoP3".tr(), style: const TextStyle(color: iconColor)),
                  // ... Diğer metinler
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text("closeButton".tr(), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor, // Mavi gradyan yerine sade zemin
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- ÜST BAR (Dil ve Bilgi) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Dil Seçimi (Daha minimal)
                  PopupMenuButton<String>(
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    surfaceTintColor: Colors.white,
                    color: Colors.white,
                    onSelected: (String value) {
                      if (value == 'TR') context.setLocale(const Locale('tr'));
                      else if (value == 'EN') context.setLocale(const Locale('en'));
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'TR', child: Text('🇹🇷 Türkçe')),
                      const PopupMenuItem(value: 'EN', child: Text('🇬🇧 English')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.language, color: iconColor, size: 20),
                          const SizedBox(width: 8),
                          Text("language".tr(), style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, color: iconColor, size: 18),
                        ],
                      ),
                    ),
                  ),

                  // Bilgi Butonu
                  GestureDetector(
                    onTap: () => showInfoDialog(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(Icons.info_outline_rounded, color: iconColor, size: 24),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // --- LOGO ALANI ---
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white, // Logonun arkasına temiz beyaz zemin
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20), // Logoya biraz nefes payı
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0,      0,      0,      1, 0,
                        ]),
                        child: Image.asset('assets/images/logo.png'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "homeTitle".tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24, // Başlık büyütüldü
                        color: primaryColor,
                        fontWeight: FontWeight.w800, // Daha kalın
                        letterSpacing: -0.5, // Modern sıkı harf aralığı
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Hızlıca anket oluştur veya katıl", // İsterseniz buraya bir slogan ekleyebilirsiniz
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: iconColor),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // --- ANA BUTONLAR (Modern Kartlar) ---
              
              // 1. Yeni Soru Oluştur (En Büyük Vurgu)
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateQuestionScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  elevation: 0, // Flat tasarım
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, size: 26),
                    const SizedBox(width: 12),
                    Text(
                      "newQuestionButton".tr(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. QR Tara (İkincil Stil)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const QrScannerScreen())),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_rounded, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            "scanQRButton".tr(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 3. Geçmiş (Küçük Kare Buton - Yanına)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyEventsScreen())),
                    child: Container(
                      width: 64, // Kare şekil
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: const Icon(Icons.history_rounded, color: primaryColor, size: 28),
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