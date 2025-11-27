import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final List<Map<String, String>> _userAnswers = [];

  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchEventData();
  }

  @override
  void dispose() {
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
        setState(() {
          _questions = docSnapshot.data()?['questions'] ?? [];
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
    _userAnswers.add({
      'question': _questions[_currentQuestionIndex]['questionText'],
      'answer': _selectedAnswer!,
    });

    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() {
        _isLoading = true;
      });
      try {
        final String respondentName = widget.nickname?.trim() ??
            'Anonim_${DateTime.now().millisecondsSinceEpoch}';

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
    final currentQuestion = !_isLoading && _questions.isNotEmpty
        ? _questions[_currentQuestionIndex]
        : null;

    final List<dynamic> rawAttachments = currentQuestion != null
        ? (currentQuestion['attachments'] as List<dynamic>? ?? [])
        : [];

    // Eski veri yapısı desteği
    if (rawAttachments.isEmpty &&
        currentQuestion != null &&
        currentQuestion['attachmentPath'] != null) {
      rawAttachments.add({
        'path': currentQuestion['attachmentPath'],
        'type': currentQuestion['attachmentType'] ?? 'image'
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? null
            : Text(
                "${"answer_title_prefix".tr()}${_currentQuestionIndex + 1} / ${_questions.length}"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 18)))
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withAlpha(15),
                                blurRadius: 20,
                                offset: const Offset(0, 5))
                          ],
                        ),
                        child: Text(
                          currentQuestion != null
                              ? (currentQuestion['questionText'] ??
                                  "answer_question_not_found".tr())
                              : "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (rawAttachments.isNotEmpty) ...[
                        Container(
                          height: 300,
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
                                    final path =
                                        attachment['path']?.toString() ?? '';
                                    final type = attachment['type'];

                                    if (path.isEmpty)
                                      return _buildErrorWidget();

                                    final bool isNetworkUrl =
                                        path.startsWith('http');

                                    if (type == 'image') {
                                      if (isNetworkUrl) {
                                        return Image.network(path,
                                            fit: BoxFit.contain, loadingBuilder:
                                                (context, child,
                                                    loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                              child: CircularProgressIndicator(
                                                  value: loadingProgress
                                                              .expectedTotalBytes !=
                                                          null
                                                      ? loadingProgress
                                                              .cumulativeBytesLoaded /
                                                          loadingProgress
                                                              .expectedTotalBytes!
                                                      : null));
                                        }, errorBuilder:
                                                (context, error, stackTrace) {
                                          debugPrint(
                                              "Resim yükleme hatası: $error");
                                          return _buildErrorWidget();
                                        });
                                      } else {
                                        return Image.file(
                                          File(path),
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _buildErrorWidget(),
                                        );
                                      }
                                    } else {
                                      return Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                                Icons.insert_drive_file_rounded,
                                                size: 60,
                                                color: Colors.blue.shade300),
                                            const SizedBox(height: 12),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20),
                                              child: Text(
                                                path
                                                    .split('/')
                                                    .last
                                                    .split('?')
                                                    .first,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            )
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                          rawAttachments.length, (idx) {
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _currentMediaIndex == idx
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade400
                                                    .withOpacity(0.5),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (currentQuestion != null &&
                          currentQuestion['options'] != null)
                        ...((currentQuestion['options'] as List<dynamic>)
                            .map((option) {
                          final bool isSelected = _selectedAnswer == option;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected
                                    ? Colors.blue.shade600
                                    : Colors.white,
                                foregroundColor:
                                    isSelected ? Colors.white : Colors.black,
                                minimumSize: const Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                                elevation: 4,
                              ),
                              onPressed: () =>
                                  setState(() => _selectedAnswer = option),
                              child: Text(option,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                            ),
                          );
                        }).toList()),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A202C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed:
                            _selectedAnswer == null ? null : _submitAndGoToNext,
                        child: Text(
                          _currentQuestionIndex < _questions.length - 1
                              ? "answer_next_button".tr()
                              : "answer_finish_button".tr(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text("Görsel yüklenemedi",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
      ],
    );
  }
}
