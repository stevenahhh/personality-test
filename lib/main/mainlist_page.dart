import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../sub/question_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MainPage();
  }
}

class _MainPage extends State<MainPage> {
  late Future<List<Map<String, dynamic>>> _initializationFuture;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  String _welcomeTitle = '심리 테스트'; // 기본 제목

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initialize();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _initializationFuture = _initialize();
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _initialize() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw '인터넷에 연결되지 않았습니다.';
    }

    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();
    _welcomeTitle = remoteConfig.getString("welcome");

    final snapshot = await FirebaseDatabase.instance.ref('test').get();
    
    final List<Map<String, dynamic>> testList = [];
    if (snapshot.exists) {
      for (final child in snapshot.children) {
        if (child.value != null) {
          // JSON 문자열을 Map으로 변환하여 리스트에 추가
          testList.add(jsonDecode(child.value.toString()) as Map<String, dynamic>);
        }
      }
    }
    return testList;
  }

  void _uploadData() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Firebase에 데이터 업로드를 시작합니다...')),
    );

    try {
      final dbRef = FirebaseDatabase.instance.ref('test');
      await dbRef.remove();

      final filesToUpload = ['res/api/mbti.json', 'res/api/test1.json', 'res/api/test2.json'];
      int successCount = 0;

      for (final filePath in filesToUpload) {
        try {
          final jsonString = await rootBundle.loadString(filePath);
          await dbRef.push().set(jsonString);
          successCount++;
        } catch (e) {
          print('$filePath 업로드 실패: $e');
        }
      }
      
      messenger.showSnackBar(
        SnackBar(content: Text('업로드 완료: 총 ${filesToUpload.length}개 중 $successCount개 성공.')),
      );

      setState(() {
        _initializationFuture = _initialize();
      });

    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('데이터 업로드 중 오류 발생: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade200,
              Colors.purple.shade100,
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              backgroundColor: Colors.transparent,
              elevation: 0,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  _welcomeTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 2.0, color: Colors.black45)])
                ),
                centerTitle: true,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  tooltip: 'Firebase에 데이터 올리기',
                  onPressed: _uploadData,
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _initializationFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(child: Text('오류: ${snapshot.error}', style: const TextStyle(color: Colors.white, fontSize: 16))),
                  );
                }

                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                  final tests = snapshot.data!;
                  if (tests.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('표시할 테스트가 없습니다.', style: TextStyle(color: Colors.white, fontSize: 16)),
                            const SizedBox(height: 10),
                            Text('상단 업로드 버튼을 눌러 데이터를 올려주세요.', style: TextStyle(color: Colors.white.withOpacity(0.8))),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList.builder(
                    itemCount: tests.length,
                    itemBuilder: (context, index) {
                      final item = tests[index];
                      return _buildTestItemCard(item, index);
                    },
                  );
                }
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestItemCard(Map<String, dynamic> item, int index) {
    return InkWell(
      onTap: () async {
        await FirebaseAnalytics.instance.logEvent(
          name: "test_click",
          parameters: {"test_name": item['title']?.toString() ?? 'Unknown'},
        );
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(builder: (context) {
            return QuestionPage(testData: item);
          }));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.white, size: 30),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                item['title']?.toString() ?? '제목 없음',
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
