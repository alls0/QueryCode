import 'package:flutter/material.dart';
import 'create_question_screen.dart';
import 'qr_scanner_screen.dart';
import 'my_events_screen.dart';
import 'package:easy_localization/easy_localization.dart'; // YENİ: Paketi import et

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF2D3748);

    void showInfoDialog(BuildContext context) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: accentColor),
                const SizedBox(width: 10),
                // YENİ: Metni çeviriden al
                Text("infoTitle".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text("infoP1".tr()),
                  const SizedBox(height: 20),
                  Text("infoP2".tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Text("infoP3".tr()),
                  Text("infoP4".tr()),
                  const SizedBox(height: 20),
                  Text("infoP5".tr(),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(),
                  Text("infoP6".tr()),
                  Text("infoP7".tr()),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                // YENİ: Metni çeviriden al
                child: Text("closeButton".tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }

    return Scaffold(
      body: Container(
        // Arka planınız aynı kaldı
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(192, 58, 142, 202),
              Color.fromARGB(255, 219, 225, 232),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 25),
                    // Logo ve ışıma efektiniz aynı kaldı
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 181, 221, 239)
                                .withOpacity(0.5),
                            blurRadius: 45,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                      child: Image.asset('assets/images/logo.png',
                          width: 150, height: 150),
                    ),
                    const SizedBox(height: 20),
                    // YENİ: Metni çeviriden al
                    Text(
                      "homeTitle".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                        shadowColor: accentColor.withAlpha(43),
                      ),
                      icon: const Icon(Icons.add, size: 24),
                      // YENİ: Metni çeviriden al
                      label: Text(
                        "newQuestionButton".tr(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateQuestionScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.9),
                        foregroundColor: accentColor,
                        minimumSize: const Size(double.infinity, 60),
                        side: const BorderSide(color: accentColor, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 24),
                      // YENİ: Metni çeviriden al
                      label: Text(
                        "scanQRButton".tr(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const QrScannerScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: accentColor,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      icon: const Icon(Icons.history, size: 24),
                      // YENİ: Metni çeviriden al
                      label: Text(
                        "myEventsButton".tr(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const MyEventsScreen()),
                        );
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    PopupMenuButton<String>(
                      offset: const Offset(0, -120),
                      // YENİ: Dil değiştirme işlevi eklendi
                      onSelected: (String value) {
                        if (value == 'TR') {
                          context.setLocale(const Locale('tr'));
                        } else if (value == 'EN') {
                          context.setLocale(const Locale('en'));
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'TR',
                          child: Text('🇹🇷  Türkçe'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'EN',
                          child: Text('🇬🇧  English'),
                        ),
                      ],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 12.0),
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
                        child: Row(
                          children: [
                            const Icon(Icons.language,
                                color: accentColor, size: 22),
                            const SizedBox(width: 6),
                            // YENİ: Metni çeviriden al
                            Text("language".tr(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: accentColor)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down,
                                color: accentColor),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => showInfoDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(18),
                              blurRadius: 10,
                              offset: const Offset(2, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.info_outline,
                            color: accentColor, size: 22),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
