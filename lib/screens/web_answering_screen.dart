import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<Map<String, String>> _userAnswers = [];

  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;

  // Tasarım Sabitleri
  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _mediaPageController.dispose();
    super.dispose();
  }

  Future<void> _fetchEventData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
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
    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': _selectedAnswer!,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() {
        _isLoading = true;
      });
      try {
        final String respondentName = _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : 'Anonim_${DateTime.now().millisecondsSinceEpoch}';

        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.eventId)
            .update({
          'results.$respondentName': _userAnswers,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ThankYouScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("answer_error_submit".tr())),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("web_join_title".tr(),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor)),
            const SizedBox(height: 12),
            Text("nickname_prompt".tr(),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: "web_nickname_label".tr(),
                filled: true,
                fillColor: _bgColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "nickname_validation".tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  minimumSize: const Size(double.infinity, 50)),
              onPressed: _submitNickname,
              child: Text("nickname_button".tr(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
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

          Text(
            currentQuestion['questionText'] ?? "answer_question_not_found".tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _primaryColor),
          ),

          const SizedBox(height: 24),

          // --- MEDYA GÖSTERİMİ ---
          if (rawAttachments.isNotEmpty) ...[
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      controller: _mediaPageController,
                      itemCount: rawAttachments.length,
                      onPageChanged: (idx) {
                        setState(() => _currentMediaIndex = idx);
                      },
                      itemBuilder: (context, idx) {
                        final attachment = rawAttachments[idx];
                        final path = attachment['path']?.toString() ?? '';
                        final type = attachment['type'];

                        if (type == 'image') {
                          return Image.network(
                            path,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: _primaryColor,
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey),
                              );
                            },
                          );
                        } else {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.insert_drive_file,
                                    size: 50, color: _primaryColor),
                                const SizedBox(height: 8),
                                Text(
                                  path.split('/').last.split('?').first,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    if (rawAttachments.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(rawAttachments.length, (idx) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentMediaIndex == idx
                                    ? _primaryColor
                                    : Colors.grey.withOpacity(0.5),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          ...(currentQuestion['options'] as List<dynamic>).map((option) {
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
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : _primaryColor),
                  ),
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                minimumSize: const Size(double.infinity, 50)),
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
