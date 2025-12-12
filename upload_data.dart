import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import './lib/firebase_options.dart';

// 이 스크립트는 프로젝트의 로컬 JSON 테스트 데이터를 Firebase 실시간 데이터베이스에 업로드합니다.
// 터미널에서 `dart run upload_data.dart` 명령어로 실행하세요.
Future<void> main(List<String> args) async {
  try {
    print('Firebase 초기화를 시작합니다...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase 초기화 성공!');

    final database = FirebaseDatabase.instance;
    final testRef = database.ref('test');

    // --clear 옵션이 주어지면 기존 데이터를 삭제하여 중복을 방지합니다.
    if (args.contains('--clear')) {
      print('기존 /test 경로의 데이터를 삭제합니다...');
      await testRef.remove();
      print('기존 데이터 삭제 완료.');
    }

    final filesToUpload = ['res/api/test1.json', 'res/api/test2.json'];
    print('${filesToUpload.length}개의 파일을 업로드합니다: $filesToUpload');

    for (final filePath in filesToUpload) {
      try {
        print('파일 읽는 중: $filePath');
        final file = File(filePath);
        // 파일이 존재하는지 확인합니다.
        if (!await file.exists()) {
          print('--> 오류: $filePath 파일을 찾을 수 없습니다. 경로를 확인하세요.');
          continue;
        }
        final jsonString = await file.readAsString();

        print('$filePath 내용 업로드 중...');
        // push()는 고유한 키를 생성하여 데이터를 추가합니다.
        await testRef.push().set(jsonString);
        
        print('--> $filePath 업로드 성공!');
      } catch (e) {
        print('--> $filePath 처리 중 오류 발생: $e');
      }
    }

    print('-------------------------------------');
    print('모든 데이터 업로드가 완료되었습니다!');
    print('이제 앱 코드를 수정하여 데이터베이스에서 데이터를 읽도록 변경할 수 있습니다.');

  } catch (e) {
    print('스크립트 실행 중 치명적인 오류가 발생했습니다: $e');
  } finally {
    // 프로세스가 자동으로 종료되지 않는 경우를 대비해 명시적으로 종료합니다.
    exit(0);
  }
}
