# backend/ai — Python AI 서버

EmbeddingGemma 2로 사진 · 글을 768차원 벡터로 바꾸고, 비슷한 상품을 찾는다. API 서버(Rust)가 호출한다.

```text
ai/
├── app/
│   ├── api/          # API 서버가 부르는 주소 (사진 → 벡터, 상품 후보 찾기)
│   ├── embedding/    # EmbeddingGemma 2 불러오기 · 벡터 만들기 → catalog.embedding 저장
│   └── matching/     # 수집한 상품 → 같은 버전 찾기, IP · 캐릭터 분류 제안
└── tests/
```

쓰는 곳: 사진 검색, 텍스트 검색, 상품 매칭, 판매자 상품 등록 후보, IP 분류 제안 (docs/03-tech-spec.md 29–30번)
