"""데모 수집 대상 서버 세 개 (모두 이 PC 안에서만 뜬다)

- 데모 몰 A: 서버가 HTML을 그려 주는 몰 → Scrapy 일반 요청으로 읽힌다
- 데모 몰 B: 빈 HTML을 주고 자바스크립트가 목록을 그리는 몰 → Playwright(Chromium)가 있어야 읽힌다
- 쿠팡 형식 테스트 서버: 쿠팡 파트너스 상품 검색과 같은 경로 · 응답 모양. HMAC 서명이 틀리면 401
"""

from __future__ import annotations

import hashlib
import hmac
import html
import json
import re
import threading
from datetime import UTC, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

from demo import data

DEMO_ACCESS_KEY = "demo-access-key"
DEMO_SECRET_KEY = "demo-secret-key"
SEARCH_PATH = "/v2/providers/affiliate_open_api/apis/openapi/products/search"
_AUTH = re.compile(
    r"^CEA algorithm=HmacSHA256, access-key=(?P<ak>[^,]+), signed-date=(?P<date>\d{6}T\d{6}Z), signature=(?P<sig>[0-9a-f]{64})$"
)


def won(v: int) -> str:
    return f"{v:,}원"


def shipping_text(v: int | None) -> str:
    return "" if v is None else ("무료배송" if v == 0 else f"배송비 {won(v)}")


def svg(item_id: int, title: str) -> bytes:
    hue = item_id * 47 % 360
    ch = html.escape(title.replace("[", "").strip()[:1])
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="160"><rect width="160" height="160" rx="24" fill="hsl({hue},70%,88%)"/>'
        f'<text x="80" y="100" font-size="64" text-anchor="middle" fill="hsl({hue},45%,35%)">{ch}</text></svg>'
    ).encode()


class _Base(BaseHTTPRequestHandler):
    robots = "User-agent: *\nAllow: /\n"
    quiet = True

    def log_message(self, fmt: str, *args) -> None:
        if not self.quiet:
            super().log_message(fmt, *args)

    def send(self, status: int, body: bytes, ctype: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def html(self, body: str, status: int = 200) -> None:
        self.send(status, body.encode(), "text/html; charset=utf-8")

    def json(self, obj: object, status: int = 200) -> None:
        self.send(status, json.dumps(obj, ensure_ascii=False).encode(), "application/json; charset=utf-8")

    def query(self) -> tuple[str, dict[str, list[str]]]:
        u = urlsplit(self.path)
        return u.path, parse_qs(u.query)

    def common(self, path: str, items: list[data.DemoItem]) -> bool:
        if path == "/robots.txt":
            self.send(200, self.robots.encode(), "text/plain; charset=utf-8")
            return True
        if m := re.fullmatch(r"/img/(\d+)\.svg", path):
            it = next((i for i in items if i.id == int(m.group(1))), None)
            self.send(200, svg(int(m.group(1)), it.title if it else "?"), "image/svg+xml")
            return True
        return False


class MallAHandler(_Base):
    """데모 몰 A — 정적 HTML"""

    robots = "User-agent: *\nDisallow: /cart\nDisallow: /admin\n"

    def do_GET(self) -> None:
        path, qs = self.query()
        if self.common(path, data.MALL_A):
            return
        if path == "/search":
            q = qs.get("q", [""])[0]
            rows = []
            for it in data.search(data.MALL_A, q):
                sold = '<span class="soldout">품절</span>' if it.sold_out else ""
                price = "" if it.sold_out else f'<span class="price">{won(it.current_price())}</span>'
                rows.append(
                    f'<li class="product"><a href="/goods/{it.id}"><img src="/img/{it.id}.svg" alt=""><span class="name">{html.escape(it.title)}</span></a>'
                    f'{price}<span class="shipping">{shipping_text(it.shipping)}</span>{sold}</li>'
                )
            self.html(
                f'<!doctype html><html lang="ko"><meta charset="utf-8"><title>데모 몰 A</title><h1>데모 몰 A</h1>'
                f'<p>“{html.escape(q)}” 검색 결과 {len(rows)}개</p><ul class="products">{"".join(rows)}</ul></html>'
            )
            return
        if m := re.fullmatch(r"/goods/(\d+)", path):
            it = next((i for i in data.MALL_A if i.id == int(m.group(1))), None)
            if it:
                self.html(f'<!doctype html><meta charset="utf-8"><h1>{html.escape(it.title)}</h1><p>{won(it.current_price())}</p>')
                return
        self.html("<h1>404</h1>", 404)


class MallBHandler(_Base):
    """데모 몰 B — 자바스크립트로 목록을 그린다 (HTML에는 상품이 없다)"""

    robots = "User-agent: *\nDisallow: /checkout\n"

    def do_GET(self) -> None:
        path, qs = self.query()
        if self.common(path, data.MALL_B):
            return
        if path == "/search":
            self.html(
                """<!doctype html><html lang="ko"><meta charset="utf-8"><title>데모 몰 B</title><h1>데모 몰 B</h1>
<div id="list">불러오는 중…</div>
<script>
const q = new URLSearchParams(location.search).get('keyword') || '';
setTimeout(async () => {
  const items = await (await fetch('/api/goods?keyword=' + encodeURIComponent(q))).json();
  document.getElementById('list').innerHTML = items.map(i =>
    `<div class="goods-card"><a href="/item/${i.id}"><b class="goods-name">${i.title}</b></a>` +
    `<em class="goods-price">${i.price.toLocaleString('ko-KR')}원</em><span class="goods-ship">${i.shipping}</span></div>`).join('');
}, 500);
</script></html>"""
            )
            return
        if path == "/api/goods":
            q = qs.get("keyword", [""])[0]
            self.json(
                [
                    {"id": i.id, "title": i.title, "price": i.current_price(), "shipping": shipping_text(i.shipping)}
                    for i in data.search(data.MALL_B, q)
                ]
            )
            return
        self.html("<h1>404</h1>", 404)


class CoupangHandler(_Base):
    """쿠팡 파트너스 상품 검색과 같은 경로 · 서명 규칙 · 응답 모양의 테스트 서버"""

    access_key = DEMO_ACCESS_KEY
    secret_key = DEMO_SECRET_KEY

    def do_GET(self) -> None:
        path, qs = self.query()
        if self.common(path, data.COUPANG):
            return
        if path != SEARCH_PATH:
            self.json({"rCode": "404", "rMessage": "Not Found"}, 404)
            return
        error = self.check_signature()
        if error:
            self.json({"rCode": "401", "rMessage": error}, 401)
            return
        keyword = qs.get("keyword", [""])[0]
        limit = max(1, min(int(qs.get("limit", ["10"])[0]), 10))
        base = f"http://{self.headers.get('Host')}"
        products = [
            {
                "productId": it.id,
                "productName": it.title,
                "productPrice": it.current_price(),
                "productImage": f"{base}/img/{it.id}.svg",
                "productUrl": f"{base}/vp/products/{it.id}?lptag=DEMO",
                "isRocket": it.rocket,
                "isFreeShipping": it.shipping == 0,
                "categoryName": "완구/취미",
                "rank": rank,
            }
            for rank, it in enumerate(data.search(data.COUPANG, keyword, limit), start=1)
        ]
        self.json({"rCode": "0", "rMessage": "", "data": {"landingUrl": f"{base}/np/search?q={keyword}", "productData": products}})

    def check_signature(self) -> str | None:
        m = _AUTH.match(self.headers.get("Authorization", ""))
        if not m:
            return "Authorization 헤더 형식이 다릅니다"
        if m["ak"] != self.access_key:
            return "access-key가 다릅니다"
        signed = datetime.strptime(m["date"], "%y%m%dT%H%M%SZ").replace(tzinfo=UTC)
        if abs((datetime.now(UTC) - signed).total_seconds()) > 600:
            return "signed-date가 10분 넘게 어긋났습니다"
        path, _, query = self.path.partition("?")
        expected = hmac.new(self.secret_key.encode(), f"{m['date']}GET{path}{query}".encode(), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, m["sig"]):
            return "Invalid signature"
        return None


def serve(handler: type[BaseHTTPRequestHandler], host: str, port: int) -> ThreadingHTTPServer:
    server = ThreadingHTTPServer((host, port), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server
