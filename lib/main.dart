import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart';
import 'package:google_fonts/google_fonts.dart'; // Font paketi eklendi

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
        // Uygulamanın tüm metin stillerini Outfit yapıyoruz
        textTheme: GoogleFonts.outfitTextTheme(
          Theme.of(context).textTheme,
        ),
        
        // Bazı widget'lar (örn. AppBar) textTheme yerine fontFamily kullanır,
        // garanti olması için bunu da ekliyoruz.
        fontFamily: GoogleFonts.outfit().fontFamily,
        // -----------------------------
      ),

      // Web yönlendirme mantığı
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (kIsWeb) {
      final uri = Uri.base;
      // print('Tarayıcı URI tespit edildi: $uri'); // Gerekirse debug için açılabilir

      final path = uri.path;
      // print('Path yolu: $path');

      // 1. ADIM: /event/ID yolu kontrol edilir
      if (path.startsWith('/event/')) {
        final eventId = path.substring('/event/'.length);
        if (eventId.isNotEmpty) {
          // print('Etkinlik ID bulundu: $eventId. WebAnsweringScreen yükleniyor.');
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