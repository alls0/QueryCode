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

  // Medya gösterimi için gerekli kontrolcüler
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _mediaPageController.dispose(); // Controller'ı temizlemeyi unutmuyoruz
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
        _currentMediaIndex = 0; // Yeni soruya geçince medya indeksini sıfırla
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFB6E0FE), Color(0xFFF4F7FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: _isLoading
              ? const CircularProgressIndicator()
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
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("web_join_title".tr(),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text("nickname_prompt".tr(), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nicknameController,
              decoration: InputDecoration(
                labelText: "web_nickname_label".tr(),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "nickname_validation".tr();
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
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
    // Mevcut soruyu al
    final currentQuestion = _questions[_currentQuestionIndex];

    // Ekleri (attachments) al ve listeye çevir, null kontrolü yap
    final List<dynamic> rawAttachments =
        currentQuestion['attachments'] as List<dynamic>? ?? [];

    return Container(
      width: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              "${"answer_title_prefix".tr()}${_currentQuestionIndex + 1} / ${_questions.length}",
              textAlign: TextAlign.center),
          const SizedBox(height: 16),

          Text(
            currentQuestion['questionText'] ?? "answer_question_not_found".tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 24),

          // --- MEDYA GÖSTERİMİ ---
          if (rawAttachments.isNotEmpty) ...[
            Container(
              height: 250, // Web için uygun sabit yükseklik
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
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
                          // Web'de network image kullanılır
                          return Image.network(
                            path,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
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
                          // Dosya gösterimi
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.insert_drive_file,
                                    size: 50, color: Colors.blue),
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
                    // Sayfa Göstergeleri (Dots)
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
                                    ? Colors.blue
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
          // --- MEDYA GÖSTERİMİ SONU ---

          ...(currentQuestion['options'] as List<dynamic>).map((option) {
            final bool isSelected = _selectedAnswer == option;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue.shade100 : null,
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(
                      color: isSelected ? Colors.blue : Colors.grey.shade300),
                ),
                onPressed: () {
                  setState(() {
                    _selectedAnswer = option;
                  });
                },
                child: Text(
                  option,
                  style: TextStyle(
                      color:
                          isSelected ? Colors.blue.shade900 : Colors.black87),
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 24),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50)),
            onPressed: _selectedAnswer == null ? null : _submitAndGoToNext,
            child: Text(_currentQuestionIndex < _questions.length - 1
                ? "answer_next_button".tr()
                : "answer_finish_button".tr()),
          ),
        ],
      ),
    );
  }
}
