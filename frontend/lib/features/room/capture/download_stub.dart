/// 앱(안드로이드 · iOS)에서는 아직 파일로 내보내지 않는다 (웹에서 내려받기)
Future<bool> saveBytes(String name, List<int> bytes, {String mime = 'application/zip'}) async => false;
