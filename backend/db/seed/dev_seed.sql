-- 개발용 가상 데이터
-- 값은 frontend/lib/core/network/mock_data.dart(= UI 구상 PPT 화면의 예시)와 같다.
-- 매장 주소 · 전화 · 몰 주소 · 가격은 모두 가상이다. 몰 주소는 예약된 .example 도메인을 쓴다.
-- 매장 좌표는 해당 동네의 대략적인 위치다 (실제 매장이 아님).
-- 이미지: 공개 저장소라 캐릭터 사진 대신 앱에 들어 있는 이모지 그림 키를 'emoji:<키>'로 적는다.
-- 시각은 now() 기준으로 넣는다. 48시간이 지나면 재고가 '확인 필요'로 바뀌므로, 다시 보려면 DB를 새로 만든다.
-- 로그인 비밀번호 (모든 계정): goodmorning1234

BEGIN;

-- ------------------------------------------------------------ catalog
INSERT INTO catalog.ip (name, category, image_url) VALUES
    ('산리오', 'character', 'emoji:ribbon'),
    ('치이카와', 'character', 'emoji:hamster'),
    ('포켓몬스터', 'game', 'emoji:bolt'),
    ('기동전사 건담', 'plamodel', 'emoji:robot'),
    ('단보', 'character', 'emoji:package'),
    ('Fate', 'anime', 'emoji:swords'),
    ('디즈니', 'anime', 'emoji:castle'),
    ('짱구는 못말려', 'anime', 'emoji:crayon'),
    ('원피스', 'anime', 'emoji:sailboat');

INSERT INTO catalog.ip_alias (ip_id, alias)
SELECT ip.id, a.alias
FROM (VALUES
    ('산리오', 'sanrio'),
    ('치이카와', '먼작귀'),
    ('치이카와', '먼가 작고 귀여운 녀석'),
    ('치이카와', 'chiikawa'),
    ('포켓몬스터', '포켓몬'),
    ('기동전사 건담', '건담'),
    ('기동전사 건담', '건프라'),
    ('단보', '요츠바랑'),
    ('Fate', '페이트'),
    ('짱구는 못말려', '짱구')
) AS a (ip, alias)
JOIN catalog.ip ip ON ip.name = a.ip;

INSERT INTO catalog.character (ip_id, name, image_url)
SELECT ip.id, c.name, c.image_url
FROM (VALUES
    (1, '산리오', '헬로키티', 'emoji:ribbon'),
    (2, '산리오', '쿠로미', 'emoji:horns'),
    (3, '산리오', '마이멜로디', 'emoji:rabbit'),
    (4, '산리오', '시나모롤', 'emoji:cloud'),
    (5, '치이카와', '치이카와', 'emoji:hamster'),
    (6, '치이카와', '하치와레', 'emoji:cat'),
    (7, '치이카와', '우사기', 'emoji:rabbit'),
    (8, '포켓몬스터', '피카츄', 'emoji:bolt'),
    (9, '포켓몬스터', '이브이', 'emoji:sparkles'),
    (10, '기동전사 건담', 'RX-78-2 건담', 'emoji:robot'),
    (11, '기동전사 건담', '자쿠 II', 'emoji:alien'),
    (12, '단보', '단보', 'emoji:package'),
    (13, 'Fate', '세이버', 'emoji:swords')
) AS c (ord, ip, name, image_url)
JOIN catalog.ip ip ON ip.name = c.ip
ORDER BY c.ord;

-- release_date: 목업의 신상품 순서(newRank 1이 가장 최근)를 날짜로 바꾼 값
INSERT INTO catalog.product (ip_id, name, type, release_date, image_url)
SELECT ip.id, p.name, p.type, DATE '2026-11-18' - (p.new_rank - 1) * 3, 'emoji:' || p.emoji
FROM (VALUES
    (1, '산리오', '쿠로미 마스코트 인형', 'doll', 1, 'horns'),
    (2, '치이카와', '치이카와 마스코트 인형', 'doll', 2, 'hamster'),
    (3, '산리오', '헬로키티 인형 M', 'doll', 6, 'ribbon'),
    (4, '산리오', '마이멜로디 & 쿠로미 아크릴 스탠드', 'acrylic', 3, 'rabbit'),
    (5, '산리오', '시나모롤 미니 피규어', 'figure', 4, 'cloud'),
    (6, '산리오', '쿠로미 마스코트 인형 키링', 'keyring', 5, 'horns'),
    (7, '산리오', '쿠로미 방울 키링', 'keyring', 9, 'black_heart'),
    (8, '산리오', '쿠로미 얼굴 키링', 'keyring', 12, 'black_heart'),
    (9, '산리오', '쿠로미 쿠션 인형', 'doll', 10, 'horns'),
    (10, '산리오', '쿠로미 아크릴 스탠드', 'acrylic', 11, 'horns'),
    (11, '치이카와', '치이카와 마스코트 키링', 'keyring', 7, 'hamster'),
    (12, '치이카와', '하치와레 랜덤 키링 (블라인드)', 'random', 8, 'cat'),
    (13, '치이카와', '치이카와 · 하치와레 · 우사기 아크릴 키링 세트', 'keyring', 13, 'sparkles'),
    (14, '치이카와', '우사기 쿠지 B상 키링', 'keyring', 14, 'rabbit'),
    (15, '포켓몬스터', '피카츄 인형', 'doll', 15, 'bolt'),
    (16, '포켓몬스터', '이브이 피규어', 'figure', 16, 'sparkles'),
    (17, '기동전사 건담', 'RG 1/144 RX-78-2 건담', 'plamodel', 17, 'robot'),
    (18, '기동전사 건담', 'HG 1/144 자쿠 II', 'plamodel', 18, 'alien'),
    (19, '단보', '리볼텍 단보 피규어', 'figure', 19, 'package'),
    (20, 'Fate', '세이버 피규어', 'figure', 20, 'swords')
) AS p (ord, ip, name, type, new_rank, emoji)
JOIN catalog.ip ip ON ip.name = p.ip
ORDER BY p.ord;

INSERT INTO catalog.product_character (product_id, character_id)
SELECT p.id, c.id
FROM (VALUES
    ('쿠로미 마스코트 인형', '쿠로미'),
    ('치이카와 마스코트 인형', '치이카와'),
    ('헬로키티 인형 M', '헬로키티'),
    ('마이멜로디 & 쿠로미 아크릴 스탠드', '마이멜로디'),
    ('마이멜로디 & 쿠로미 아크릴 스탠드', '쿠로미'),
    ('시나모롤 미니 피규어', '시나모롤'),
    ('쿠로미 마스코트 인형 키링', '쿠로미'),
    ('쿠로미 방울 키링', '쿠로미'),
    ('쿠로미 얼굴 키링', '쿠로미'),
    ('쿠로미 쿠션 인형', '쿠로미'),
    ('쿠로미 아크릴 스탠드', '쿠로미'),
    ('치이카와 마스코트 키링', '치이카와'),
    ('하치와레 랜덤 키링 (블라인드)', '하치와레'),
    ('치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '치이카와'),
    ('치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '하치와레'),
    ('치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '우사기'),
    ('우사기 쿠지 B상 키링', '우사기'),
    ('피카츄 인형', '피카츄'),
    ('이브이 피규어', '이브이'),
    ('RG 1/144 RX-78-2 건담', 'RX-78-2 건담'),
    ('HG 1/144 자쿠 II', '자쿠 II'),
    ('리볼텍 단보 피규어', '단보'),
    ('세이버 피규어', '세이버')
) AS pc (product, character)
JOIN catalog.product p ON p.name = pc.product
JOIN catalog.character c ON c.name = pc.character AND c.ip_id = p.ip_id;

INSERT INTO catalog.variant (product_id, name, attrs, is_default)
SELECT p.id, v.name, v.attrs::jsonb, v.is_default
FROM (VALUES
    (1, '쿠로미 마스코트 인형', '일반 10cm', '{"size_cm": 10}', true),
    (2, '쿠로미 마스코트 인형', '빅 20cm', '{"size_cm": 20}', false),
    (3, '치이카와 마스코트 인형', '일반', NULL, true),
    (4, '헬로키티 인형 M', 'M', '{"size": "M"}', true),
    (5, '마이멜로디 & 쿠로미 아크릴 스탠드', '단품', NULL, true),
    (6, '시나모롤 미니 피규어', '미니', NULL, true),
    (7, '쿠로미 마스코트 인형 키링', '단품', NULL, true),
    (8, '쿠로미 방울 키링', '단품', NULL, true),
    (9, '쿠로미 얼굴 키링', '단품', NULL, true),
    (10, '쿠로미 쿠션 인형', 'M', '{"size": "M"}', true),
    (11, '쿠로미 쿠션 인형', 'L', '{"size": "L"}', false),
    (12, '쿠로미 아크릴 스탠드', '단품', NULL, true),
    (13, '치이카와 마스코트 키링', '단품', NULL, true),
    (14, '하치와레 랜덤 키링 (블라인드)', '랜덤 1종', NULL, true),
    (15, '치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '3종 세트', NULL, true),
    (16, '우사기 쿠지 B상 키링', 'B상', '{"prize": "B"}', true),
    (17, '피카츄 인형', 'M', '{"size": "M"}', true),
    (18, '이브이 피규어', '단품', NULL, true),
    (19, 'RG 1/144 RX-78-2 건담', 'Ver. 2.0', '{"edition": "2.0"}', true),
    (20, 'RG 1/144 RX-78-2 건담', '구판', '{"edition": "old"}', false),
    (21, 'HG 1/144 자쿠 II', '단품', NULL, true),
    (22, '리볼텍 단보 피규어', '일반 13cm', '{"size_cm": 13}', true),
    (23, '리볼텍 단보 피규어', '미니 8cm', '{"size_cm": 8}', false),
    (24, '세이버 피규어', '갑옷 ver.', '{"outfit": "armor"}', true),
    (25, '세이버 피규어', '드레스 ver.', '{"outfit": "dress"}', false)
) AS v (ord, product, name, attrs, is_default)
JOIN catalog.product p ON p.name = v.product
ORDER BY v.ord;

-- ------------------------------------------------------------ online
INSERT INTO online.mall (name, site_url, source, api_name, crawl_allowed) VALUES
    ('오픈마켓 A', 'https://mall-a.example', 'api', '가상 API', false),
    ('오픈마켓 B', 'https://mall-b.example', 'api', '가상 API', false),
    ('공식 온라인몰', 'https://official.example', 'crawl', NULL, false),
    ('굿즈 전문몰 C', 'https://mall-c.example', 'crawl', NULL, false),
    ('캐릭터 전문몰 D', 'https://mall-d.example', 'crawl', NULL, false);

INSERT INTO online.offer (variant_id, mall_id, title, url, price, shipping_fee, sold_out, source, observed_at)
SELECT v.id, m.id, p.name || ' ' || v.name,
       m.site_url || '/goods/' || v.id,
       o.price, o.shipping, o.sold_out, m.source, now() - o.ago::interval
FROM (VALUES
    ('쿠로미 마스코트 인형', '일반 10cm', '오픈마켓 A', 12900, 0, false, '20 minutes'),
    ('쿠로미 마스코트 인형', '일반 10cm', '오픈마켓 B', 11900, 3000, false, '1 hour'),
    ('쿠로미 마스코트 인형', '일반 10cm', '공식 온라인몰', 15000, 0, false, '3 hours'),
    ('쿠로미 마스코트 인형', '일반 10cm', '굿즈 전문몰 C', 0, 0, true, '1 day'),
    ('쿠로미 마스코트 인형', '빅 20cm', '오픈마켓 A', 24900, 0, false, '20 minutes'),
    ('쿠로미 마스코트 인형', '빅 20cm', '공식 온라인몰', 26000, 0, false, '3 hours'),
    ('치이카와 마스코트 인형', '일반', '공식 온라인몰', 18500, 0, false, '1 hour'),
    ('치이카와 마스코트 인형', '일반', '오픈마켓 A', 17500, 2500, false, '30 minutes'),
    ('치이카와 마스코트 인형', '일반', '오픈마켓 B', 21000, 0, false, '2 hours'),
    ('헬로키티 인형 M', 'M', '오픈마켓 A', 19000, 0, false, '10 minutes'),
    ('헬로키티 인형 M', 'M', '오픈마켓 B', 17900, 3000, false, '1 hour'),
    ('헬로키티 인형 M', 'M', '공식 온라인몰', 22000, 0, false, '1 day'),
    ('헬로키티 인형 M', 'M', '굿즈 전문몰 C', 21500, 0, false, '1 day'),
    ('헬로키티 인형 M', 'M', '캐릭터 전문몰 D', 23000, 0, false, '2 days'),
    ('마이멜로디 & 쿠로미 아크릴 스탠드', '단품', '공식 온라인몰', 15000, 0, false, '3 hours'),
    ('마이멜로디 & 쿠로미 아크릴 스탠드', '단품', '오픈마켓 A', 16500, 0, false, '1 hour'),
    ('쿠로미 마스코트 인형 키링', '단품', '오픈마켓 A', 12900, 0, false, '1 hour'),
    ('쿠로미 마스코트 인형 키링', '단품', '공식 온라인몰', 13000, 0, false, '1 day'),
    ('쿠로미 얼굴 키링', '단품', '오픈마켓 B', 8900, 0, false, '2 hours'),
    ('쿠로미 쿠션 인형', 'M', '공식 온라인몰', 21000, 0, false, '1 day'),
    ('쿠로미 쿠션 인형', 'L', '공식 온라인몰', 32000, 0, false, '1 day'),
    ('쿠로미 아크릴 스탠드', '단품', '공식 온라인몰', 15000, 0, false, '3 hours'),
    ('치이카와 마스코트 키링', '단품', '오픈마켓 A', 9900, 0, false, '20 minutes'),
    ('치이카와 마스코트 키링', '단품', '오픈마켓 B', 8900, 2500, false, '1 hour'),
    ('치이카와 마스코트 키링', '단품', '공식 온라인몰', 11000, 0, false, '1 day'),
    ('치이카와 마스코트 키링', '단품', '굿즈 전문몰 C', 10500, 0, false, '1 day'),
    ('하치와레 랜덤 키링 (블라인드)', '랜덤 1종', '오픈마켓 A', 9000, 0, false, '30 minutes'),
    ('하치와레 랜덤 키링 (블라인드)', '랜덤 1종', '공식 온라인몰', 9500, 0, false, '1 day'),
    ('하치와레 랜덤 키링 (블라인드)', '랜덤 1종', '오픈마켓 B', 7900, 3000, false, '2 hours'),
    ('치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '3종 세트', '공식 온라인몰', 14500, 0, false, '1 day'),
    ('치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '3종 세트', '오픈마켓 A', 15900, 0, false, '1 hour'),
    ('피카츄 인형', 'M', '오픈마켓 B', 21000, 3000, false, '1 hour'),
    ('피카츄 인형', 'M', '공식 온라인몰', 21000, 0, false, '1 day'),
    ('피카츄 인형', 'M', '오픈마켓 A', 23500, 0, false, '20 minutes'),
    ('이브이 피규어', '단품', '오픈마켓 A', 32000, 0, false, '1 hour'),
    ('RG 1/144 RX-78-2 건담', 'Ver. 2.0', '오픈마켓 A', 39800, 0, false, '10 minutes'),
    ('RG 1/144 RX-78-2 건담', 'Ver. 2.0', '공식 온라인몰', 41000, 0, false, '1 day'),
    ('RG 1/144 RX-78-2 건담', '구판', '오픈마켓 B', 29000, 3000, false, '2 hours'),
    ('HG 1/144 자쿠 II', '단품', '오픈마켓 A', 16000, 0, false, '1 hour'),
    ('리볼텍 단보 피규어', '일반 13cm', '오픈마켓 A', 25000, 0, false, '1 hour'),
    ('리볼텍 단보 피규어', '일반 13cm', '공식 온라인몰', 27000, 0, false, '1 day'),
    ('리볼텍 단보 피규어', '일반 13cm', '굿즈 전문몰 C', 26500, 0, false, '1 day'),
    ('리볼텍 단보 피규어', '미니 8cm', '오픈마켓 A', 12000, 0, false, '1 hour'),
    ('리볼텍 단보 피규어', '미니 8cm', '오픈마켓 B', 11000, 2500, false, '2 hours'),
    ('리볼텍 단보 피규어', '미니 8cm', '공식 온라인몰', 14000, 0, false, '1 day'),
    ('리볼텍 단보 피규어', '미니 8cm', '굿즈 전문몰 C', 13500, 0, false, '1 day'),
    ('세이버 피규어', '갑옷 ver.', '오픈마켓 A', 36000, 0, false, '1 hour'),
    ('세이버 피규어', '갑옷 ver.', '공식 온라인몰', 38000, 0, false, '1 day'),
    ('세이버 피규어', '드레스 ver.', '오픈마켓 A', 39000, 0, false, '1 hour')
) AS o (product, variant, mall, price, shipping, sold_out, ago)
JOIN catalog.product p ON p.name = o.product
JOIN catalog.variant v ON v.product_id = p.id AND v.name = o.variant
JOIN online.mall m ON m.name = o.mall;

-- 가격 기록: 쿠로미 마스코트 인형 오픈마켓 A 15,900원 → 12,900원 (가격 하락 알림 예시)
INSERT INTO online.offer_history (offer_id, price, shipping_fee, sold_out, observed_at)
SELECT o.id, h.price, 0, false, now() - h.ago::interval
FROM (VALUES (15900, '2 days'), (12900, '20 minutes')) AS h (price, ago)
CROSS JOIN online.offer o
JOIN online.mall m ON m.id = o.mall_id AND m.name = '오픈마켓 A'
JOIN catalog.variant v ON v.id = o.variant_id AND v.name = '일반 10cm'
JOIN catalog.product p ON p.id = v.product_id AND p.name = '쿠로미 마스코트 인형';

INSERT INTO online.offer_history (offer_id, price, shipping_fee, sold_out, observed_at)
SELECT o.id, o.price, o.shipping_fee, o.sold_out, o.observed_at
FROM online.offer o
WHERE NOT EXISTS (SELECT 1 FROM online.offer_history h WHERE h.offer_id = o.id);

-- ------------------------------------------------------------ offline
INSERT INTO offline.store (name, kind, address, location, phone, hours, popup_until, info_source, updated_at)
SELECT s.name, s.kind, s.address,
       ST_SetSRID(ST_MakePoint(s.lng, s.lat), 4326)::geography,
       s.phone, s.hours::jsonb, s.popup_until::date, s.info_source, s.updated_at::timestamptz
FROM (VALUES
    ('피규어샵 용산점', '피규어·프라모델', '서울 용산구 (가상 주소) 2', 37.5299, 126.9648, '02-000-1002',
     '{"mon": {"open": "10:30", "close": "20:30"}, "tue": null, "wed": {"open": "10:30", "close": "20:30"}, "thu": {"open": "10:30", "close": "20:30"}, "fri": {"open": "10:30", "close": "20:30"}, "sat": {"open": "10:30", "close": "20:30"}, "sun": {"open": "10:30", "close": "20:30"}}',
     NULL, 'owner', '2026-10-28 10:00+09'),
    ('굿즈샵 홍대점', '캐릭터샵', '서울 마포구 (가상 주소) 15', 37.5563, 126.9236, '02-000-2041',
     '{"mon": {"open": "11:00", "close": "21:00"}, "tue": {"open": "11:00", "close": "21:00"}, "wed": {"open": "11:00", "close": "21:00"}, "thu": {"open": "11:00", "close": "21:00"}, "fri": {"open": "11:00", "close": "21:00"}, "sat": {"open": "11:00", "close": "21:00"}, "sun": {"open": "11:00", "close": "21:00"}}',
     NULL, 'owner', '2026-10-25 10:00+09'),
    ('치이카와 팝업 성수', '팝업', '서울 성동구 (가상 주소) 7', 37.5446, 127.0559, '02-000-5200',
     '{"mon": {"open": "11:00", "close": "20:00"}, "tue": {"open": "11:00", "close": "20:00"}, "wed": {"open": "11:00", "close": "20:00"}, "thu": {"open": "11:00", "close": "20:00"}, "fri": {"open": "11:00", "close": "20:00"}, "sat": {"open": "11:00", "close": "20:00"}, "sun": {"open": "11:00", "close": "20:00"}}',
     '2026-11-30', 'crawl', '2026-10-26 10:00+09'),
    ('키덜트샵 건대점', '종합 굿즈', '서울 광진구 (가상 주소) 31', 37.5404, 127.0692, '02-000-5631',
     '{"mon": null, "tue": {"open": "12:00", "close": "21:00"}, "wed": {"open": "12:00", "close": "21:00"}, "thu": {"open": "12:00", "close": "21:00"}, "fri": {"open": "12:00", "close": "21:00"}, "sat": {"open": "12:00", "close": "21:00"}, "sun": {"open": "12:00", "close": "21:00"}}',
     NULL, 'crawl', '2026-10-20 10:00+09'),
    ('캐릭터스토어 강남점', '캐릭터샵', '서울 강남구 (가상 주소) 63', 37.4979, 127.0276, '02-000-6302',
     '{"mon": {"open": "10:00", "close": "22:00"}, "tue": {"open": "10:00", "close": "22:00"}, "wed": {"open": "10:00", "close": "22:00"}, "thu": {"open": "10:00", "close": "22:00"}, "fri": {"open": "10:00", "close": "22:00"}, "sat": {"open": "10:00", "close": "22:00"}, "sun": {"open": "10:00", "close": "22:00"}}',
     NULL, 'crawl', '2026-10-24 10:00+09')
) AS s (name, kind, address, lat, lng, phone, hours, popup_until, info_source, updated_at);

INSERT INTO offline.stock (store_id, variant_id, status, source, confirmed_at)
SELECT st.id, v.id, x.status, x.source, now() - x.ago::interval
FROM (VALUES
    ('피규어샵 용산점', 'RG 1/144 RX-78-2 건담', 'Ver. 2.0', 'many', 'owner', '2 hours'),
    ('피규어샵 용산점', 'RG 1/144 RX-78-2 건담', '구판', 'few', 'owner', '2 hours'),
    ('피규어샵 용산점', 'HG 1/144 자쿠 II', '단품', 'few', 'owner', '2 hours'),
    ('피규어샵 용산점', '세이버 피규어', '갑옷 ver.', 'few', 'report', '1 day'),
    ('피규어샵 용산점', '세이버 피규어', '드레스 ver.', 'many', 'owner', '2 hours'),
    ('피규어샵 용산점', '리볼텍 단보 피규어', '미니 8cm', 'unknown', 'crawl', '3 days'),
    ('굿즈샵 홍대점', '쿠로미 마스코트 인형', '일반 10cm', 'many', 'owner', '2 hours'),
    ('굿즈샵 홍대점', '헬로키티 인형 M', 'M', 'many', 'owner', '2 hours'),
    ('굿즈샵 홍대점', '시나모롤 미니 피규어', '미니', 'few', 'owner', '2 hours'),
    ('굿즈샵 홍대점', '쿠로미 방울 키링', '단품', 'many', 'owner', '2 hours'),
    ('굿즈샵 홍대점', '치이카와 마스코트 키링', '단품', 'few', 'report', '1 day'),
    ('치이카와 팝업 성수', '치이카와 마스코트 인형', '일반', 'many', 'report', '3 hours'),
    ('치이카와 팝업 성수', '치이카와 마스코트 키링', '단품', 'many', 'report', '3 hours'),
    ('치이카와 팝업 성수', '하치와레 랜덤 키링 (블라인드)', '랜덤 1종', 'few', 'report', '1 day'),
    ('치이카와 팝업 성수', '우사기 쿠지 B상 키링', 'B상', 'many', 'report', '3 hours'),
    ('키덜트샵 건대점', '쿠로미 마스코트 인형', '일반 10cm', 'few', 'report', '1 day'),
    ('키덜트샵 건대점', '헬로키티 인형 M', 'M', 'unknown', 'crawl', '4 days'),
    ('키덜트샵 건대점', '치이카와 마스코트 키링', '단품', 'unknown', 'crawl', '3 days'),
    ('키덜트샵 건대점', '하치와레 랜덤 키링 (블라인드)', '랜덤 1종', 'unknown', 'crawl', '5 days'),
    ('캐릭터스토어 강남점', '쿠로미 마스코트 인형', '일반 10cm', 'unknown', 'crawl', '3 days'),
    ('캐릭터스토어 강남점', '헬로키티 인형 M', 'M', 'few', 'report', '1 day'),
    ('캐릭터스토어 강남점', '피카츄 인형', 'M', 'none', 'owner', '30 minutes')
) AS x (store, product, variant, status, source, ago)
JOIN offline.store st ON st.name = x.store
JOIN catalog.product p ON p.name = x.product
JOIN catalog.variant v ON v.product_id = p.id AND v.name = x.variant;

-- ------------------------------------------------------------ account
INSERT INTO account.app_user (email, password_hash, nickname, home_area, role, agree_location, agree_push) VALUES
    ('goods@example.com', '$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw', '굿즈러버', '용산구', 'user', true, true),
    ('owner.yongsan@example.com', '$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw', '용산점 사장님', '용산구', 'seller', false, true),
    ('owner.hongdae@example.com', '$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw', '홍대점 사장님', '마포구', 'seller', false, true),
    ('admin@example.com', '$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw', '운영자', NULL, 'admin', false, false),
    ('reporter1@example.com', '$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw', '제보왕', '성동구', 'user', true, false),
    ('reporter2@example.com', '$argon2id$v=19$m=65536,t=3,p=4$nCbEVyH2YEnS/wMzp4klLw$Pi5wfIqeRPUo1hXZZFyBEj43IhnlkYefb0LWNBrInCw', '피규어수집가', '광진구', 'user', true, false);

INSERT INTO account.seller_member (user_id, store_id, role, verified_at)
SELECT u.id, s.id, 'owner', '2026-10-01 10:00+09'
FROM (VALUES ('owner.yongsan@example.com', '피규어샵 용산점'), ('owner.hongdae@example.com', '굿즈샵 홍대점')) AS x (email, store)
JOIN account.app_user u ON u.email = x.email
JOIN offline.store s ON s.name = x.store;

INSERT INTO account.user_ip (user_id, ip_id, sort_order)
SELECT u.id, ip.id, x.ord
FROM (VALUES ('산리오', 1), ('치이카와', 2), ('포켓몬스터', 3), ('기동전사 건담', 4), ('단보', 5), ('Fate', 6)) AS x (ip, ord)
JOIN catalog.ip ip ON ip.name = x.ip
CROSS JOIN account.app_user u
WHERE u.email = 'goods@example.com';

-- 찜 · 알림 · 저장한 매장 (frontend/lib/app/app_state.dart 기본값)
INSERT INTO account.wishlist (user_id, variant_id)
SELECT u.id, v.id
FROM account.app_user u
JOIN catalog.product p ON p.name IN ('쿠로미 마스코트 인형', '치이카와 마스코트 키링', '헬로키티 인형 M', 'RG 1/144 RX-78-2 건담', '우사기 쿠지 B상 키링')
JOIN catalog.variant v ON v.product_id = p.id AND v.is_default
WHERE u.email = 'goods@example.com';

INSERT INTO account.alert (user_id, variant_id, type, target_price)
SELECT u.id, v.id, x.type, x.target_price
FROM (VALUES
    ('쿠로미 마스코트 인형', 'price', 13000),
    ('치이카와 마스코트 인형', 'restock', NULL),
    ('RG 1/144 RX-78-2 건담', 'price', 38000)
) AS x (product, type, target_price)
JOIN catalog.product p ON p.name = x.product
JOIN catalog.variant v ON v.product_id = p.id AND v.is_default
CROSS JOIN account.app_user u
WHERE u.email = 'goods@example.com';

INSERT INTO account.saved_store (user_id, store_id)
SELECT u.id, s.id
FROM account.app_user u
JOIN offline.store s ON s.name IN ('피규어샵 용산점', '굿즈샵 홍대점')
WHERE u.email = 'goods@example.com';

-- 받은 알림
INSERT INTO account.notification (user_id, type, title, body, link, image_url, read_at, created_at)
SELECT u.id, n.type, n.title, n.body, n.link, n.image_url,
       CASE WHEN n.unread THEN NULL ELSE now() END, now() - n.ago::interval
FROM (VALUES
    ('price', '쿠로미 마스코트 인형 가격 하락', '오픈마켓 A 15,900원 → 12,900원',
     '/products/' || (SELECT id FROM catalog.product WHERE name = '쿠로미 마스코트 인형'), 'emoji:horns', true, '10 minutes'),
    ('restock', '치이카와 마스코트 인형 재입고', '공식 온라인몰에 다시 들어왔어요',
     '/products/' || (SELECT id FROM catalog.product WHERE name = '치이카와 마스코트 인형'), 'emoji:hamster', true, '1 hour'),
    ('stock_in', '피규어샵 용산점에 건담 입고', '저장한 매장 · 내 IP 굿즈',
     '/stores/' || (SELECT id FROM offline.store WHERE name = '피규어샵 용산점'), 'emoji:robot', false, '3 hours'),
    ('report', '재고 제보가 반영됐어요', '캐릭터스토어 강남점 · 재고 적음',
     '/stores/' || (SELECT id FROM offline.store WHERE name = '캐릭터스토어 강남점'), NULL, false, '1 day'),
    ('issue', '문의에 답변이 왔어요', '10/27 오픈마켓 A 가격 문의', '/me/issues', NULL, false, '2 days'),
    ('new_goods', '내 IP 새 굿즈', '산리오 신상품 4개가 등록됐어요',
     '/ips/' || (SELECT id FROM catalog.ip WHERE name = '산리오'), NULL, false, '3 days')
) AS n (type, title, body, link, image_url, unread, ago)
CROSS JOIN account.app_user u
WHERE u.email = 'goods@example.com';

-- 이동 기록 (구매하러 가기를 누른 시점의 가격)
INSERT INTO account.outbound_click (user_id, offer_id, variant_id, price_snapshot, shipping_snapshot, clicked_at)
SELECT u.id, o.id, v.id, x.price, x.shipping, x.clicked_at::timestamptz
FROM (VALUES
    ('RG 1/144 RX-78-2 건담', 'Ver. 2.0', '오픈마켓 A', 39800, 0, '2026-10-27 21:14+09'),
    ('쿠로미 마스코트 인형', '일반 10cm', '공식 온라인몰', 15000, 0, '2026-10-25 13:02+09'),
    ('피카츄 인형', 'M', '오픈마켓 B', 21000, 3000, '2026-10-20 18:40+09')
) AS x (product, variant, mall, price, shipping, clicked_at)
JOIN catalog.product p ON p.name = x.product
JOIN catalog.variant v ON v.product_id = p.id AND v.name = x.variant
JOIN online.mall m ON m.name = x.mall
JOIN online.offer o ON o.variant_id = v.id AND o.mall_id = m.id
CROSS JOIN account.app_user u
WHERE u.email = 'goods@example.com';

INSERT INTO account.purchase (user_id, variant_id, click_id, price, purchased_on)
SELECT c.user_id, c.variant_id, c.id, c.price_snapshot + c.shipping_snapshot, DATE '2026-10-27'
FROM account.outbound_click c
JOIN catalog.variant v ON v.id = c.variant_id AND v.name = 'Ver. 2.0';

INSERT INTO account.issue (user_id, click_id, purchase_id, type, content, price_now, state, answer, created_at)
SELECT p.user_id, p.click_id, p.id, 'price', '결제 화면에서 41,000원으로 나왔어요', 39800, 'answered',
       '판매처에 확인해 보니 쿠폰 적용 전 가격이 수집됐어요. 가격 정보를 고쳤어요.', '2026-10-27 22:00+09'
FROM account.purchase p
WHERE p.click_id IS NOT NULL;

-- 재고 제보: 굿즈러버의 반영된 제보 2건, 용산점 사장님이 확인할 제보 2건
INSERT INTO offline.stock_report (store_id, variant_id, user_id, status, state, resolved_by, created_at)
SELECT s.id, v.id, u.id, x.status, x.state, r.id, x.created_at::timestamptz
FROM (VALUES
    ('캐릭터스토어 강남점', '헬로키티 인형 M', 'M', 'goods@example.com', 'few', 'approved', 'admin@example.com', '2026-10-28 15:00+09'),
    ('키덜트샵 건대점', '쿠로미 마스코트 인형', '일반 10cm', 'goods@example.com', 'few', 'approved', NULL, '2026-10-22 17:30+09'),
    ('피규어샵 용산점', 'HG 1/144 자쿠 II', '단품', 'reporter1@example.com', 'none', 'pending', NULL, '2026-11-19 18:10+09'),
    ('피규어샵 용산점', '리볼텍 단보 피규어', '미니 8cm', 'reporter2@example.com', 'few', 'pending', NULL, '2026-11-19 19:30+09')
) AS x (store, product, variant, email, status, state, resolver, created_at)
JOIN offline.store s ON s.name = x.store
JOIN catalog.product p ON p.name = x.product
JOIN catalog.variant v ON v.product_id = p.id AND v.name = x.variant
JOIN account.app_user u ON u.email = x.email
LEFT JOIN account.app_user r ON r.email = x.resolver;

COMMIT;
