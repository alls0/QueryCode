import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Diğer ekranları import ediyoruz
import 'screens/home_screen.dart';
import 'screens/web_answering_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dil paketini başlat
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Uygulamayı EasyLocalization ile sarmala
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations', // Çeviri dosyalarının yolu
      fallbackLocale: const Locale('tr'), // Bulamazsa varsayılan dil
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cihazın ekran genişliğini alıyoruz
        final double screenWidth = constraints.maxWidth;

        // --- AKILLI EKRAN AYARI ---
        Size designSize;

        if (screenWidth < 600) {
          // TELEFONLAR İÇİN (Senin referansın)
          // Bu boyuttaki cihazlarda tasarım aynen korunur.
          designSize = const Size(411, 914);
        } else {
          // TABLETLER VE BÜYÜK EKRANLAR İÇİN
          // Tabletler için daha geniş bir referans veriyoruz (Örn: iPad Pro 11")
          // Bu sayede ScreenUtil, "Ekran büyüdü, her şeyi devasa yapayım" demez.
          // Yazılar ve butonlar tablet ekranına uygun, zarif bir boyutta kalır.
          designSize = const Size(834, 1194);
        }

        return ScreenUtilInit(
          designSize: designSize, // Hesaplanan dinamik boyut
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'QueryCode',

              // Dil ayarlarını MaterialApp'e bildir
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,

              theme: ThemeData(
                scaffoldBackgroundColor: const Color(0xFFF4F7FB),

                // --- FONT AYARLARI (OUTFIT) ---
                textTheme: GoogleFonts.outfitTextTheme(
                  Theme.of(context).textTheme,
                ),
                fontFamily: GoogleFonts.outfit().fontFamily,
                // -----------------------------
              ),

              // Web yönlendirme mantığı
              home: _getInitialScreen(),
            );
          },
        );
      },
    );
  }

  Widget _getInitialScreen() {
    if (kIsWeb) {
      final uri = Uri.base;
      final path = uri.path;

      // 1. ADIM: /event/ID yolu kontrol edilir
      if (path.startsWith('/event/')) {
        final eventId = path.substring('/event/'.length);
        if (eventId.isNotEmpty) {
          return WebAnsweringScreen(eventId: eventId);
        }
      }

      // 2. ADIM: Eğer yol /event/ID değilse, ana ekranı yükle.
      return const HomeScreen();
    }

    // Mobil platformlar için
    return const HomeScreen();
  }
}
