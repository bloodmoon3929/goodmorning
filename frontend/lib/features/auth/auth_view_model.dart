import '../../core/network/goodmorning_api.dart';
import '../../core/network/load_state.dart';
import '../../models/catalog.dart';

/// 회원가입 1단계에서 2단계로 넘기는 값
class SignupDraft {
  const SignupDraft({this.email = '', this.nickname = '굿즈러버', this.region = '용산구', this.sns});

  final String email;
  final String nickname;
  final String region;
  final String? sns; // 카카오 · 네이버 · Apple 로 처음 로그인한 경우
}

/// 로그인 (4)
class LoginViewModel extends ViewModel {
  String email = 'goods@example.com';
  String password = 'goods1234';
  bool busy = false;

  bool get canSubmit => email.contains('@') && password.length >= 8 && !busy;

  Future<void> submit() async {
    busy = true;
    notify();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    busy = false;
    notify();
  }
}

enum EmailCheck { unchecked, checking, ok, taken }

/// 회원가입 · 계정 정보 (5)
class SignupAccountViewModel extends ViewModel {
  SignupAccountViewModel(this.api);
  final GoodmorningApi api;

  String email = '';
  String password = '';
  String confirm = '';
  String nickname = '';
  String? region;
  EmailCheck emailCheck = EmailCheck.unchecked;
  bool terms = false;
  bool privacy = false;
  bool location = false;
  bool alerts = false;

  static final _hasLetter = RegExp(r'[A-Za-z]');
  static final _hasDigit = RegExp(r'\d');

  bool get passwordOk => password.length >= 8 && _hasLetter.hasMatch(password) && _hasDigit.hasMatch(password);
  bool get confirmOk => confirm.isNotEmpty && confirm == password;
  bool get allAgreed => terms && privacy && location && alerts;
  bool get canNext => emailCheck == EmailCheck.ok && passwordOk && confirmOk && nickname.trim().isNotEmpty && terms && privacy;

  void setEmail(String v) {
    email = v;
    emailCheck = EmailCheck.unchecked;
    notify();
  }

  void setPassword(String v) {
    password = v;
    notify();
  }

  void setConfirm(String v) {
    confirm = v;
    notify();
  }

  void setNickname(String v) {
    nickname = v;
    notify();
  }

  Future<void> checkEmail() async {
    if (!email.contains('@')) return;
    emailCheck = EmailCheck.checking;
    notify();
    final taken = await api.isEmailTaken(email);
    emailCheck = taken ? EmailCheck.taken : EmailCheck.ok;
    notify();
  }

  void useCurrentLocation() {
    region = '용산구';
    notify();
  }

  void toggleAll() {
    final v = !allAgreed;
    terms = privacy = location = alerts = v;
    notify();
  }

  void toggle(String which) {
    switch (which) {
      case 'terms':
        terms = !terms;
      case 'privacy':
        privacy = !privacy;
      case 'location':
        location = !location;
      case 'alerts':
        alerts = !alerts;
    }
    notify();
  }

  SignupDraft get draft => SignupDraft(email: email, nickname: nickname.trim(), region: region ?? '지역 미설정');
}

/// 회원가입 · IP 고르기 (6) 와 IP 목록 조정 (12)이 함께 쓴다
class IpPickViewModel extends ViewModel {
  IpPickViewModel(this.api, {List<String> initial = const []}) : selected = [...initial] {
    reload();
  }

  final GoodmorningApi api;
  Load<List<Ip>> ips = const Loading();
  final List<String> selected; // 고른 순서 = 홈 · 굿즈 탐색에 보이는 순서
  String query = '';
  IpKind? kind;
  final Set<String> requested = {};

  void reload() => load(api.ips, (v) => ips = v);

  List<Ip> visible(List<Ip> all) {
    final q = query.trim().toLowerCase();
    return all.where((ip) {
      if (kind != null && ip.kind != kind) return false;
      if (q.isEmpty) return true;
      return ip.name.toLowerCase().contains(q) || ip.aliases.any((a) => a.toLowerCase().contains(q));
    }).toList();
  }

  void toggle(String id) {
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    notify();
  }

  /// [newIndex]는 옮길 항목을 뺀 뒤의 위치 (onReorderItem)
  void reorder(int oldIndex, int newIndex) {
    final id = selected.removeAt(oldIndex);
    selected.insert(newIndex, id);
    notify();
  }

  void setQuery(String v) {
    query = v;
    notify();
  }

  void setKind(IpKind? k) {
    kind = k;
    notify();
  }

  void request(String name) {
    requested.add(name.trim());
    notify();
  }
}
