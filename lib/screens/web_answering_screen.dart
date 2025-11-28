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

  // Cevap Yönetimi
  String? _selectedAnswer;
  final TextEditingController _otherAnswerController = TextEditingController();
  static const String _otherOptionKey = '__OTHER_OPTION_SELECTED__';

  final List<Map<String, String>> _userAnswers = [];
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  String? _deviceId;

  // Tasarım Sabitleri
  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;

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
        final List<dynamic> votedDevices = data['votedDevices'] ?? [];
        if (votedDevices.contains(_deviceId)) {
          setState(() {
            _errorMessage = "You have already voted in this event.";
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
    // Cevabı belirle
    String finalAnswer = _selectedAnswer == _otherOptionKey
        ? _otherAnswerController.text.trim()
        : _selectedAnswer!;

    if (finalAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an answer.")),
      );
      return;
    }

    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': finalAnswer,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      // SON SORU: GÖNDERME
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
            errorMsg = "You have already voted!";

          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMsg)));
          setState(() {
            _isLoading = false;
            if (e.toString().contains("Already voted"))
              _errorMessage = errorMsg;
          });
        }
      }
    } else {
      // SONRAKİ SORU
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
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? CircularProgressIndicator(color: _primaryColor)
              : _errorMessage.isNotEmpty
                  ? Text(_errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 18))
                  : _buildCurrentStep(),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return _buildNicknameStep();
    } else {
      return _buildAnsweringStep();
    }
  }

  Widget _buildNicknameStep() {
    // ... Bu kısım (Nickname formu) önceki kodunuzdaki gibi kalabilir ...
    // Hızlı olması için burayı kısaltıyorum, önceki koddaki _buildNicknameStep aynı şekilde kullanılabilir.
    return Container(
      width: 450,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text("web_join_title".tr(),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor)),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: "web_nickname_label".tr(),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? "nickname_validation".tr() : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  minimumSize: const Size(double.infinity, 50)),
              onPressed: _submitNickname,
              child: Text("nickname_button".tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnsweringStep() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final List<dynamic> rawAttachments =
        currentQuestion['attachments'] as List<dynamic>? ?? [];
    List<dynamic> options = List.from(currentQuestion['options'] ?? []);

    // Açık uçlu kontrolü
    final bool allowOpenEnded = currentQuestion['allowOpenEnded'] ?? false;

    return Container(
      width: 500,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              "${"answer_title_prefix".tr()} ${_currentQuestionIndex + 1}/${_questions.length}",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(currentQuestion['questionText'] ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor)),
          const SizedBox(height: 24),

          // Medya Alanı
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
                    return const Icon(Icons.insert_drive_file, size: 50);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Seçenekler
          ...options.map((option) {
            final bool isSelected = _selectedAnswer == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => setState(() => _selectedAnswer = option),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : _surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            isSelected ? _primaryColor : Colors.grey.shade300,
                        width: 1.5),
                  ),
                  child: Text(option,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _primaryColor)),
                ),
              ),
            );
          }).toList(),

          // Açık Uçlu Seçenek (Web için)
          if (allowOpenEnded)
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedAnswer = _otherOptionKey),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _selectedAnswer == _otherOptionKey
                                ? _primaryColor
                                : Colors.grey.shade300,
                            width:
                                _selectedAnswer == _otherOptionKey ? 2 : 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_note,
                              color: _selectedAnswer == _otherOptionKey
                                  ? _primaryColor
                                  : Colors.grey),
                          const SizedBox(width: 8),
                          Text("Other (Type your answer)",
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
                    decoration: InputDecoration(
                      hintText: "Type your answer here...",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: _primaryColor, width: 2),
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),

          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: _selectedAnswer == null ? null : _submitAndGoToNext,
            child: Text(
                _currentQuestionIndex < _questions.length - 1
                    ? "answer_next_button".tr()
                    : "answer_finish_button".tr(),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
