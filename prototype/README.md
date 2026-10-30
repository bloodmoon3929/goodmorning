# 굿모닝 클릭 프로토타입 (FigCraft)

UI 구상 PPT([docs/02-screens.md](../docs/02-screens.md))의 화면 25장을 FigCraft로 다시 그리고, 버튼마다 다음 화면을 이어 둔 클릭 프로토타입이다.

- 바로 보기: https://bloodmoon3929.github.io/goodmorning/ (GitHub Actions가 `prototype/site`를 GitHub Pages로 배포)
- 원본 파일: [`goodmorning.figcraft`](goodmorning.figcraft) — FigCraft에서 열면 화면 28장과 클릭 연결(Prototype)이 그대로 있다. 발표 모드(▶)로 재생할 수 있다.

## 화면

PPT 화면 25장에, 버튼을 눌렀을 때 나오는 상태 화면을 더해 28장이다.

|구분|화면 (PPT 슬라이드 번호)|
|--|--|
|로그인 · 회원가입|로그인(4), 계정 정보(5), IP 고르기(6)|
|홈|홈(7), 온라인 필터 · 오프라인 필터(7), 사진 고르기 · 사진 검색 결과(11), 알림(9), 검색 결과(10)|
|굿즈 탐색|굿즈 탐색(8), IP 목록 조정(12), IP 화면(13), 캐릭터 화면(14)|
|상품|온라인 가격(15), 오프라인 매장(16), 비슷한 굿즈(15), 외부 쇼핑몰로 이동(15)|
|매장|리스트(17), 지도(18), 매장 상세(19), 재고 제보(20), 지도 앱 · 전화 앱 연결(19)|
|마이 · 판매자|마이(21), 이동 기록(22), 문제 제기(23), 재고 관리(24), 상품 등록(25)|

- 상품 상세 · 매장 상세 · IP 화면은 PPT의 예시(쿠로미 마스코트 인형, 피규어샵 용산점, 산리오) 한 가지로 만들었다. 다른 상품 · 매장을 눌러도 이 예시 화면으로 간다.
- 캐릭터 사진은 저장소 공개용 규칙대로 이모지로 대신했다 ([Fluent Emoji 3D](https://github.com/microsoft/fluentui-emoji), MIT).

## 폴더

```text
prototype/
├── goodmorning.figcraft   # FigCraft 원본 (화면 + 클릭 연결)
├── figcraft/build.py      # 화면을 그리는 스크립트 → .figcraft · PNG · screens.json 생성
└── site/                  # GitHub Pages로 올라가는 정적 뷰어
    ├── index.html · app.js · style.css
    ├── screens.json       # 화면 목록과 클릭 영역 (build.py가 씀)
    └── screens/*.png      # FigCraft에서 내보낸 화면 (2배 해상도)
```

## 다시 만들기

화면을 고치면 `figcraft/build.py`의 화면 함수(`s_home` 등)를 수정하고 다시 돌린다.

```sh
# FigCraft(flatpak: ai.storyteller.figcraft)와 Python fontTools 필요
python3 prototype/figcraft/build.py
```

- 글꼴은 `frontend/assets/fonts`의 Pretendard, 그림은 `frontend/assets/emoji`를 쓴다 (Flutter 앱과 같은 파일).
- 스크립트가 FigCraft 명령 2,000여 개를 `figcraft-cli run`으로 실행해 `.figcraft`를 저장하고, 같은 실행 안에서 화면 PNG를 내보낸다.
- FigCraft 앱에서 직접 고친 경우에는 `figcraft-cli export prototype/goodmorning.figcraft -o prototype/site/screens --format png --scale 2`로 그림만 다시 내보낼 수 있다 (클릭 영역은 `screens.json`에서 고친다).
