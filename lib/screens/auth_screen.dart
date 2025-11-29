import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore eklendi
import 'package:easy_localization/easy_localization.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form Verileri
  String _email = '';
  String _password = '';
  String _firstName = ''; // Yeni
  String _lastName = '';  // Yeni
  String _username = '';  // Yeni
  
  // UI Durumları
  bool _isLogin = true; 
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Renk Paleti
  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _primaryBlue = const Color(0xFF3182CE);
  final Color _backgroundColor = const Color(0xFFF4F7FB);

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- GİRİŞ YAP ---
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email,
          password: _password,
        );
      } else {
        // --- KAYIT OL ---
        // 1. Kullanıcıyı Firebase Auth'da oluştur
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

        // 2. Ekstra bilgileri Firestore'a kaydet
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'firstName': _firstName,
          'lastName': _lastName,
          'username': _username,
          'email': _email,
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user', // İleride admin vs. eklemek isterseniz
        });

        // 3. Firebase Auth profilindeki "Display Name"i güncelle (İsteğe bağlı ama önerilir)
        await userCredential.user!.updateDisplayName("$_firstName $_lastName");
      }

      // İşlem başarılıysa ekranı kapat
      if (mounted) Navigator.of(context).pop();

    } on FirebaseAuthException catch (e) {
  debugPrint("Firebase Auth Error Code: ${e.code}");
  String message = 'auth_error_generic'.tr(); // Varsayılan: Genel Hata

  if (e.code == 'user-not-found') {
    message = 'auth_register_required'.tr();
  } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
    message = 'auth_wrong_password'.tr();
  } else if (e.code == 'email-already-in-use') {
    message = 'auth_email_in_use'.tr(); // 🔥 Bu en sık karşılaşılan hatadır.
  } else if (e.code == 'weak-password') {
    message = 'auth_weak_password'.tr();
  } else if (e.code == 'invalid-email') {
    message = 'auth_email_invalid'.tr();
  } else if (e.code == 'channel-error') {
    // Genellikle mobil cihazda olmayan bir işlemi çağırmaktan kaynaklanır
    message = 'auth_channel_error'.tr(); 
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      // ...
    ),
  );
} catch (e) {
  // ⚡ Beklenmeyen diğer hatalar (Örn: İnternet bağlantısı yok, Firestore yazma hatası)
  ScaffoldMessenger.of(context).showSnackBar(
    // Artık generic olarak "Hata: $e" yerine kullanıcı dostu bir mesaj gösteriyoruz.
    SnackBar(
      content: Text("auth_unexpected_error".tr()),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // --- 1. ANA İÇERİK ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logo4.png',
                      height: 80, // Logo biraz küçültüldü, form uzadığı için yer açtık
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.qr_code_2, size: 80, color: _primaryBlue);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Başlıklar
                  Text(
                    _isLogin ? "auth_welcome".tr() : "auth_create_account".tr(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin 
                      ? "auth_welcome_sub".tr()
                      : "auth_create_sub".tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // --- SADECE KAYIT EKRANINDA GÖRÜNEN ALANLAR ---
                        if (!_isLogin) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernInput(
                                  label: 'auth_name'.tr(), // Çeviri anahtarı ekleyin
                                  icon: Icons.person_outline,
                                  onSaved: (value) => _firstName = value!.trim(),
                                  validator: (value) {
                                    if (value == null || value.length < 2) return 'Gerekli';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModernInput(
                                  label: 'auth_surname'.tr(),
                                  icon: Icons.person_outline,
                                  onSaved: (value) => _lastName = value!.trim(),
                                  validator: (value) {
                                    if (value == null || value.length < 2) return 'Gerekli';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildModernInput(
                            label: 'auth_username'.tr(),
                            icon: Icons.alternate_email,
                            onSaved: (value) => _username = value!.trim(),
                            validator: (value) {
                              if (value == null || value.length < 3) return 'En az 3 karakter';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        
                        // --- ORTAK ALANLAR (EMAIL & PASSWORD) ---
                        _buildModernInput(
                          label: 'auth_email'.tr(),
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          onSaved: (value) => _email = value!.trim(),
                          validator: (value) {
                            if (value == null || !value.contains('@')) {
                              return 'auth_email_invalid'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildModernInput(
                          label: 'auth_password'.tr(),
                          icon: Icons.lock_outline,
                          obscureText: !_isPasswordVisible,
                          isPassword: true,
                          onSaved: (value) => _password = value!.trim(),
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'auth_password_min'.tr();
                            }
                            return null;
                          },
                          onToggleVisibility: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        if (_isLoading)
                          CircularProgressIndicator(color: _primaryBlue)
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
                                  elevation: 2,
                                  shadowColor: _primaryColor.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _isLogin ? 'auth_login'.tr() : 'auth_register'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isLogin
                                        ? "auth_no_account_text".tr()
                                        : "auth_have_account_text".tr(),
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isLogin = !_isLogin;
                                        _formKey.currentState?.reset();
                                      });
                                    },
                                    child: Text(
                                      _isLogin
                                          ? 'auth_register'.tr()
                                          : 'auth_login'.tr(),
                                      style: TextStyle(
                                        color: _primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. GERİ DÖN BUTONU ---
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: InkWell(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _primaryColor,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Input Widget
  Widget _buildModernInput({
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType? keyboardType,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
    VoidCallback? onToggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(icon, color: Colors.grey[400]),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400],
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }
}