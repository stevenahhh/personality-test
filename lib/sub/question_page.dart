import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
// WebSharer 관련 임포트는 일단 제거합니다.
// import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
// import 'package:url_launcher/url_launcher.dart';

class QuestionPage extends StatefulWidget {
  final Map<String, dynamic> testData;

  const QuestionPage({Key? key, required this.testData}) : super(key: key);

  @override
  State<QuestionPage> createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  int _currentIndex = 0;
  String? _selectedAnswer;
  final List<String> _userAnswers = [];

  void _answerQuestion(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });

    Timer(const Duration(milliseconds: 300), () {
      _userAnswers.add(answer);
      final questions = widget.testData['questions'] as List?;
      if (questions != null && _currentIndex < questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedAnswer = null;
        });
      } else {
        _showResult();
      }
    });
  }

  void _showResult() {
    final results = widget.testData['results'] as Map<String, dynamic>?;
    if (results == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => const ErrorResultPage(message: '결과 데이터 형식이 올바르지 않습니다.'),
      ));
      return;
    }

    final allAnswers = _userAnswers.join();
    final Map<String, int> counts = {};
    for (var char in allAnswers.split('')) {
      counts[char] = (counts[char] ?? 0) + 1;
    }
    
    String resultType = '';
    if (counts.isNotEmpty) {
      resultType = counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    final resultData = results[resultType] as Map<String, dynamic>?;

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => ResultPage(
        title: widget.testData['title'] as String? ?? '결과',
        resultData: resultData,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.testData['questions'] as List?;
    if (questions == null || questions.isEmpty) {
      return const ErrorResultPage(message: '질문 데이터가 없거나 형식이 올바르지 않습니다.');
    }

    final currentQuestion = questions[_currentIndex] as Map<String, dynamic>;
    final answers = currentQuestion['answers'] as Map<String, dynamic>?;
    if (answers == null) {
      return ErrorResultPage(message: '질문 #${_currentIndex + 1}의 답변 데이터 형식이 올바르지 않습니다.');
    }

    final progress = (_currentIndex + 1) / questions.length;

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade100,
      appBar: AppBar(
        title: Text(widget.testData['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepPurple.shade300,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.deepPurple.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Q${_currentIndex + 1}. ${currentQuestion['question']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ..._buildAnswerButtons(answers),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnswerButtons(Map<String, dynamic> answers) {
    return answers.entries.map((entry) {
      final answerText = entry.value as String;
      final answerType = entry.key;
      bool isSelected = _selectedAnswer == answerType;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            foregroundColor: isSelected ? Colors.deepPurple : Colors.white,
            backgroundColor: isSelected ? Colors.white : Colors.deepPurple.shade400,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            elevation: 4,
          ),
          onPressed: () => _answerQuestion(answerType),
          child: Text(answerText, style: const TextStyle(fontSize: 16)),
        ),
      );
    }).toList();
  }
}

class ResultPage extends StatelessWidget {
  final String title;
  final Map<String, dynamic>? resultData;

  const ResultPage({Key? key, required this.title, this.resultData}) : super(key: key);

  Future<void> _shareOnKakao(BuildContext context) async {
    if (resultData == null) return;

    final resultDescription = resultData!['description'] as String? ?? '결과 설명이 없습니다.';

    final template = TextTemplate(
      text: '[심리 테스트 결과]\n$title\n\n결과: $resultDescription',
      link: Link(),
      buttonTitle: '테스트 하러가기',
    );

    try {
      bool isKakaoTalkSharingAvailable = await ShareClient.instance.isKakaoTalkSharingAvailable();
      if (isKakaoTalkSharingAvailable) {
        Uri uri = await ShareClient.instance.shareDefault(template: template);
        await ShareClient.instance.launchKakaoTalk(uri);
      } else {
        // 문제가 되던 WebSharer 로직을 잠시 비활성화하고, 사용자에게 알림을 표시합니다.
        _showErrorDialog(context, '카카오톡이 설치되어 있지 않아 공유할 수 없습니다.');
      }
    } catch (error) {
      _showErrorDialog(context, '공유에 실패했습니다: $error');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (resultData == null) {
      return const ErrorResultPage(message: '결과를 계산할 수 없습니다.');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('테스트 결과'), backgroundColor: Colors.deepPurple.shade300),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepPurple.shade100, Colors.purple.shade200],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('당신의 결과는...', style: TextStyle(fontSize: 22, color: Colors.white70)),
            const SizedBox(height: 10),
            Text(
              resultData!['type'] as String? ?? '알 수 없음',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                resultData!['description'] as String? ?? '설명이 없습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white, height: 1.5),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('카카오톡으로 공유하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEE500),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _shareOnKakao(context),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('돌아가기', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorResultPage extends StatelessWidget {
  final String message;
  const ErrorResultPage({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오류')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('돌아가기')),
          ],
        ),
      ),
    );
  }
}
