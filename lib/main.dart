import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:easy_localization/easy_localization.dart'; // YENİ: Paketi import et

// Diğer ekranları import ediyoruz
import 'screens/home_screen.dart';
import 'screens/web_answering_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // YENİ: Dil paketini başlat
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // YENİ: Uygulamayı EasyLocalization ile sarmala
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

      // YENİ: Dil ayarlarını MaterialApp'e bildir
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        fontFamily: 'Roboto',
      ),

      // Mevcut web yönlendirme mantığınızı koruyoruz
      home: _getInitialScreen(),
    );
  }

  // Bu fonksiyona hiç dokunmadık, olduğu gibi çalışmaya devam ediyor
  // Dosya: lib/main.dart
// MEVCUT _getInitialScreen() FONKSİYONUNUN TAMAMINI DEĞİŞTİR:

  Widget _getInitialScreen() {
    if (kIsWeb) {
      final uri = Uri.base;
      print('Tarayıcı URI tespit edildi: $uri');

      final path = uri.path;
      print('Path yolu: $path');

      // 1. ADIM: /event/ID yolu kontrol edilir
      if (path.startsWith('/event/')) {
        final eventId = path.substring('/event/'.length);
        if (eventId.isNotEmpty) {
          print(
              'Etkinlik ID bulundu: $eventId. WebAnsweringScreen yükleniyor.');
          return WebAnsweringScreen(eventId: eventId);
        }
      }

      // 2. ADIM (FIX): Eğer yol /event/ID değilse (yani / ise),
      // direkt olarak mobil uygulamanın ana ekranını (HomeScreen) yükle.
      print(
          'Geçerli etkinlik yolu bulunamadı. Varsayılan Ana Ekran (HomeScreen) yükleniyor.');
      return const HomeScreen();
    }
    // Mobil platformlar için eski mantık aynı kalır
    return const HomeScreen();
  }
}
