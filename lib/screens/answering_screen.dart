import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'thank_you_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // <-- EKLENDİ

class AnsweringScreen extends StatefulWidget {
  final String eventId;
  final String? nickname;

  const AnsweringScreen({
    super.key,
    required this.eventId,
    this.nickname,
  });

  @override
  State<AnsweringScreen> createState() => _AnsweringScreenState();
}

class _AnsweringScreenState extends State<AnsweringScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _questions = [];
  int _currentQuestionIndex = 0;

  String? _selectedAnswer;
  final TextEditingController _otherAnswerController = TextEditingController();
  static const String _otherOptionKey = '__OTHER_OPTION_SELECTED__';

  final List<Map<String, String>> _userAnswers = [];
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  String? _deviceId;

  // --- RENK PALETİ ---
  final Color _primaryColor = const Color(0xFF1A202C); // Koyu Lacivert
  final Color _secondaryColor = const Color(0xFF718096); // Gri
  final Color _bgColor = const Color(0xFFF8FAFC); // Açık Arka Plan
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  @override
  void dispose() {
    _mediaPageController.dispose();
    _otherAnswerController.dispose();
    super.dispose();
  }

  Future<void> _fetchEventData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_unique_id');

      if (_deviceId == null) {
        _deviceId = const Uuid().v4();
        await prefs.setString('device_unique_id', _deviceId!);
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;

        final Timestamp? startTs = data['startTime'];
        final Timestamp? endTs = data['endTime'];

        if (startTs != null && endTs != null) {
          final DateTime now = DateTime.now();
          final DateTime start = startTs.toDate();
          final DateTime end = endTs.toDate();
          final DateFormat formatter =
              DateFormat('dd MMM HH:mm', context.locale.toString());

          if (now.isBefore(start)) {
            setState(() {
              _errorMessage = "answer_event_not_started"
                  .tr(namedArgs: {'date': formatter.format(start)});
              _isLoading = false;
            });
            return;
          }

          if (now.isAfter(end)) {
            setState(() {
              _errorMessage = "answer_event_ended"
                  .tr(namedArgs: {'date': formatter.format(end)});
              _isLoading = false;
            });
            return;
          }
        }

        final List<dynamic> votedDevices = data['votedDevices'] ?? [];
        if (votedDevices.contains(_deviceId)) {
          setState(() {
            _errorMessage = "answer_already_voted".tr();
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _questions = data['questions'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "answer_error_not_found".tr();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "answer_error_fetch".tr();
        _isLoading = false;
      });
    }
  }

  void _submitAndGoToNext() async {
    String finalAnswer = _selectedAnswer == _otherOptionKey
        ? _otherAnswerController.text.trim()
        : _selectedAnswer!;

    if (finalAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("answer_enter_answer".tr(),
              style: TextStyle(fontSize: 14.sp)), // .sp EKLENDİ
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': finalAnswer,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      // --- SONUÇLARI GÖNDER ---
      setState(() => _isLoading = true);

      try {
        final String respondentName = widget.nickname?.trim() ??
            'Anonim_${DateTime.now().millisecondsSinceEpoch}';

        final eventRef =
            FirebaseFirestore.instance.collection('events').doc(widget.eventId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(eventRef);
          if (!snapshot.exists) throw Exception("Event not found");

          final data = snapshot.data() as Map<String, dynamic>;
          final List<dynamic> votedDevices = data['votedDevices'] ?? [];

          if (votedDevices.contains(_deviceId)) {
            throw Exception("Already voted");
          }

          transaction.update(eventRef, {
            'results.$respondentName': _userAnswers,
            'votedDevices': FieldValue.arrayUnion([_deviceId])
          });
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ThankYouScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = "answer_error_submit".tr();
          if (e.toString().contains("Already voted")) {
            errorMsg = "answer_already_voted".tr();
          }

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(errorMsg, style: TextStyle(fontSize: 14.sp)),
              backgroundColor: Colors.red));

          if (e.toString().contains("Already voted")) {
            setState(() {
              _errorMessage = "answer_already_voted".tr();
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      }
    } else {
      // --- SONRAKİ SORUYA GEÇ ---
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _otherAnswerController.clear();
        _currentMediaIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Progress değerini hesapla (0.0 ile 1.0 arası)
    double progress = _questions.isEmpty
        ? 0
        : (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: _bgColor,
      // --- 1. MODERN APP BAR & LOGO ---
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Hero(
          tag: 'app_logo',
          child: Image.asset(
            'assets/images/logo4.png',
            height: 40.h, // .h EKLENDİ (Logo boyutu)
            errorBuilder: (c, o, s) => Icon(Icons.qr_code_2,
                color: _primaryColor, size: 30.sp), // .sp EKLENDİ
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(6.0.h), // .h EKLENDİ
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0.w), // .w EKLENDİ
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.r), // .r EKLENDİ
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: _primaryColor, // Uygulamanın ana rengi
                minHeight: 6.h, // .h EKLENDİ
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildQuestionContent(),
    );
  }

  // Hata Ekranı
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.0.r), // .r EKLENDİ
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r), // .r EKLENDİ
              decoration: BoxDecoration(
                  color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.info_outline_rounded,
                  size: 48.sp, color: Colors.orange.shade700), // .sp EKLENDİ
            ),
            SizedBox(height: 24.h), // .h EKLENDİ
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _primaryColor,
                  fontSize: 16.sp, // .sp EKLENDİ
                  fontWeight: FontWeight.w600,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // Soru İçeriği (Animasyonlu)
  Widget _buildQuestionContent() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final rawAttachments =
        currentQuestion['attachments'] as List<dynamic>? ?? [];
    final bool allowOpenEnded = currentQuestion['allowOpenEnded'] ?? false;
    List<dynamic> options = [];
    if (currentQuestion['options'] != null) {
      options = List.from(currentQuestion['options']);
    }

    // AnimatedSwitcher ile sorular arası yumuşak geçiş
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: SingleChildScrollView(
        // Key kullanarak AnimatedSwitcher'ın değişimi algılamasını sağlıyoruz
        key: ValueKey<int>(_currentQuestionIndex),
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 40.h), // .w .h EKLENDİ
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Soru Sayacı
            Text(
              "${"answer_title_prefix".tr()} ${_currentQuestionIndex + 1}/${_questions.length}",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _secondaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp, // .sp EKLENDİ
                  letterSpacing: 1.0),
            ),
            SizedBox(height: 12.h), // .h EKLENDİ

            // Soru Metni Kartı
            Container(
              padding: EdgeInsets.all(24.r), // .r EKLENDİ
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24.r), // .r EKLENDİ
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16.r, // .r EKLENDİ
                      offset: Offset(0, 4.h)) // .h EKLENDİ
                ],
              ),
              child: Text(
                currentQuestion['questionText'] ?? "",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20.sp, // .sp EKLENDİ
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                    height: 1.3),
              ),
            ),
            SizedBox(height: 24.h), // .h EKLENDİ

            // Medya Alanı (Varsa)
            if (rawAttachments.isNotEmpty) _buildMediaCarousel(rawAttachments),

            // Seçenekler
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              separatorBuilder: (c, i) => SizedBox(height: 12.h), // .h EKLENDİ
              itemBuilder: (context, index) {
                final option = options[index];
                return _buildOptionCard(option);
              },
            ),

            // Diğer (Open Ended) Seçeneği
            if (allowOpenEnded) ...[
              SizedBox(height: 12.h), // .h EKLENDİ
              _buildOtherOption(),
            ],

            SizedBox(height: 32.h), // .h EKLENDİ

            // İleri / Bitir Butonu
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 20.h), // .h EKLENDİ
                elevation: 4,
                shadowColor: _primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r)), // .r EKLENDİ
              ),
              onPressed: _selectedAnswer == null ? null : _submitAndGoToNext,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentQuestionIndex < _questions.length - 1
                        ? "answer_next_button".tr()
                        : "answer_finish_button".tr(),
                    style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold), // .sp EKLENDİ
                  ),
                  SizedBox(width: 8.w), // .w EKLENDİ
                  Icon(
                    _currentQuestionIndex < _questions.length - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.check_circle_rounded,
                    size: 20.sp, // .sp EKLENDİ
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Medya Göstericisi
  // Medya Göstericisi (GÜNCELLENDİ: Oklar ve Sayaç Eklendi)
  Widget _buildMediaCarousel(List<dynamic> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 220.h, // .h EKLENDİ
          child: Stack(
            children: [
              // 1. Resim Kaydırıcı
              PageView.builder(
                controller: _mediaPageController,
                itemCount: attachments.length,
                onPageChanged: (idx) =>
                    setState(() => _currentMediaIndex = idx),
                itemBuilder: (context, idx) {
                  final attachment = attachments[idx];
                  final path = attachment['path']?.toString() ?? '';
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w), // .w EKLENDİ
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.r), // .r EKLENDİ
                      color: Colors.black12,
                      image: attachment['type'] == 'image'
                          ? DecorationImage(
                              image: NetworkImage(path), fit: BoxFit.contain)
                          : null,
                    ),
                    child: attachment['type'] != 'image'
                        ? Center(
                            child: Icon(Icons.insert_drive_file,
                                size: 40.sp,
                                color: Colors.white)) // .sp EKLENDİ
                        : null,
                  );
                },
              ),

              // 2. Resim Sayacı (Sağ Üst Köşe - Örn: 1/3)
              if (attachments.length > 1)
                Positioned(
                  top: 10.h, // .h EKLENDİ
                  right: 14.w, // .w EKLENDİ
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h), // .w .h EKLENDİ
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12.r), // .r EKLENDİ
                    ),
                    child: Text(
                      "${_currentMediaIndex + 1}/${attachments.length}",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp, // .sp EKLENDİ
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // 3. Sol Ok (Geri)
              if (_currentMediaIndex > 0)
                Positioned(
                  left: 8.w, // .w EKLENDİ
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _mediaPageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: Container(
                        padding: EdgeInsets.all(6.r), // .r EKLENDİ
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4)
                            ]),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18.sp, color: _primaryColor), // .sp EKLENDİ
                      ),
                    ),
                  ),
                ),

              // 4. Sağ Ok (İleri)
              if (_currentMediaIndex < attachments.length - 1)
                Positioned(
                  right: 8.w, // .w EKLENDİ
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        _mediaPageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      },
                      child: Container(
                        padding: EdgeInsets.all(6.r), // .r EKLENDİ
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4)
                            ]),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                            size: 18.sp, color: _primaryColor), // .sp EKLENDİ
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Alt Noktalar (Dots) - Mevcut haliyle kalabilir
        if (attachments.length > 1)
          Padding(
            padding: EdgeInsets.only(top: 12.h), // .h EKLENDİ
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                attachments.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: EdgeInsets.symmetric(horizontal: 3.w), // .w EKLENDİ
                  height: 6.h, // .h EKLENDİ
                  width: _currentMediaIndex == index ? 20.w : 6.w, // .w EKLENDİ
                  decoration: BoxDecoration(
                    color: _currentMediaIndex == index
                        ? _primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3.r), // .r EKLENDİ
                  ),
                ),
              ),
            ),
          ),
        SizedBox(height: 24.h), // .h EKLENDİ
      ],
    );
  }

  // Modern Seçenek Kartı
  Widget _buildOptionCard(String option) {
    final bool isSelected = _selectedAnswer == option;
    return GestureDetector(
      onTap: () => setState(() => _selectedAnswer = option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            vertical: 18.h, horizontal: 20.w), // .h .w EKLENDİ
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _surfaceColor,
          borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
          border: Border.all(
              color: isSelected ? _primaryColor : Colors.transparent,
              width: 2.w), // .w EKLENDİ
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10.r, // .r EKLENDİ
                  offset: Offset(0, 4.h)), // .h EKLENDİ
          ],
        ),
        child: Row(
          children: [
            // Radyo Butonu İkonu
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 22.sp, // .sp EKLENDİ
            ),
            SizedBox(width: 16.w), // .w EKLENDİ
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16.sp, // .sp EKLENDİ
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : _primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // "Diğer" Seçeneği
  Widget _buildOtherOption() {
    final bool isSelected = _selectedAnswer == _otherOptionKey;
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedAnswer = _otherOptionKey),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
                vertical: 18.h, horizontal: 20.w), // .h .w EKLENDİ
            decoration: BoxDecoration(
              color: isSelected ? _surfaceColor : _surfaceColor,
              borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
              border: Border.all(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  width: 2.w), // .w EKLENDİ
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10.r, // .r EKLENDİ
                    offset: Offset(0, 4.h)), // .h EKLENDİ
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: isSelected ? _primaryColor : Colors.grey.shade400,
                  size: 24.sp, // .sp EKLENDİ
                ),
                SizedBox(width: 16.w), // .w EKLENDİ
                Text(
                  "answer_other_label".tr(), // "Diğer (Lütfen belirtiniz)"
                  style: TextStyle(
                    fontSize: 16.sp, // .sp EKLENDİ
                    fontWeight: FontWeight.w600,
                    color: isSelected ? _primaryColor : _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Metin Kutusu (Sadece seçiliyse açılır)
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: isSelected
              ? Container(
                  margin: EdgeInsets.only(top: 12.h), // .h EKLENDİ
                  child: TextField(
                    controller: _otherAnswerController,
                    autofocus: true,
                    maxLength: 50,
                    style: TextStyle(
                        color: _primaryColor, fontSize: 16.sp), // .sp EKLENDİ
                    decoration: InputDecoration(
                      hintText: "answer_other_hint".tr(),
                      filled: true,
                      fillColor: _surfaceColor,
                      contentPadding: EdgeInsets.all(16.r), // .r EKLENDİ
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r), // .r EKLENDİ
                        borderSide: BorderSide(
                            color: _primaryColor, width: 2.w), // .w EKLENDİ
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
