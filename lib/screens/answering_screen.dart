import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'thank_you_screen.dart';
import 'package:easy_localization/easy_localization.dart';

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
          content: Text("answer_enter_answer".tr()),
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

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));

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
            height: 40, // Logo boyutu
            errorBuilder: (c, o, s) =>
                Icon(Icons.qr_code_2, color: _primaryColor),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                color: _primaryColor, // Uygulamanın ana rengi
                minHeight: 6,
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.info_outline_rounded,
                  size: 48, color: Colors.orange.shade700),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _primaryColor,
                  fontSize: 16,
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
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
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
                  fontSize: 12,
                  letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),

            // Soru Metni Kartı
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Text(
                currentQuestion['questionText'] ?? "",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                    height: 1.3),
              ),
            ),
            const SizedBox(height: 24),

            // Medya Alanı (Varsa)
            if (rawAttachments.isNotEmpty) _buildMediaCarousel(rawAttachments),

            // Seçenekler
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final option = options[index];
                return _buildOptionCard(option);
              },
            ),

            // Diğer (Open Ended) Seçeneği
            if (allowOpenEnded) ...[
              const SizedBox(height: 12),
              _buildOtherOption(),
            ],

            const SizedBox(height: 32),

            // İleri / Bitir Butonu
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                elevation: 4,
                shadowColor: _primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _selectedAnswer == null ? null : _submitAndGoToNext,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentQuestionIndex < _questions.length - 1
                        ? "answer_next_button".tr()
                        : "answer_finish_button".tr(),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _currentQuestionIndex < _questions.length - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.check_circle_rounded,
                    size: 20,
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
  Widget _buildMediaCarousel(List<dynamic> attachments) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _mediaPageController,
            itemCount: attachments.length,
            onPageChanged: (idx) => setState(() => _currentMediaIndex = idx),
            itemBuilder: (context, idx) {
              final attachment = attachments[idx];
              final path = attachment['path']?.toString() ?? '';
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black12,
                  image: attachment['type'] == 'image'
                      ? DecorationImage(
                          image: NetworkImage(path), fit: BoxFit.cover)
                      : null,
                ),
                child: attachment['type'] != 'image'
                    ? const Center(
                        child: Icon(Icons.insert_drive_file,
                            size: 40, color: Colors.white))
                    : null,
              );
            },
          ),
        ),
        if (attachments.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                attachments.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: _currentMediaIndex == index ? 20 : 6,
                  decoration: BoxDecoration(
                    color: _currentMediaIndex == index
                        ? _primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
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
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? _primaryColor : Colors.transparent,
              width: 2),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
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
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
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
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color: isSelected ? _surfaceColor : _surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  color: isSelected ? _primaryColor : Colors.grey.shade400,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Text(
                  "answer_other_label".tr(), // "Diğer (Lütfen belirtiniz)"
                  style: TextStyle(
                    fontSize: 16,
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
                  margin: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: _otherAnswerController,
                    autofocus: true,
                    maxLength: 50,
                    style: TextStyle(color: _primaryColor),
                    decoration: InputDecoration(
                      hintText: "answer_other_hint".tr(),
                      filled: true,
                      fillColor: _surfaceColor,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: _primaryColor, width: 2),
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