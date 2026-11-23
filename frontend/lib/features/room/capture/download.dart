import 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart' as platform;

/// 파일을 내려받게 한다 (웹: 브라우저 다운로드). 지원하지 않는 곳이면 false
Future<bool> saveBytes(String name, List<int> bytes, {String mime = 'application/zip'}) => platform.saveBytes(name, bytes, mime: mime);
