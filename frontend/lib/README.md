# frontend/lib — Flutter 폴더 구조

Flutter에서는 컴포넌트를 위젯(Widget)이라고 부른다. 화면은 작은 위젯을 조립해서 만들고, 값이 바뀌면 그 위젯만 다시 그린다.
같은 모양이 두 화면 이상에 나오면 `components/`에 위젯으로 만들고, 화면에서는 가져다 쓴다.

```text
lib/
├── app/              # 앱 시작점, 화면 이동(라우팅), 테마 적용
├── core/
│   ├── theme/        # 색 코드 · 글꼴 · 간격 (docs/01-screen-flow.md 의 색 표)
│   ├── network/      # API 호출 공통 (주소, 로그인 토큰, 오류 처리)
│   └── cache/        # 미리 로딩 · 캐시 (docs/03-tech-spec.md 33번)
├── models/           # 데이터 모양 (API 응답과 같은 구조: Product, Variant, Store, Stock …)
├── components/       # 여러 화면이 함께 쓰는 위젯
│   ├── product_card/     # 상품 카드 (사진 · IP · 이름 · 배지 · ♡)
│   ├── stock_badge/      # 재고 많음 · 적음 · 없음 · 확인 필요 + 출처 · 시각
│   ├── channel_badge/    # 🌐 온라인 · 📍 오프라인 배지
│   ├── channel_filter/   # 전체 / 온라인 / 오프라인 필터
│   ├── ip_tile/          # IP 타일 (내 IP, 회원가입 IP 고르기, IP 목록 조정)
│   ├── bottom_tab_bar/   # 하단 탭 바
│   ├── skeleton/         # 스켈레톤 (컴포넌트마다 로딩 중 모양)
│   └── bottom_sheet/     # 아래에서 올라오는 창 (재고 제보, 문제 제기, 매장 미리보기)
└── features/         # 화면 단위 (슬라이드 번호는 docs/02-screens.md)
    ├── auth/             # 로그인 · 회원가입 (4–6)
    ├── home/             # 홈 (7)
    ├── explore/          # 굿즈 탐색 · IP 목록 조정 · IP 화면 · 캐릭터 화면 (8, 12–14)
    ├── search/           # 검색 결과 · 사진 검색 결과 (10–11)
    ├── notification/     # 알림 목록 (9)
    ├── product/          # 상품 상세 온라인 · 오프라인 (15–16)
    ├── store/            # 매장 찾기 리스트 · 지도 · 매장 상세 · 재고 제보 (17–20)
    ├── my/               # 마이 · 이동 기록 · 문제 제기 (21–23)
    └── seller/           # 판매자 센터 재고 관리 · 상품 등록 (24–25)
```

## 화면(feature) 안의 파일 규칙

화면은 MVVM으로 나눈다. 화면 위젯은 그리기만 하고, 데이터 요청과 상태는 view model이 맡는다.

```text
features/home/
├── home_screen.dart        # View: 화면 조립 (components + widgets)
├── home_view_model.dart    # ViewModel: API 요청, 로딩 · 오류 상태, 버튼 동작
└── widgets/                # 이 화면에서만 쓰는 위젯 (예: 내 주변 재고 카드)
```

- 화면 하나에만 쓰이는 위젯은 그 화면의 `widgets/`에 두고, 두 번째 화면에서 쓰게 되면 `components/`로 옮긴다.
- 컴포넌트마다 따로 데이터를 받아 그린다 (부분 로딩). 데이터를 기다리는 동안은 `components/skeleton/`의 모양을 보여 준다.
- 이름은 `snake_case.dart` 파일, `PascalCase` 클래스 (`product_card.dart` → `ProductCard`).
