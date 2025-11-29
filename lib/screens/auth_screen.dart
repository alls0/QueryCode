import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  bool _isLogin = true; // Giriş modu mu, Kayıt modu mu?
  bool _isLoading = false;

  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _primaryBlue = const Color(0xFF3182CE);

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Giriş Yap
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      } else {
        // Kayıt Ol
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      }
      // Başarılı olursa ekranı kapat (Home'a dön)
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      // Hata kodunu konsola yazdır (Geliştirme aşamasında sorunu görmek için)
      debugPrint("Firebase Auth Error Code: ${e.code}");

      String message =
          'auth_error_generic'.tr(); // Varsayılan: "Bir hata oluştu."

      // --- İSTEDİĞİNİZ ÖZEL HATA MEKANİZMASI ---
      if (e.code == 'user-not-found') {
        // Eğer kullanıcı veritabanında yoksa bu özel mesaj gösterilecek
        message = 'auth_register_required'.tr();
      }
      // ----------------------------------------
      else if (e.code == 'wrong-password') {
        message = 'auth_wrong_password'.tr();
      } else if (e.code == 'invalid-credential') {
        // Firebase bazen güvenlik nedeniyle user-not-found yerine bunu döndürebilir
        // Bu durumda da kayıt uyarısı veya genel hata verebilirsiniz.
        message = 'auth_wrong_password'.tr();
      } else if (e.code == 'email-already-in-use') {
        message = 'auth_email_in_use'.tr();
      } else if (e.code == 'weak-password') {
        message = 'auth_weak_password'.tr();
      } else if (e.code == 'invalid-email') {
        message = 'auth_email_invalid'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4), // Uyarı biraz daha uzun kalsın
          action: SnackBarAction(
            label: _isLogin ? 'auth_register'.tr() : 'Tamam',
            textColor: Colors.white,
            onPressed: () {
              if (_isLogin) {
                // Kullanıcı "Kayıt Ol" butonuna basarsa formu değiştir
                setState(() {
                  _isLogin = false;
                });
              }
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_isLogin ? 'auth_login'.tr() : 'auth_register'.tr()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _primaryColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isLogin
                          ? "auth_welcome".tr()
                          : "auth_create_account".tr(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('email'),
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'auth_email'.tr(),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return 'auth_email_invalid'.tr();
                        }
                        return null;
                      },
                      onSaved: (value) => _email = value!.trim(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('password'),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'auth_password'.tr(),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'auth_password_min'.tr();
                        }
                        return null;
                      },
                      onSaved: (value) => _password = value!.trim(),
                    ),
                    const SizedBox(height: 24),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(_isLogin
                                ? 'auth_login'.tr()
                                : 'auth_register'.tr()),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            child: Text(
                              _isLogin
                                  ? 'auth_no_account'.tr()
                                  : 'auth_have_account'.tr(),
                              style: TextStyle(color: _primaryBlue),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
