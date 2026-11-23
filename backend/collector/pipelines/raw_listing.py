"""크롤링 결과 → ingest.raw_listing, 몰마다 ingest.collect_job 기록 (+ 관리자 페이지 실행이면 단계별 기록)"""

from __future__ import annotations

from typing import Any

from scrapy.exceptions import DropItem

import config
import db
from events import RunLog, won
from listing import Listing


class RawListingPipeline:
    def open_spider(self, spider: Any) -> None:
        self.conn = db.connect(config.database_url())
        self.run_id: int | None = getattr(spider, "run_id", None)
        self.log = RunLog(self.conn, self.run_id)
        self.mall_ids: dict[str, int | None] = {}
        self.jobs: dict[str, int] = {}
        self.counts: dict[str, int] = {}

    def _mall_id(self, name: str) -> int | None:
        if name not in self.mall_ids:
            self.mall_ids[name] = db.mall_id_by_name(self.conn, name)
        return self.mall_ids[name]

    def _job(self, mall: str) -> int:
        if mall not in self.jobs:
            self.jobs[mall] = db.start_job(self.conn, self._mall_id(mall), "crawl", self.run_id)
            self.counts[mall] = 0
        return self.jobs[mall]

    def process_item(self, item: Listing, spider: Any) -> Listing:
        listing = item
        mall_id = self._mall_id(listing.mall_name)
        if mall_id is None:
            raise DropItem(f"online.mall에 없는 몰: {listing.mall_name}")
        job_id = self._job(listing.mall_name)
        r = db.save_listing(self.conn, mall_id, listing, job_id)
        self.counts[listing.mall_name] += 1
        if r.offer_id is None:
            msg = f"저장 #{r.raw_id} {listing.title} · {won(listing.price)} → 새 주소라 매칭 대기"
        elif r.price_changed:
            msg = f"저장 #{r.raw_id} {listing.title} → 이미 연결된 판매처 가격 갱신 {won(r.old_price)} → {won(listing.price)}"
        else:
            msg = f"저장 #{r.raw_id} {listing.title} → 이미 연결된 판매처, 가격 그대로 {won(listing.price)}"
        self.log.emit("save", msg, raw_id=r.raw_id, offer_id=r.offer_id, price_changed=r.price_changed, mall=listing.mall_name)
        return item

    def close_spider(self, spider: Any) -> None:
        # 결과가 하나도 없던 몰도 실행 기록을 남긴다 (실패 이유 포함)
        for site in getattr(spider, "targets", []):
            self._job(site.mall)
        for mall, job_id in self.jobs.items():
            errors = getattr(spider, "errors", {}).get(mall, [])
            count = self.counts.get(mall, 0)
            error = "; ".join(errors)[:1000] if errors and count == 0 else None
            db.finish_job(self.conn, job_id, count, error)
            self.log.emit(
                "done",
                f"{mall}: {count}건 저장" + (f" (실패: {error[:120]})" if error else ""),
                level="error" if error else "info",
                mall=mall,
            )
        self.conn.close()
