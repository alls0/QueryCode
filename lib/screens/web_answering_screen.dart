import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'thank_you_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class WebAnsweringScreen extends StatefulWidget {
  final String eventId;

  const WebAnsweringScreen({super.key, required this.eventId});

  @override
  State<WebAnsweringScreen> createState() => _WebAnsweringScreenState();
}

class _WebAnsweringScreenState extends State<WebAnsweringScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _questions = [];
  bool _isNicknameRequired = false;
  int _currentStep = 0;
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _currentQuestionIndex = 0;

  String? _selectedAnswer;
  final TextEditingController _otherAnswerController = TextEditingController();
  static const String _otherOptionKey = '__OTHER_OPTION_SELECTED__';

  final List<Map<String, String>> _userAnswers = [];
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  String? _deviceId;

  // --- MODERN RENK PALETİ ---
  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;
  final Color _secondaryColor = const Color(0xFF718096);

  @override
  void initState() {
    super.initState();
    _checkDeviceAndFetchEvent();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _otherAnswerController.dispose();
    _mediaPageController.dispose();
    super.dispose();
  }

  Future<void> _checkDeviceAndFetchEvent() async {
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
          _isNicknameRequired = data['isNicknameRequired'] ?? false;
          _currentStep = _isNicknameRequired ? 0 : 1;
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

  void _submitNickname() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _currentStep = 1;
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
      setState(() => _isLoading = true);

      try {
        final String respondentName = _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : 'Anonim_${DateTime.now().millisecondsSinceEpoch}';

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
          if (e.toString().contains("Already voted"))
            errorMsg = "answer_already_voted".tr();

          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
          setState(() {
            _isLoading = false;
            if (e.toString().contains("Already voted"))
              _errorMessage = errorMsg;
          });
        }
      }
    } else {
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
    // Eğer Nickname adımındaysak progress 0, değilse soruya göre
    double progress = 0.0;
    if (_currentStep == 1 && _questions.isNotEmpty) {
      progress = (_currentQuestionIndex + 1) / _questions.length;
    }

    return Scaffold(
      backgroundColor: _bgColor,
      // --- APP BAR & LOGO & PROGRESS ---
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Hero(
          tag: 'app_logo',
          child: Image.asset(
            'assets/images/logo4.png',
            height: 40,
            errorBuilder: (c, o, s) =>
                Icon(Icons.qr_code_2, color: _primaryColor),
          ),
        ),
        bottom: _currentStep == 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(6.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0), // Full width
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: _primaryColor,
                    minHeight: 4,
                  ),
                ),
              )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? CircularProgressIndicator(color: _primaryColor)
              : _errorMessage.isNotEmpty
                  ? _buildErrorView()
                  : _buildCurrentStep(), // Animasyonlu geçiş eklenebilir
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.orange.shade50, shape: BoxShape.circle),
          child: Icon(Icons.info_outline_rounded,
              size: 50, color: Colors.orange.shade700),
        ),
        const SizedBox(height: 24),
        Text(
          _errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    // AnimatedSwitcher ile adımlar arası yumuşak geçiş
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: _currentStep == 0
          ? _buildNicknameStep()
          : _buildAnsweringStep(),
    );
  }

  // --- 1. ADIM: İSİM GİRİŞ (MODERN) ---
  Widget _buildNicknameStep() {
    return Container(
      key: const ValueKey('nickname_step'),
      width: 450, // Web'de çok genişlememesi için sınır
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _bgColor, shape: BoxShape.circle),
              child: Icon(Icons.person_outline_rounded,
                  size: 32, color: _primaryColor),
            ),
            const SizedBox(height: 24),
            Text("web_join_title".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                    letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(
              "Devam etmek için bir takma ad belirleyin", // Dil desteği eklenebilir
              textAlign: TextAlign.center,
              style: TextStyle(color: _secondaryColor, fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nicknameController,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
              decoration: InputDecoration(
                hintText: "web_nickname_label".tr(),
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: _bgColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _primaryColor, width: 2)),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? "nickname_validation".tr() : null,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 5,
                    shadowColor: _primaryColor.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: _submitNickname,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("nickname_button".tr(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. ADIM: SORU CEVAPLAMA (MODERN) ---
  Widget _buildAnsweringStep() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final List<dynamic> rawAttachments =
        currentQuestion['attachments'] as List<dynamic>? ?? [];
    List<dynamic> options = List.from(currentQuestion['options'] ?? []);
    final bool allowOpenEnded = currentQuestion['allowOpenEnded'] ?? false;

    // AnimatedSwitcher için key değişimi
    return Container(
      key: ValueKey('question_$_currentQuestionIndex'),
      width: 500, // İçeriği odaklar
      padding: const EdgeInsets.all(32), // Web için geniş padding
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade100), // Hafif border
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              "${"answer_title_prefix".tr()} ${_currentQuestionIndex + 1}/${_questions.length}",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _secondaryColor, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 16),
          Text(currentQuestion['questionText'] ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor,
                  height: 1.3)),
          const SizedBox(height: 32),
          
          if (rawAttachments.isNotEmpty) ...[
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView.builder(
                  controller: _mediaPageController,
                  itemCount: rawAttachments.length,
                  itemBuilder: (context, idx) {
                    final attachment = rawAttachments[idx];
                    if (attachment['type'] == 'image') {
                      return Image.network(attachment['path'],
                          fit: BoxFit.contain);
                    }
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                          child: Icon(Icons.insert_drive_file, size: 50, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          ...options.map((option) {
            final bool isSelected = _selectedAnswer == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => setState(() => _selectedAnswer = option),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : _bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            isSelected ? _primaryColor : Colors.transparent,
                        width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(option,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : _primaryColor)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          if (allowOpenEnded)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedAnswer = _otherOptionKey),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                      decoration: BoxDecoration(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _selectedAnswer == _otherOptionKey
                                ? _primaryColor
                                : Colors.transparent,
                            width: 2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note_rounded,
                              color: _selectedAnswer == _otherOptionKey
                                  ? _primaryColor
                                  : Colors.grey),
                          const SizedBox(width: 8),
                          Text("answer_other_label".tr(),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _selectedAnswer == _otherOptionKey
                                      ? _primaryColor
                                      : Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedAnswer == _otherOptionKey)
                  TextField(
                    controller: _otherAnswerController,
                    autofocus: true,
                    maxLength: 50,
                    style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "answer_other_hint".tr(),
                      filled: true,
                      fillColor: _bgColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: _primaryColor, width: 2)),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          const SizedBox(height: 32),
          
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                elevation: 4,
                shadowColor: _primaryColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: _selectedAnswer == null ? null : _submitAndGoToNext,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    _currentQuestionIndex < _questions.length - 1
                        ? "answer_next_button".tr()
                        : "answer_finish_button".tr(),
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(_currentQuestionIndex < _questions.length - 1 
                  ? Icons.arrow_forward_rounded 
                  : Icons.check_circle_rounded, size: 20)
              ],
            ),
          ),
        ],
      ),
    );
  }
}