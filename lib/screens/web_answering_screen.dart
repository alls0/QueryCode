import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // EKLENDİ
import 'package:uuid/uuid.dart'; // EKLENDİ
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

  // YENİ: Cihaz Kimliği Değişkeni
  String? _deviceId;

  // Tasarım Sabitleri
  final Color _primaryColor = const Color(0xFF1A202C);
  final Color _bgColor = const Color(0xFFF8FAFC);
  final Color _surfaceColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _checkDeviceAndFetchEvent(); // Metod ismi güncellendi
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _mediaPageController.dispose();
    super.dispose();
  }

  // --- YENİ: CİHAZ ID ALMA VE KONTROL ETME ---
  Future<void> _checkDeviceAndFetchEvent() async {
    try {
      // 1. Cihaz ID'sini SharedPreferences'tan al veya oluştur
      final prefs = await SharedPreferences.getInstance();
      _deviceId = prefs.getString('device_unique_id');

      if (_deviceId == null) {
        _deviceId = const Uuid().v4();
        await prefs.setString('device_unique_id', _deviceId!);
      }

      // 2. Etkinliği Çek
      final docSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;

        // 3. KONTROL: Bu cihaz daha önce oy vermiş mi?
        final List<dynamic> votedDevices = data['votedDevices'] ?? [];
        if (votedDevices.contains(_deviceId)) {
          setState(() {
            _errorMessage =
                "You have already voted in this event."; // Dil desteği eklenebilir: "already_voted_error".tr()
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

  // --- GÜNCELLENEN GÖNDERME METODU (TRANSACTION İLE) ---
  void _submitAndGoToNext() async {
    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': _selectedAnswer!,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      // SON SORU: GÖNDERME İŞLEMİ
      setState(() {
        _isLoading = true;
      });

      try {
        final String respondentName = _nicknameController.text.trim().isNotEmpty
            ? _nicknameController.text.trim()
            : 'Anonim_${DateTime.now().millisecondsSinceEpoch}';

        final eventRef =
            FirebaseFirestore.instance.collection('events').doc(widget.eventId);

        // Transaction kullanarak güvenli kayıt (Çakışmaları önler)
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(eventRef);

          if (!snapshot.exists) throw Exception("Event not found");

          final data = snapshot.data() as Map<String, dynamic>;
          final List<dynamic> votedDevices = data['votedDevices'] ?? [];

          // Son bir kez daha kontrol et (Aynı anda iki sekme açmış olabilir)
          if (votedDevices.contains(_deviceId)) {
            throw Exception("Already voted");
          }

          // Güncelleme: Hem sonuçları hem de Cihaz ID'sini ekle
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
            errorMsg = "You have already voted!";
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg)),
          );
          setState(() {
            _isLoading = false;
            if (e.toString().contains("Already voted")) {
              _errorMessage = errorMsg; // Ekranı hata mesajıyla kilitle
            }
          });
        }
      }
    } else {
      // SONRAKİ SORUYA GEÇ
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
                  ? Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 10)
                          ]),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.red, size: 50),
                          const SizedBox(height: 20),
                          Text(_errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  : _buildCurrentStep(),
        ),
      ),
    );
  }

  // ... (Geri kalan _buildCurrentStep, _buildNicknameStep ve _buildAnsweringStep kodları AYNI kalacak) ...

  Widget _buildCurrentStep() {
    if (_currentStep == 0) {
      return _buildNicknameStep();
    } else {
      return _buildAnsweringStep();
    }
  }

  // _buildNicknameStep ve _buildAnsweringStep metodlarını orijinal kodunuzdan olduğu gibi koruyun,
  // sadece yukarıdaki _checkDeviceAndFetchEvent ve _submitAndGoToNext metodlarını değiştirmeniz yeterli.

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
