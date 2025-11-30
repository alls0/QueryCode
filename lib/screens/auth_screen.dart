import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_sign_in/google_sign_in.dart'; // <-- EKLENDİ

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
  String _firstName = '';
  String _lastName = '';
  String _username = '';

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
        final userCredential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
        );

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
          'role': 'user',
        });

        await userCredential.user!.updateDisplayName("$_firstName $_lastName");
      }

      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error Code: ${e.code}");
      String message = 'auth_error_generic'.tr();

      if (e.code == 'user-not-found') {
        message = 'auth_register_required'.tr();
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'auth_wrong_password'.tr();
      } else if (e.code == 'email-already-in-use') {
        message = 'auth_email_in_use'.tr();
      } else if (e.code == 'weak-password') {
        message = 'auth_weak_password'.tr();
      } else if (e.code == 'invalid-email') {
        message = 'auth_email_invalid'.tr();
      } else if (e.code == 'channel-error') {
        message = 'auth_channel_error'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(fontSize: 14.sp)), // .sp
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("auth_unexpected_error".tr(),
              style: TextStyle(fontSize: 14.sp)), // .sp
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.r)), // .r
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ŞİFREMİ UNUTTUM METODU (Önceki Adımdan Restore Edildi)
  Future<void> _forgotPassword() async {
    _formKey.currentState!.save();

    if (_email.isEmpty || !_email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth_email_invalid'.tr(),
              style: TextStyle(fontSize: 14.sp)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('auth_password_reset_sent'.tr(),
                style: TextStyle(fontSize: 14.sp)),
            backgroundColor: _primaryBlue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Firebase Auth Error Code (Password Reset): ${e.code}");
      String message = 'auth_error_generic'.tr();

      if (e.code == 'invalid-email' || e.code == 'user-not-found') {
        message = 'auth_password_reset_error'.tr();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: TextStyle(fontSize: 14.sp)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("auth_unexpected_error".tr(),
                style: TextStyle(fontSize: 14.sp)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // GOOGLE İLE GİRİŞ METODU (Önceki Adımdan Restore Edildi)
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.additionalUserInfo!.isNewUser) {
        final username = userCredential.user!.email?.split('@').first ?? 'user';
        final nameParts = googleUser.displayName?.split(' ') ?? [];
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1 ? nameParts.last : '';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'firstName': firstName,
          'lastName': lastName,
          'username': username,
          'email': userCredential.user!.email,
          'uid': userCredential.user!.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'user',
        });
      }

      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      debugPrint("Google Auth Error Code: ${e.code}");
      String message = 'auth_google_error'.tr();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(fontSize: 14.sp)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
    } catch (e) {
      debugPrint("Unexpected Google Sign-in Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("auth_unexpected_error".tr(),
              style: TextStyle(fontSize: 14.sp)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // YENİ WIDGET: Google Giriş Butonunu Oluşturur
  Widget _buildGoogleSignInButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signInWithGoogle,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/google_logo.png', // Lütfen bu dosya yolunun doğru olduğundan emin olun
            height: 20.h,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.g_mobiledata, color: Colors.red);
            },
          ),
          SizedBox(width: 10.w),
          Text(
            'auth_login_google'.tr(),
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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
              padding: EdgeInsets.symmetric(
                  horizontal: 24.w, vertical: 40.h), // .w .h
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/logo4.png',
                      height: 140.h, // .h
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.qr_code_2,
                            size: 80.sp, color: _primaryBlue); // .sp
                      },
                    ),
                  ),
                  SizedBox(height: 20.h), // .h

                  // Başlıklar
                  Text(
                    _isLogin ? "auth_welcome".tr() : "auth_create_account".tr(),
                    style: TextStyle(
                      fontSize: 26.sp, // .sp
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8.h), // .h
                  Text(
                    _isLogin ? "auth_welcome_sub".tr() : "auth_create_sub".tr(),
                    style: TextStyle(
                      fontSize: 14.sp, // .sp
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 24.h), // .h

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
                                  label: 'auth_name'.tr(),
                                  icon: Icons.person_outline,
                                  onSaved: (value) =>
                                      _firstName = value!.trim(),
                                  validator: (value) {
                                    if (value == null || value.length < 2)
                                      return 'Gerekli';
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 12.w), // .w
                              Expanded(
                                child: _buildModernInput(
                                  label: 'auth_surname'.tr(),
                                  icon: Icons.person_outline,
                                  onSaved: (value) => _lastName = value!.trim(),
                                  validator: (value) {
                                    if (value == null || value.length < 2)
                                      return 'Gerekli';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h), // .h
                          _buildModernInput(
                            label: 'auth_username'.tr(),
                            icon: Icons.alternate_email,
                            onSaved: (value) => _username = value!.trim(),
                            validator: (value) {
                              if (value == null || value.length < 3)
                                return 'En az 3 karakter';
                              return null;
                            },
                          ),
                          SizedBox(height: 12.h), // .h
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
                        SizedBox(height: 12.h), // .h
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

                        // Şifremi Unuttum Butonu (Eski Tasarıma uygun olarak yerleştirildi)
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _forgotPassword,
                              child: Text(
                                'auth_forgot_password'.tr(),
                                style: TextStyle(
                                  color: _primaryBlue,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp, // .sp
                                ),
                              ),
                            ),
                          ),

                        SizedBox(height: 16.h), // Aralığı ayarlamak için

                        if (_isLoading)
                          CircularProgressIndicator(color: _primaryBlue)
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // E-posta/Şifre Giriş Butonu
                              ElevatedButton(
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      vertical: 16.h), // .h
                                  elevation: 2,
                                  shadowColor: _primaryColor.withOpacity(0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16.r), // .r
                                  ),
                                ),
                                child: Text(
                                  _isLogin
                                      ? 'auth_login'.tr()
                                      : 'auth_register'.tr(),
                                  style: TextStyle(
                                      fontSize: 16.sp, // .sp
                                      fontWeight: FontWeight.bold),
                                ),
                              ),

                              // YENİ: Google İle Giriş Butonu
                              if (_isLogin) ...[
                                SizedBox(height: 16.h),
                                _buildGoogleSignInButton(),
                              ],

                              SizedBox(height: 16.h), // .h
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isLogin
                                        ? "auth_no_account_text".tr()
                                        : "auth_have_account_text".tr(),
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14.sp), // .sp
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
                                        fontSize: 14.sp, // .sp
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
                padding: EdgeInsets.all(12.0.r), // .r
                child: InkWell(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  borderRadius: BorderRadius.circular(12.r), // .r
                  child: Container(
                    padding: EdgeInsets.all(10.r), // .r
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r), // .r
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10.r, // .r
                          offset: Offset(0, 2.h), // .h
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _primaryColor,
                      size: 22.sp, // .sp
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

  // Modern Input Widget (Orjinal Tasarım Korundu)
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
        borderRadius: BorderRadius.circular(16.r), // .r
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r, // .r
            offset: Offset(0, 4.h), // .h
          ),
        ],
      ),
      child: TextFormField(
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16.sp), // .sp
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(color: Colors.grey[500], fontSize: 14.sp), // .sp
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 24.sp), // .sp
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400],
                    size: 24.sp, // .sp
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.r), // .r
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h), // .w .h
        ),
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }
}
