#!/usr/bin/env python3
"""굿모닝 FigCraft 프로토타입 생성기.

UI 구상 PPT(docs/02-screens.md)의 화면을 FigCraft 명령 스크립트로 그린 뒤 `figcraft-cli run`으로
`prototype/goodmorning.figcraft`를 만들고, 같은 세션에서 화면마다 PNG를 내보낸다.
정적 뷰어(prototype/site)는 여기서 쓰는 `screens.json`(화면 목록 · 클릭 영역)을 읽는다.

    python3 prototype/figcraft/build.py            # 저장소 루트에서

FigCraft는 flatpak(ai.storyteller.figcraft)으로 설치되어 있다고 본다.
다른 방식으로 설치했다면 FIGCRAFT_CLI 환경 변수에 실행 명령을 넣는다 (예: FIGCRAFT_CLI=figcraft-cli).
"""
import json
import math
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'frontend' / 'assets'
FONT_DIR = ASSETS / 'fonts'
EMOJI_DIR = ASSETS / 'emoji'
OUT_FIG = ROOT / 'prototype' / 'goodmorning.figcraft'
SITE = ROOT / 'prototype' / 'site'
SCREEN_DIR = SITE / 'screens'
WORK = ROOT / 'prototype' / 'figcraft' / '.build'

W, H = 390, 844
GAP_X, GAP_Y = 140, 260

# 색 (docs/01-screen-flow.md 공통 요소)
ORANGE, ORANGE_BG = '#FF7A2F', '#FFF0E6'
BLUE, BLUE_BG = '#2F6FED', '#E8F0FE'
GREEN, GREEN_BG = '#18A058', '#E4F6EC'
AMBER, AMBER_BG = '#B7791F', '#FFF5D6'
RED, RED_BG = '#E5484D', '#FDECEC'
INK, SUB = '#1F2329', '#8A8F98'
LINE, BG, WHITE = '#E3E6EA', '#F4F5F7', '#FFFFFF'

EMOJI = {
    'bell': 'bell', 'camera': 'camera', 'house': 'house', 'teddy': 'teddy_bear', 'pin': 'round_pushpin',
    'smile': 'slightly_smiling_face', 'globe': 'globe_with_meridians', 'gear': 'gear', 'star': 'star',
    'compass': 'compass', 'phone': 'telephone_receiver', 'link': 'link', 'cart': 'shopping_cart',
    'receipt': 'receipt', 'memo': 'memo', 'speech': 'speech_balloon', 'chart_down': 'chart_decreasing',
    'package': 'package', 'check': 'check_mark_button', 'warning': 'warning', 'store': 'department_store',
    'moai': 'moai', 'key': 'key', 'placard': 'placard', 'robot': 'robot', 'die': 'game_die',
    'ribbon': 'ribbon', 'hamster': 'hamster', 'bolt': 'high_voltage', 'swords': 'crossed_swords',
    'castle': 'castle', 'crayon': 'crayon', 'sailboat': 'sailboat', 'horns': 'smiling_face_with_horns',
    'cat': 'cat_face', 'rabbit': 'rabbit_face', 'cloud': 'cloud', 'alien': 'alien_monster',
    'sparkles': 'sparkles', 'black_heart': 'black_heart', 'red_heart': 'red_heart', 'bags': 'shopping_bags',
    'map': 'world_map', 'sunrise': 'sunrise', 'bookmark': 'bookmark', 'bulb': 'light_bulb',
    'party': 'party_popper', 'megaphone': 'megaphone', 'envelope': 'envelope', 'mobile': 'mobile_phone',
    'lock': 'locked', 'bust': 'bust_in_silhouette', 'magnifier': 'magnifying_glass_tilted_left',
    'camera_flash': 'camera_with_flash', 'picture': 'framed_picture',
}

# ---------------------------------------------------------------- 목업 데이터 (PPT 화면의 예시 값)
IPS = {
    'sanrio': ('산리오', 'ribbon', '#FCE4EC', '캐릭터 4 · 굿즈 128'),
    'chiikawa': ('치이카와', 'hamster', '#FDEBD9', '캐릭터 3 · 굿즈 86'),
    'pokemon': ('포켓몬스터', 'bolt', '#FFF6CC', '캐릭터 2 · 굿즈 210'),
    'gundam': ('기동전사 건담', 'robot', '#E3ECFA', '캐릭터 2 · 굿즈 64'),
    'danbo': ('단보', 'package', '#F0E4D7', '캐릭터 1 · 굿즈 12'),
    'fate': ('Fate', 'swords', '#E8EAF2', '캐릭터 1 · 굿즈 9'),
    'disney': ('디즈니', 'castle', '#E6EDF9', ''),
    'shinchan': ('짱구는 못말려', 'crayon', '#FFF0D6', ''),
    'onepiece': ('원피스', 'sailboat', '#FBE4E4', ''),
}
MY_IPS = ['sanrio', 'chiikawa', 'pokemon', 'gundam', 'danbo', 'fate']
OTHER_IPS = ['disney', 'shinchan', 'onepiece']

P = {  # id: (IP · 캐릭터, 이름, 이모지, 배경, 온라인 배지, 오프라인 배지)
    'kuromi': ('산리오 · 쿠로미', '쿠로미 마스코트 인형', 'horns', '#ECE0F5', '4곳 · 12,900원~', '근처 2곳 재고'),
    'chiikawa': ('치이카와 · 치이카와', '치이카와 마스코트 인형', 'hamster', '#FDEBD9', '3곳 · 18,500원~', '근처 1곳 재고'),
    'kitty': ('산리오 · 헬로키티', '헬로키티 인형 M', 'ribbon', '#FCE4EC', '5곳 · 19,000원~', '근처 3곳 재고'),
    'mymelo': ('산리오 · 마이멜로디, 쿠로미', '마이멜로디 & 쿠로미 아크릴 스탠드', 'rabbit', '#FBE3EF', '2곳 · 15,000원~', None),
    'cinna': ('산리오 · 시나모롤', '시나모롤 미니 피규어', 'cloud', '#E3F0FB', None, '근처 1곳 재고'),
    'kuromi_key': ('산리오 · 쿠로미', '쿠로미 방울 키링', 'black_heart', '#ECE0F5', None, '근처 2곳 재고'),
}

STORES = {
    'yongsan': ('피규어샵 용산점', '피규어·프라모델', '0.8km · 영업 중 · 20:30까지', ('green', '내 IP 굿즈 재고 1개'), None),
    'hongdae': ('굿즈샵 홍대점', '캐릭터샵', '4.1km · 영업 중 · 21:00까지', ('green', '내 IP 굿즈 재고 3개'), None),
    'popup': ('치이카와 팝업 성수', '팝업', '5.2km · 영업 중 · 20:00까지', ('green', '내 IP 굿즈 재고 2개'), '~11/30 종료'),
    'kondae': ('키덜트샵 건대점', '종합 굿즈', '5.6km · 영업 중 · 21:00까지', ('gray', '재고 확인 필요'), None),
}

STOCK = {  # 상태: (글자색, 배경, 이름)
    'many': (GREEN, GREEN_BG, '재고 많음'),
    'few': (AMBER, AMBER_BG, '재고 적음'),
    'none': (RED, RED_BG, '재고 없음'),
    'check': (SUB, BG, '확인 필요'),
}


# ---------------------------------------------------------------- 글자 폭 측정 (Pretendard)
class Fonts:
    def __init__(self):
        self.faces = {}
        for w in ('Regular', 'Medium', 'SemiBold', 'Bold'):
            f = TTFont(FONT_DIR / f'Pretendard-{w}.otf')
            self.faces[w] = (f.getBestCmap(), f['hmtx'], f['head'].unitsPerEm)

    def width(self, s, size, weight='Regular'):
        cmap, hmtx, upm = self.faces[weight]
        return sum(hmtx[cmap.get(ord(c), '.notdef')][0] for c in s) / upm * size

    def wrap(self, s, size, weight, maxw):
        lines = []
        for para in s.split('\n'):
            cur = ''
            for word in para.split(' '):
                cand = word if not cur else cur + ' ' + word
                if not cur or self.width(cand, size, weight) <= maxw:
                    cur = cand
                else:
                    lines.append(cur)
                    cur = word
            lines.append(cur)
        return lines


# ---------------------------------------------------------------- FigCraft 명령 스크립트
class Doc:
    def __init__(self):
        self.fonts = Fonts()
        self.cmds = []
        self.next_id = 2  # 새 문서에서 첫 레이어가 2번 (1번은 페이지)
        self.expect = []  # (step, 예상 id)
        self.screens = []
        self.cur = None
        self.quiet = False  # 오버레이 아래 깔리는 화면은 클릭 영역을 만들지 않는다
        for w in ('Regular', 'Medium', 'SemiBold', 'Bold'):
            self.cmds.append({'command': 'text.loadFont', 'params': {'path': str(FONT_DIR / f'Pretendard-{w}.otf')}})

    # -- 기본 레이어
    def _create(self, command, params):
        nid = self.next_id
        self.next_id += 1
        self.expect.append((len(self.cmds), nid))
        params.setdefault('select', False)
        self.cmds.append({'command': command, 'params': params})
        return nid

    def screen(self, slug, title, slide, desc, col, row, height=H):
        self.end_screen()
        x, y = col * (W + GAP_X), row * (H + GAP_Y)
        name = f'{slide} {title}' if slide else title
        fid = self._create('node.create', {'type': 'frame', 'name': name, 'x': x, 'y': y, 'width': W,
                                           'height': height, 'props': {'fill': WHITE, 'clip': True}})
        self.cur = {'slug': slug, 'title': title, 'slide': slide, 'desc': desc, 'id': fid,
                    'height': height, 'hotspots': [], 'pending': []}
        self.screens.append(self.cur)
        return self.cur

    def end_screen(self):
        """클릭 영역(투명 사각형)은 화면을 다 그린 뒤 맨 위에 올린다."""
        if not self.cur:
            return
        for (x, y, w, h, to) in self.cur['pending']:
            rid = self._create('node.create', {'type': 'rectangle', 'name': f'→ {to}', 'x': round(x), 'y': round(y),
                                               'width': round(w), 'height': round(h), 'parent': self.cur['id'],
                                               'props': {'fill': 'none'}})
            self.cur['hotspots'].append({'x': round(x), 'y': round(y), 'w': round(w), 'h': round(h), 'to': to, 'node': rid})
        self.cur['pending'] = []

    def rect(self, x, y, w, h, fill=WHITE, r=0, stroke=None, sw=1, dashes=None, opacity=None, name='box'):
        props = {'fill': fill if fill else 'none', 'cornerRadius': r}
        if stroke:
            props.update(stroke=stroke, strokeWeight=sw, strokeAlign='inside')
        if dashes:
            props['dashes'] = dashes
        if opacity is not None:
            props['opacity'] = opacity
        return self._create('node.create', {'type': 'rectangle', 'name': name, 'x': round(x, 1), 'y': round(y, 1),
                                            'width': round(w, 1), 'height': round(h, 1), 'parent': self.cur['id'], 'props': props})

    def ellipse(self, x, y, w, h, fill, stroke=None, sw=1, opacity=None):
        props = {'fill': fill}
        if stroke:
            props.update(stroke=stroke, strokeWeight=sw)
        if opacity is not None:
            props['opacity'] = opacity
        return self._create('node.create', {'type': 'ellipse', 'name': 'dot', 'x': round(x, 1), 'y': round(y, 1),
                                            'width': w, 'height': h, 'parent': self.cur['id'], 'props': props})

    def text(self, x, y, s, size=14, weight='Regular', color=INK, w=None, align='left', lh=None, wrap=None):
        """글자. 줄 높이를 px로 고정해 높이를 미리 안다. wrap=폭이면 단어 단위로 줄을 나눈다."""
        lh = lh or round(size * 1.4)
        if wrap:
            s = '\n'.join(self.fonts.wrap(s, size, weight, wrap))
        lines = s.split('\n')
        tw = max(self.fonts.width(line, size, weight) for line in lines)
        props = {'fontFamily': 'Pretendard', 'fontStyle': weight, 'fontSize': size, 'fill': color, 'lineHeight': lh}
        params = {'type': 'text', 'name': s.split('\n')[0][:24], 'x': round(x, 1), 'y': round(y, 1), 'text': s,
                  'parent': self.cur['id']}
        if w:
            props.update(textAlign=align, textAutoResize='height')
            params['width'] = round(w, 1)
        else:
            props['textAutoResize'] = 'widthAndHeight'
        params['props'] = props
        self._create('node.create', params)
        return tw, lh * len(lines)

    def emoji(self, key, x, y, size):
        return self._create('image.place', {'path': str(EMOJI_DIR / f'{EMOJI[key]}_3d.png'), 'x': round(x, 1),
                                            'y': round(y, 1), 'width': size, 'height': size, 'parent': self.cur['id']})

    def hs(self, x, y, w, h, to):
        if not self.quiet:
            self.cur['pending'].append((x, y, w, h, to))

    # -- 마무리: 클릭 연결, 흐름, 내보내기
    def finish(self, start_slug):
        self.end_screen()
        ids = {s['slug']: s['id'] for s in self.screens}
        for s in self.screens:
            for h in s['hotspots']:
                if h['to'] == 'back':
                    self.cmds.append({'command': 'proto.interaction.add', 'params': {
                        'id': h['node'], 'trigger': {'type': 'onClick'}, 'action': {'type': 'back'}}})
                else:
                    if h['to'] not in ids:
                        raise SystemExit(f"{s['slug']}: 없는 화면으로 연결 → {h['to']}")
                    self.cmds.append({'command': 'proto.interaction.add', 'params': {'id': h['node'], 'dest': ids[h['to']]}})
        self.cmds.append({'command': 'proto.flow.add', 'params': {'start': ids[start_slug], 'name': '굿모닝 프로토타입'}})
        self.cmds.append({'command': 'proto.settings', 'params': {'width': W, 'height': H}})
        for s in self.screens:
            self.cmds.append({'command': 'file.export', 'params': {
                'ids': [s['id']], 'format': 'png', 'scale': 2, 'path': str(SCREEN_DIR / f"{s['slug']}.png")}})


# ---------------------------------------------------------------- 공통 요소 (frontend/lib/components 와 같은 단위)
def pill(d, x, y, label, fg, bg, size=11, icon=None, h=22, padx=8, weight='SemiBold', r=None):
    tw = d.fonts.width(label, size, weight)
    isz = size + 3 if icon else 0
    wdt = padx * 2 + tw + (isz + 3 if icon else 0)
    d.rect(x, y, wdt, h, fill=bg, r=h / 2 if r is None else r)
    cx = x + padx
    if icon:
        d.emoji(icon, cx, y + (h - isz) / 2, isz)
        cx += isz + 3
    lh = round(size * 1.4)
    d.text(cx, y + (h - lh) / 2, label, size=size, weight=weight, color=fg)
    return wdt


def online_badge(d, x, y, label, size=11):
    return pill(d, x, y, label, BLUE, BLUE_BG, size=size, icon='globe')


def offline_badge(d, x, y, label, size=11):
    return pill(d, x, y, label, GREEN, GREEN_BG, size=size, icon='pin')


def stock_badge(d, x, y, status, source=None, right=None):
    fg, bg, label = STOCK[status]
    wdt = d.fonts.width(label, 12, 'SemiBold') + 16
    if right is not None:
        x = right - wdt
    pill(d, x, y, label, fg, bg, size=12, h=24)
    if source:
        sw_ = d.fonts.width(source, 11)
        d.text((right - sw_) if right is not None else x, y + 28, source, size=11, color=SUB)
    return wdt


def button(d, x, y, w, h, label, kind='primary', size=15, icon=None, to=None, r=None):
    styles = {
        'primary': (ORANGE, WHITE, None),
        'secondary': (WHITE, INK, LINE),
        'dark': (INK, WHITE, None),
        'disabled': (BG, '#B0B5BD', None),
        'green': (GREEN_BG, GREEN, None),
        'kakao': ('#FEE500', '#191919', None),
        'naver': ('#03C75A', WHITE, None),
        'apple': ('#000000', WHITE, None),
    }
    fill, fg, stroke = styles[kind]
    d.rect(x, y, w, h, fill=fill, r=h / 2 if r is None else r, stroke=stroke)
    weight = 'SemiBold'
    tw = d.fonts.width(label, size, weight)
    isz = size + 4 if icon else 0
    cw = tw + (isz + 6 if icon else 0)
    cx = x + (w - cw) / 2
    lh = round(size * 1.4)
    if icon:
        d.emoji(icon, cx, y + (h - isz) / 2, isz)
        cx += isz + 6
    d.text(cx, y + (h - lh) / 2, label, size=size, weight=weight, color=fg)
    if to:
        d.hs(x, y, w, h, to)


def app_bar(d, title, right=None, right_to=None, back='back'):
    d.text(14, 13, '‹', size=26, weight='Medium', color=INK, lh=30)
    d.hs(0, 0, 52, 56, back)
    d.text(44, 16, title, size=18, weight='Bold', lh=24)
    if right:
        tw = d.fonts.width(right, 14, 'Medium')
        d.text(W - 16 - tw, 18, right, size=14, weight='Medium', color=SUB, lh=20)
        if right_to:
            d.hs(W - 32 - tw, 0, tw + 32, 56, right_to)
    return 56


def section(d, y, title, more=None, more_to=None, sub=None):
    d.text(16, y, title, size=16, weight='Bold', lh=22)
    if sub:
        d.text(16 + d.fonts.width(title, 16, 'Bold') + 8, y + 3, sub, size=12, color=SUB, lh=17)
    if more:
        tw = d.fonts.width(more, 13)
        d.text(W - 16 - tw, y + 2, more, size=13, color=SUB, lh=18)
        if more_to:
            d.hs(W - 28 - tw, y - 6, tw + 24, 32, more_to)
    return y + 30


def search_box(d, y, placeholder, to=None, camera_to=None, value=None, x=16, w=358):
    d.rect(x, y, w, 44, fill=BG, r=22)
    if value:
        d.text(x + 18, y + 12, value, size=15, weight='Medium', lh=20)
    else:
        d.text(x + 18, y + 12, placeholder, size=14, color=SUB, lh=20)
    if camera_to:
        d.emoji('camera', x + w - 40, y + 10, 24)
        d.hs(x + w - 50, y, 50, 44, camera_to)
        if to:
            d.hs(x, y, w - 50, 44, to)
    elif to:
        d.hs(x, y, w, 44, to)
    return y + 44


def channel_filter(d, y, sel='all', links=None):
    d.rect(16, y, 358, 38, fill=BG, r=19)
    segs = [('all', '전체', None), ('online', '온라인', 'globe'), ('offline', '오프라인', 'pin')]
    sw_ = (358 - 8) / 3
    for i, (k, label, ic) in enumerate(segs):
        sx = 20 + i * sw_
        on = k == sel
        if on:
            d.rect(sx, y + 4, sw_, 30, fill=WHITE, r=15, stroke=LINE)
        weight = 'SemiBold' if on else 'Medium'
        tw = d.fonts.width(label, 13, weight)
        cw = tw + (18 if ic else 0)
        cx = sx + (sw_ - cw) / 2
        if ic:
            d.emoji(ic, cx, y + 12, 14)
            cx += 18
        d.text(cx, y + 10, label, size=13, weight=weight, color=INK if on else SUB, lh=18)
        if links and links.get(k):
            d.hs(sx, y, sw_, 38, links[k])
    return y + 38


def chips(d, y, labels, sel=0, x=16, dark=True, links=None, size=13, h=32, gap=8):
    cx = x
    for i, label in enumerate(labels):
        on = i == sel
        tw = d.fonts.width(label, size, 'SemiBold' if on else 'Medium')
        cw = tw + 28
        if on and dark:
            d.rect(cx, y, cw, h, fill=INK, r=h / 2)
            color = WHITE
        elif on:
            d.rect(cx, y, cw, h, fill=ORANGE_BG, r=h / 2, stroke=ORANGE)
            color = ORANGE
        else:
            d.rect(cx, y, cw, h, fill=WHITE, r=h / 2, stroke=LINE)
            color = INK
        lh = round(size * 1.4)
        d.text(cx + 14, y + (h - lh) / 2, label, size=size, weight='SemiBold' if on else 'Medium', color=color)
        if links and links.get(i):
            d.hs(cx, y, cw, h, links[i])
        cx += cw + gap
    return y + h


def ip_tile_small(d, x, y, key, to=None):
    name, ic, bg, _ = IPS[key]
    label = '건담' if key == 'gundam' else name
    d.rect(x, y, 58, 58, fill=bg, r=16)
    d.emoji(ic, x + 12, y + 12, 34)
    d.text(x - 8, y + 64, label, size=12, weight='Medium', w=74, align='center', lh=16)
    if to:
        d.hs(x - 6, y - 4, 70, 86, to)


def ip_tile_grid(d, x, y, key, w=110, selected=None, sub=None, to=None):
    name, ic, bg, stat = IPS[key]
    h = 108 if not sub else 124
    if selected:
        d.rect(x, y, w, h, fill=WHITE, r=14, stroke=ORANGE, sw=2)
    else:
        d.rect(x, y, w, h, fill=WHITE, r=14, stroke=LINE)
    d.rect(x + 6, y + 6, w - 12, 66, fill=bg, r=10)
    d.emoji(ic, x + w / 2 - 20, y + 19, 40)
    d.text(x, y + 78, name, size=12, weight='SemiBold', w=w, align='center', lh=17)
    if sub:
        d.text(x, y + 97, sub, size=10, color=SUB, w=w, align='center', lh=14)
    if selected:
        d.ellipse(x + w - 26, y + 9, 18, 18, ORANGE)
        d.text(x + w - 26, y + 9, '✓', size=11, weight='Bold', color=WHITE, w=18, align='center', lh=18)
    if to:
        d.hs(x, y, w, h, to)
    return h


def product_card(d, x, y, key, w=173, show_on=True, show_off=True, to=None):
    meta, name, ic, bg, on, off = P[key]
    ih = 112
    d.rect(x, y, w, ih, fill=bg, r=14)
    d.emoji(ic, x + w / 2 - 30, y + ih / 2 - 30, 60)
    d.text(x + w - 28, y + 6, '♡', size=19, color=SUB, lh=26)
    yy = y + ih + 8
    d.text(x, yy, meta, size=11, color=SUB, lh=15)
    yy += 17
    _, th = d.text(x, yy, name, size=14, weight='SemiBold', lh=19, wrap=w)
    yy += th + 6
    if on and show_on:
        online_badge(d, x, yy, on)
        yy += 26
    if off and show_off:
        offline_badge(d, x, yy, off)
        yy += 26
    if to:
        d.hs(x, y, w, yy - y, to)
    return yy - y


def result_row(d, y, ic, bg, meta, name, on=None, off=None, extra=None, to=None, dim=False, img=76):
    d.rect(16, y, img, img, fill=bg, r=12)
    d.emoji(ic, 16 + img / 2 - 22, y + img / 2 - 22, 44)
    x = 16 + img + 12
    yy = y + 2
    d.text(x, yy, meta, size=11, color=SUB, lh=15)
    yy += 17
    _, th = d.text(x, yy, name, size=14, weight='SemiBold', color=SUB if dim else INK, lh=19, wrap=W - 16 - x)
    yy += th + 6
    bx = x
    if extra:
        bx += pill(d, bx, yy, extra[0], extra[1], extra[2]) + 6
    if on:
        bx += online_badge(d, bx, yy, on) + 6
    if off:
        offline_badge(d, bx, yy, off)
    h = max(img, yy + 22 - y)
    if to:
        d.hs(16, y, W - 32, h, to)
    return h


def store_card_small(d, x, y, key, w=173, to=None):
    name, kind, dist, stock, _ = STORES[key]
    d.rect(x, y, w, 100, fill=WHITE, r=14, stroke=LINE)
    d.emoji('pin', x + 12, y + 14, 16)
    d.text(x + 31, y + 12, name, size=14, weight='SemiBold', lh=20)
    d.text(x + 12, y + 38, dist.split(' · ')[0] + ' · 영업 중', size=11, color=SUB, lh=15)
    fg, bg = (GREEN, GREEN_BG) if stock[0] == 'green' else (SUB, BG)
    pill(d, x + 12, y + 64, stock[1], fg, bg, size=11, h=22)
    if to:
        d.hs(x, y, w, 100, to)


def tabbar(d, active):
    y = H - 66
    d.rect(0, y, W, 66, fill=WHITE)
    d.rect(0, y, W, 1, fill=LINE)
    tabs = [('house', '홈', 'home'), ('teddy', '굿즈 탐색', 'explore'), ('pin', '매장 찾기', 'stores-list'), ('smile', '마이', 'my')]
    tw = W / 4
    for i, (ic, label, to) in enumerate(tabs):
        on = active == to
        d.emoji(ic, i * tw + tw / 2 - 13, y + 9, 26)
        d.text(i * tw, y + 39, label, size=11, weight='SemiBold' if on else 'Medium', color=ORANGE if on else SUB,
               w=tw, align='center', lh=15)
        d.hs(i * tw, y, tw, 66, to)


def steps(d, y, active):
    for i, label in enumerate(['1. 계정 정보', '2. IP 선택']):
        x = 16 + i * 183
        d.rect(x, y, 175, 4, fill=ORANGE if i + 1 == active else LINE, r=2)
        d.text(x, y + 10, label, size=12, weight='SemiBold' if i + 1 == active else 'Medium',
               color=ORANGE if i + 1 == active else SUB, lh=16)
    return y + 32


def dim_and_sheet(d, base_fn, sheet_h):
    """밑 화면을 그리고 어둡게 덮은 뒤 아래에서 올라온 창(바텀 시트) 자리를 만든다."""
    d.quiet = True
    base_fn(d, overlay=True)
    d.quiet = False
    d.rect(0, 0, W, H, fill='#000000', opacity=0.42, name='dim')
    d.hs(0, 0, W, H - sheet_h, 'back')
    top = H - sheet_h
    d.rect(0, top, W, sheet_h + 24, fill=WHITE, r=22)
    d.rect(W / 2 - 20, top + 10, 40, 4, fill=LINE, r=2)
    return top + 28


def checkline(d, x, y, label, on=True, bold=False, size=14):
    d.ellipse(x, y + 1, 20, 20, ORANGE if on else WHITE, stroke=None if on else LINE)
    d.text(x, y + 1, '✓', size=12, weight='Bold', color=WHITE if on else '#C8CCD2', w=20, align='center', lh=20)
    d.text(x + 30, y, label, size=size, weight='SemiBold' if bold else 'Regular', lh=22)


# ---------------------------------------------------------------- 화면
def s_login(d):
    d.screen('login', '로그인', 4, '앱을 처음 열거나 로그아웃 상태일 때', 0, 0)
    d.emoji('sunrise', W / 2 - 40, 92, 80)
    d.text(0, 184, '굿모닝', size=34, weight='Bold', color=ORANGE, w=W, align='center', lh=44)
    d.text(0, 230, '굿즈 모으는 닝겐', size=14, color=SUB, w=W, align='center', lh=20)
    for i, (label, val) in enumerate([('이메일', 'goods@example.com'), ('비밀번호', '••••••••')]):
        y = 286 + i * 60
        d.rect(24, y, 342, 50, fill=BG, r=12)
        d.text(42, y + 15, val, size=15, color=INK if i == 0 else SUB, lh=20)
    button(d, 24, 414, 342, 52, '로그인', to='home')
    t = '비밀번호 찾기   ·   회원가입'
    tw = d.fonts.width(t, 13)
    d.text((W - tw) / 2, 482, t, size=13, color=SUB, lh=18)
    sw_ = d.fonts.width('회원가입', 13)
    d.hs((W + tw) / 2 - sw_ - 8, 472, sw_ + 16, 38, 'signup')
    d.rect(24, 540, 110, 1, fill=LINE)
    d.rect(256, 540, 110, 1, fill=LINE)
    d.text(0, 531, 'SNS로 시작하기', size=12, color=SUB, w=W, align='center', lh=17)
    button(d, 24, 566, 342, 48, '카카오로 시작하기', kind='kakao', size=15, to='signup-ip', r=12)
    button(d, 24, 622, 342, 48, '네이버로 시작하기', kind='naver', size=15, to='signup-ip', r=12)
    button(d, 24, 678, 342, 48, 'Apple로 시작하기', kind='apple', size=15, to='signup-ip', r=12)
    t = '로그인 없이 둘러보기 ›'
    tw = d.fonts.width(t, 14, 'Medium')
    d.text((W - tw) / 2, 760, t, size=14, weight='Medium', color=SUB, lh=20)
    d.hs((W - tw) / 2 - 12, 750, tw + 24, 40, 'home')


def s_signup(d):
    d.screen('signup', '회원가입 · 계정 정보', 5, '회원가입 1단계', 1, 0)
    app_bar(d, '회원가입')
    y = steps(d, 62, 1) + 8
    fields = [('이메일', 'goods@example.com', '중복 확인', None), ('비밀번호', '••••••••', None, '✓ 영문 · 숫자 포함 8자 이상'),
              ('비밀번호 확인', '••••••••', None, None), ('닉네임', '굿즈러버', None, None)]
    for label, val, btn, help_ in fields:
        d.text(16, y, label, size=13, weight='SemiBold', lh=18)
        y += 24
        d.rect(16, y, 358, 46, fill=BG, r=12)
        d.text(32, y + 13, val, size=15, color=INK, lh=20)
        if btn:
            tw = d.fonts.width(btn, 12, 'SemiBold')
            d.rect(374 - tw - 30, y + 9, tw + 20, 28, fill=WHITE, r=14, stroke=LINE)
            d.text(374 - tw - 20, y + 14, btn, size=12, weight='SemiBold', lh=17)
        y += 46
        if help_:
            d.text(18, y + 5, help_, size=12, weight='Medium', color=GREEN, lh=16)
            y += 22
        y += 12
    d.text(16, y, '동네 (선택)', size=13, weight='SemiBold', lh=18)
    y += 24
    d.rect(16, y, 358, 46, fill=WHITE, r=12, stroke=LINE)
    d.emoji('pin', 30, y + 14, 18)
    d.text(54, y + 13, '현재 위치로 설정 · 용산구', size=14, weight='Medium', lh=20)
    y += 62
    d.rect(16, y - 8, 358, 1, fill=LINE)
    checkline(d, 16, y + 6, '전체 동의', bold=True, size=15)
    y += 40
    for label in ['이용약관 (필수)', '개인정보 처리방침 (필수)', '위치 정보 이용 (선택) · 내 주변 재고', '알림 받기 (선택) · 가격 하락 · 재입고']:
        checkline(d, 26, y, label, size=13)
        y += 30
    button(d, 16, 770, 358, 52, '다음 · IP 고르기', to='signup-ip')


def s_signup_ip(d):
    d.screen('signup-ip', '회원가입 · IP 고르기', 6, '회원가입 2단계 · 고른 IP만 홈과 굿즈 탐색에 보인다', 2, 0)
    app_bar(d, '회원가입')
    y = steps(d, 62, 2) + 6
    d.text(16, y, '좋아하는 IP를 골라 주세요', size=20, weight='Bold', lh=28)
    d.text(16, y + 32, '고른 IP의 굿즈만 보여요 · 나중에 바꿀 수 있어요', size=12, color=SUB, lh=17)
    y = search_box(d, y + 60, 'IP · 캐릭터 이름 검색 (먼작귀도 돼요)') + 12
    y = chips(d, y, ['전체', '캐릭터', '애니', '게임', '프라모델'], sel=0) + 14
    keys = MY_IPS + OTHER_IPS
    for i, k in enumerate(keys):
        col, row = i % 3, i // 3
        ip_tile_grid(d, 16 + col * 124, y + row * 118, k, selected=k in MY_IPS)
    y += 3 * 118 + 4
    d.rect(16, y, 358, 40, fill=WHITE, r=12, stroke='#B0B5BD', dashes=[5, 4])
    d.text(0, y + 11, '찾는 IP가 없어요? 추가 요청 +', size=13, color=SUB, w=W, align='center', lh=18)
    button(d, 16, 774, 358, 52, '6개 선택 · 굿모닝 시작하기', to='home')


def home_body(d, sel='all', overlay=False):
    d.text(16, 14, '굿모닝', size=24, weight='Bold', color=ORANGE, lh=32)
    d.emoji('bell', W - 46, 14, 28)
    d.ellipse(W - 24, 14, 8, 8, ORANGE)
    d.hs(W - 56, 4, 52, 48, 'notifications')
    search_box(d, 58, '굿즈 이름, 캐릭터 검색', to='search', camera_to='photo-pick')
    channel_filter(d, 114, sel, links={'all': 'home', 'offline': 'home-offline', 'online': 'home-online'})
    order = ['ip', 'stores', 'new'] if sel != 'offline' else ['stores', 'ip', 'new']
    y = 166
    for part in order:
        if part == 'ip':
            y = section(d, y, '내 IP', more='전체 ›', more_to='explore')
            for i, k in enumerate(['sanrio', 'chiikawa', 'pokemon', 'gundam']):
                ip_tile_small(d, 22 + i * 74, y, k, to='ip-sanrio' if k == 'sanrio' else None)
            x = 22 + 4 * 74
            d.rect(x, y, 58, 58, fill=WHITE, r=16, stroke='#B0B5BD', dashes=[5, 4])
            d.text(x, y + 14, '+', size=24, color=SUB, w=58, align='center', lh=30)
            d.text(x - 8, y + 64, '추가', size=12, color=SUB, w=74, align='center', lh=16)
            d.hs(x - 6, y - 4, 70, 86, 'ip-manage')
            y += 98
        elif part == 'stores':
            y = section(d, y, '내 주변 재고', more='지도 ›', more_to='stores-map')
            store_card_small(d, 16, y, 'yongsan', to='store-detail')
            store_card_small(d, 201, y, 'hongdae')
            y += 116
        else:
            y = section(d, y, '내 IP 신상품', more='더보기 ›', more_to='ip-sanrio')
            for i, k in enumerate(['kuromi', 'chiikawa']):
                product_card(d, 16 + i * 185, y, k, show_on=sel != 'offline', show_off=sel != 'online',
                             to='product-online' if k == 'kuromi' else None)
            y += 240
    tabbar(d, 'home')


def s_home(d):
    d.screen('home', '홈', 7, '앱을 열면 처음 보이는 화면', 0, 1)
    home_body(d)


def s_home_online(d):
    d.screen('home-online', '홈 · 온라인 필터', 7, '판매 경로 필터 [온라인]: 목록이 온라인 판매 기준으로 바뀜', 1, 1)
    home_body(d, 'online')


def s_home_offline(d):
    d.screen('home-offline', '홈 · 오프라인 필터', 7, '판매 경로 필터 [오프라인]: 내 주변 재고가 맨 위로', 2, 1)
    home_body(d, 'offline')


def s_photo_pick(d):
    d.screen('photo-pick', '사진 검색 · 사진 고르기', 11, '홈의 📷: 사진을 찍거나 최근 사진에서 고르기', 3, 1)
    y = dim_and_sheet(d, lambda dd, overlay: home_body(dd), 360)
    d.text(20, y, '사진으로 찾기', size=18, weight='Bold', lh=24)
    d.text(W - 40, y - 2, '×', size=24, color=SUB, lh=28)
    d.hs(W - 52, y - 10, 48, 44, 'back')
    d.text(20, y + 30, '같은 굿즈와 다른 버전까지 함께 찾아 드려요', size=13, color=SUB, lh=18)
    y += 64
    button(d, 20, y, 169, 48, '사진 찍기', kind='secondary', icon='camera', size=14, r=12)
    button(d, 201, y, 169, 48, '앨범에서 고르기', kind='secondary', icon='picture', size=14, r=12)
    y += 64
    d.text(20, y, '최근 사진', size=14, weight='SemiBold', lh=20)
    y += 28
    for i, (ic, bg) in enumerate([('package', '#F0E4D7'), ('horns', '#ECE0F5'), ('robot', '#E3ECFA')]):
        x = 20 + i * 120
        d.rect(x, y, 110, 110, fill=bg, r=12)
        d.emoji(ic, x + 25, y + 25, 60)
        if i == 0:
            d.rect(x, y, 110, 110, fill=None, r=12, stroke=ORANGE, sw=2)
            d.hs(x, y, 110, 110, 'photo-search')


def s_photo_search(d):
    d.screen('photo-search', '사진 검색 결과', 11, '홈의 📷 으로 사진을 올린 뒤 보이는 화면', 4, 1)
    app_bar(d, '사진 검색')
    d.rect(16, 62, 358, 128, fill='#F0E4D7', r=14)
    d.emoji('package', W / 2 - 36, 88, 72)
    pill(d, 26, 72, '올린 사진', WHITE, INK, size=11, h=24)
    tw = d.fonts.width('다시 찍기', 12, 'SemiBold') + 20
    pill(d, 364 - tw, 154, '다시 찍기', INK, WHITE, size=12, h=26)
    d.hs(364 - tw, 150, tw, 34, 'photo-pick')
    y = 204
    d.rect(16, y, 358, 64, fill=AMBER_BG, r=12, stroke='#F2D58A')
    d.emoji('warning', 30, y + 12, 18)
    d.text(54, y + 11, '비슷한 버전이 있어요', size=14, weight='Bold', color=AMBER, lh=20)
    d.text(30, y + 37, '일반 13cm와 미니 8cm가 거의 같게 보여요. 크기를 확인하세요.', size=12, color=AMBER, lh=17)
    y += 78
    search_box(d, y, '+ 조건 추가 (예: 미니, 박스 ver.)')
    y += 60
    d.text(16, y, '비슷한 굿즈', size=15, weight='Bold', lh=21)
    y += 30
    d.rect(10, y - 6, 370, 196, fill=None, r=14, stroke=ORANGE, sw=1.5, dashes=[6, 4])
    rows = [('일반 13cm', '73%', '3곳 · 25,000원~'), ('미니 8cm', '72%', '4곳 · 12,000원~')]
    for ver, sim, on in rows:
        h = result_row(d, y + 4, 'package', '#F0E4D7', '단보 · 단보', '리볼텍 단보 피규어', on=on,
                       extra=(ver, ORANGE, ORANGE_BG), to='product-online')
        d.text(W - 16 - d.fonts.width(f'유사도 {sim}', 12), y + 6, f'유사도 {sim}', size=12, color=SUB, lh=17)
        y += 94
    y += 16
    result_row(d, y, 'swords', '#E8EAF2', 'Fate · 세이버', '세이버 피규어', on='2곳 · 36,000원~',
               extra=('갑옷 ver.', ORANGE, ORANGE_BG), dim=True, to='product-online')
    d.text(W - 16 - d.fonts.width('유사도 40%', 12), y + 2, '유사도 40%', size=12, color=SUB, lh=17)
    y += 96
    d.text(0, y, '점선 안 = 같은 굿즈의 다른 버전', size=12, weight='Medium', color=ORANGE, w=W, align='center', lh=17)


def s_notifications(d):
    d.screen('notifications', '알림 목록', 9, '홈의 🔔 에서 들어오는 화면', 5, 1)
    app_bar(d, '알림', right='모두 읽음')
    y = chips(d, 64, ['전체', '가격', '재입고', '입고', '제보 · 문의'], sel=0) + 18
    groups = [('오늘', [
        ('chart_down', '쿠로미 마스코트 인형 가격 하락', '오픈마켓 A 15,900원 → 12,900원', '10분 전', True, 'horns', '#ECE0F5', 'product-online'),
        ('package', '치이카와 마스코트 인형 재입고', '공식 온라인몰에 다시 들어왔어요', '1시간 전', True, 'hamster', '#FDEBD9', None),
        ('pin', '피규어샵 용산점에 건담 입고', '저장한 매장 · 내 IP 굿즈', '3시간 전', False, 'robot', '#E3ECFA', 'store-detail'),
    ]), ('이번 주', [
        ('check', '재고 제보가 반영됐어요', '캐릭터스토어 강남점 · 재고 적음', '어제', False, None, None, None),
        ('speech', '문의에 답변이 왔어요', '10/27 오픈마켓 A 가격 문의', '2일 전', False, None, None, 'history'),
        ('star', '내 IP 새 굿즈', '산리오 신상품 4개가 등록됐어요', '3일 전', False, None, None, 'ip-sanrio'),
    ])]
    for gname, items in groups:
        d.text(16, y, gname, size=13, weight='SemiBold', color=SUB, lh=18)
        y += 28
        for ic, title, sub, t, unread, thumb, tbg, to in items:
            if unread:
                d.rect(0, y - 8, W, 76, fill='#FFF8F3')
                d.ellipse(6, y + 16, 6, 6, ORANGE)
            d.rect(16, y, 44, 44, fill=BG, r=12)
            d.emoji(ic, 26, y + 10, 24)
            maxw = W - 16 - 72 - (64 if thumb else 0) - 8
            d.text(72, y, title, size=14, weight='SemiBold' if unread else 'Medium', lh=20, wrap=maxw)
            d.text(72, y + 22, sub, size=12, color=SUB, lh=17)
            d.text(72, y + 41, t, size=11, color=SUB, lh=15)
            if thumb:
                d.rect(W - 16 - 52, y, 52, 52, fill=tbg, r=10)
                d.emoji(thumb, W - 16 - 52 + 10, y + 10, 32)
            if to:
                d.hs(0, y - 8, W, 76, to)
            y += 76
        y += 6
    tw = d.fonts.width('알림 설정 ›', 13)
    d.text((W - tw) / 2, y + 6, '알림 설정 ›', size=13, color=SUB, lh=18)


def s_search(d):
    d.screen('search', '검색 결과', 10, '검색창에 입력한 뒤 보이는 화면', 6, 1)
    d.text(14, 18, '‹', size=26, weight='Medium', lh=30)
    d.hs(0, 4, 44, 52, 'back')
    d.rect(44, 10, 330, 44, fill=BG, r=22)
    d.text(62, 22, '먼작귀 키링', size=15, weight='Medium', lh=20)
    d.text(344, 18, '×', size=20, color=SUB, lh=26)
    y = 66
    d.rect(16, y, 358, 36, fill=ORANGE_BG, r=10)
    d.text(30, y + 9, '‘먼작귀’를 ‘치이카와’로 함께 찾았어요', size=13, weight='Medium', color=ORANGE, lh=18)
    y = channel_filter(d, y + 48) + 12
    y = chips(d, y, ['품목 ▼', '가격 ▼', '최저가순 ▼'], sel=-1, size=12, h=30) + 14
    d.text(16, y, '검색 결과 12개', size=13, weight='SemiBold', color=SUB, lh=18)
    y += 28
    rows = [('hamster', '#FDEBD9', '치이카와 · 치이카와', '치이카와 마스코트 키링', '4곳 · 9,900원~', '근처 3곳'),
            ('cat', '#EEF1F5', '치이카와 · 하치와레', '하치와레 랜덤 키링 (블라인드)', '3곳 · 9,000원~', '근처 2곳'),
            ('sparkles', '#FFF6CC', '치이카와 · 3명', '치이카와 · 하치와레 · 우사기 아크릴 키링 세트', '2곳 · 14,500원~', None),
            ('rabbit', '#FBE3EF', '치이카와 · 우사기', '우사기 쿠지 B상 키링', None, '근처 1곳')]
    for ic, bg, meta, name, on, off in rows:
        h = result_row(d, y, ic, bg, meta, name, on=on, off=off, to='product-online')
        y += h + 16
        d.rect(16, y - 8, 358, 1, fill=LINE)
    tabbar(d, 'explore')


def s_explore(d):
    d.screen('explore', '굿즈 탐색', 8, '품목이나 IP로 굿즈를 찾아 들어가는 화면', 0, 2)
    d.text(16, 16, '굿즈 탐색', size=22, weight='Bold', lh=30)
    search_box(d, 58, '캐릭터 · IP 이름 검색 (예: 먼작귀)', to='search')
    channel_filter(d, 114)
    y = section(d, 168, '품목으로 보기')
    cats = [('moai', '피규어'), ('teddy', '인형'), ('key', '키링'), ('placard', '아크릴'), ('robot', '프라모델'), ('die', '랜덤')]
    for i, (ic, label) in enumerate(cats):
        x = 16 + i * 60
        d.rect(x, y, 52, 52, fill=BG, r=14)
        d.emoji(ic, x + 10, y + 10, 32)
        d.text(x - 4, y + 58, label, size=12, weight='Medium', w=60, align='center', lh=16)
        d.hs(x - 4, y, 60, 76, 'search')
    y += 92
    y = section(d, y, '내 IP', sub='회원가입 때 고른 IP')
    for i, k in enumerate(MY_IPS):
        col, row = i % 3, i // 3
        ip_tile_grid(d, 16 + col * 124, y + row * 134, k, sub=IPS[k][3], to='ip-sanrio' if k == 'sanrio' else None)
    y += 2 * 134 + 2
    d.rect(16, y, 358, 44, fill=WHITE, r=12, stroke=LINE)
    tw = d.fonts.width('IP 목록 조정', 14, 'SemiBold')
    d.emoji('gear', (W - tw - 24) / 2, y + 12, 20)
    d.text((W - tw - 24) / 2 + 24, y + 12, 'IP 목록 조정', size=14, weight='SemiBold', lh=20)
    d.hs(16, y, 358, 44, 'ip-manage')
    tabbar(d, 'explore')


def s_ip_manage(d):
    d.screen('ip-manage', 'IP 목록 조정', 12, '홈의 [+ 추가], 굿즈 탐색의 [IP 목록 조정] 에서 들어오는 화면', 1, 2)
    app_bar(d, 'IP 목록 조정')
    d.text(16, 62, '홈과 굿즈 탐색에 보일 IP를 고르세요', size=14, color=SUB, lh=20)
    y = search_box(d, 92, 'IP · 캐릭터 이름 검색') + 18
    d.text(16, y, '내 IP 6', size=15, weight='Bold', lh=21)
    t = '꾹 눌러 순서 바꾸기'
    d.text(W - 16 - d.fonts.width(t, 12), y + 3, t, size=12, color=SUB, lh=17)
    y += 30
    for i, k in enumerate(MY_IPS):
        ip_tile_grid(d, 16 + (i % 3) * 124, y + (i // 3) * 118, k, selected=True)
    y += 2 * 118 + 10
    d.text(16, y, '다른 IP', size=15, weight='Bold', lh=21)
    y += 30
    for i, k in enumerate(OTHER_IPS):
        ip_tile_grid(d, 16 + i * 124, y, k)
    y += 124
    d.rect(16, y, 358, 76, fill=WHITE, r=12, stroke='#B0B5BD', dashes=[5, 4])
    d.text(30, y + 14, '찾는 IP가 없나요?', size=14, weight='SemiBold', lh=20)
    d.text(30, y + 38, 'IP 이름을 보내 주시면 확인 후 추가해요', size=12, color=SUB, lh=17)
    pill(d, 286, y + 24, '추가 요청', ORANGE, ORANGE_BG, size=12, h=28)
    button(d, 16, 774, 358, 52, '저장', to='back')


def s_ip_sanrio(d):
    d.screen('ip-sanrio', 'IP 화면 · 산리오', 13, '굿즈 탐색에서 IP를 고르면 보이는 화면 (예: 산리오)', 2, 2)
    app_bar(d, '산리오')
    channel_filter(d, 60)
    y = 112
    chars = [('전체', 'ribbon', '#FCE4EC'), ('헬로키티', 'ribbon', '#FCE4EC'), ('쿠로미', 'horns', '#ECE0F5'),
             ('마이멜로디', 'rabbit', '#FBE3EF'), ('시나모롤', 'cloud', '#E3F0FB')]
    for i, (name, ic, bg) in enumerate(chars):
        x = 16 + i * 72
        d.ellipse(x + 4, y, 56, 56, bg, stroke=ORANGE if i == 0 else None, sw=2)
        d.emoji(ic, x + 16, y + 12, 32)
        d.text(x - 6, y + 62, name, size=12, weight='SemiBold' if i == 0 else 'Medium', color=ORANGE if i == 0 else INK,
               w=76, align='center', lh=16)
        if name == '쿠로미':
            d.hs(x - 4, y - 4, 72, 88, 'character-kuromi')
    y += 94
    y = chips(d, y, ['전체', '피규어', '인형', '키링', '아크릴'], sel=0, size=12, h=30) + 14
    d.text(16, y, '굿즈 128개', size=13, weight='SemiBold', color=SUB, lh=18)
    t = '인기순 ▼'
    d.text(W - 16 - d.fonts.width(t, 13, 'Medium'), y, t, size=13, weight='Medium', lh=18)
    y += 28
    for i, k in enumerate(['kuromi', 'kitty']):
        product_card(d, 16 + i * 185, y, k, to='product-online' if k == 'kuromi' else None)
    y += 248
    for i, k in enumerate(['mymelo', 'cinna']):
        product_card(d, 16 + i * 185, y, k)
    tabbar(d, 'explore')


def s_character(d):
    d.screen('character-kuromi', '캐릭터 화면 · 쿠로미', 14, 'IP 화면에서 캐릭터를 고르면 보이는 화면 (예: 쿠로미)', 3, 2)
    app_bar(d, '쿠로미')
    d.ellipse(16, 62, 64, 64, '#ECE0F5')
    d.emoji('horns', 28, 74, 40)
    d.text(92, 66, '쿠로미', size=20, weight='Bold', lh=28)
    d.text(92 + d.fonts.width('쿠로미', 20, 'Bold') + 8, 72, '산리오', size=13, color=BLUE, lh=18)
    d.hs(88, 66, 160, 30, 'ip-sanrio')
    d.text(92, 98, '굿즈 24개 · 온라인 18 · 근처 매장 6', size=13, color=SUB, lh=18)
    channel_filter(d, 142)
    y = 196
    groups = [('키링 6', [('마스코트 인형 키링', ('on', '12,900원~')), ('방울 키링', ('off', '근처 2곳')), ('얼굴 키링', ('on', '8,900원~'))], 'black_heart'),
              ('인형 5', [('쿠션 인형 M', ('on', '21,000원~')), ('쿠션 인형 L', ('off', '근처 1곳')), ('미니 인형', ('on', '9,900원~'))], 'horns'),
              ('아크릴 4', [('아크릴 스탠드', ('on', '15,000원~')), ('아크릴 키링', ('off', '근처 2곳')), ('포토 카드', ('on', '4,500원~'))], 'horns')]
    for title, items, ic in groups:
        y = section(d, y, title, more='전체 ›')
        for i, (name, (kind, val)) in enumerate(items):
            x = 16 + i * 122
            d.rect(x, y, 112, 84, fill='#ECE0F5', r=12)
            d.emoji(ic if i != 1 else 'horns', x + 34, y + 20, 44)
            d.text(x, y + 90, name, size=12, weight='SemiBold', lh=17, wrap=112)
            if kind == 'on':
                online_badge(d, x, y + 112, val, size=10)
            else:
                offline_badge(d, x, y + 112, val, size=10)
            d.hs(x, y, 112, 136, 'product-online')
        y += 148
    tabbar(d, 'explore')


def product_header(d, tab):
    d.text(14, 13, '‹', size=26, weight='Medium', lh=30)
    d.hs(0, 0, 52, 56, 'back')
    d.text(W - 70, 18, '공유', size=14, weight='Medium', color=INK, lh=20)
    d.text(W - 34, 14, '♡', size=21, color=INK, lh=28)
    d.rect(16, 56, 358, 132, fill='#ECE0F5', r=16)
    d.emoji('horns', W / 2 - 42, 80, 84)
    d.text(16, 198, '산리오 › 쿠로미', size=12, weight='Medium', color=BLUE, lh=17)
    d.hs(10, 192, 120, 28, 'character-kuromi')
    d.text(16, 218, '쿠로미 마스코트 인형', size=19, weight='Bold', lh=26)
    y = 254
    d.text(16, y + 6, '버전', size=12, color=SUB, lh=17)
    chips(d, y, ['일반 10cm', '빅 20cm'], sel=0, x=56, size=12, h=30)
    y += 44
    d.rect(16, y, 173, 62, fill=BLUE_BG, r=12)
    d.emoji('globe', 28, y + 11, 14)
    d.text(46, y + 9, '온라인 4곳', size=12, weight='Medium', color=BLUE, lh=17)
    d.text(28, y + 30, '최저 12,900원', size=16, weight='Bold', color=BLUE, lh=22)
    d.rect(201, y, 173, 62, fill=GREEN_BG, r=12)
    d.emoji('pin', 213, y + 11, 14)
    d.text(231, y + 9, '오프라인', size=12, weight='Medium', color=GREEN, lh=17)
    d.text(213, y + 30, '근처 2곳 재고', size=16, weight='Bold', color=GREEN, lh=22)
    d.hs(16, y, 173, 62, 'product-online')
    d.hs(201, y, 173, 62, 'product-offline')
    y += 76
    tabs = [('online', '온라인 가격', 'product-online'), ('offline', '오프라인 매장', 'product-offline'), ('similar', '비슷한 굿즈', 'product-similar')]
    tw_ = 358 / 3
    for i, (k, label, to) in enumerate(tabs):
        on = k == tab
        d.text(16 + i * tw_, y, label, size=14, weight='Bold' if on else 'Medium', color=INK if on else SUB, w=tw_, align='center', lh=20)
        if on:
            d.rect(16 + i * tw_ + 18, y + 28, tw_ - 36, 3, fill=ORANGE, r=1.5)
        d.hs(16 + i * tw_, y - 8, tw_, 40, to)
    d.rect(16, y + 31, 358, 1, fill=LINE)
    return y + 44


def product_bottom(d, main_label, main_to):
    y = H - 76
    d.rect(0, y, W, 76, fill=WHITE)
    d.rect(0, y, W, 1, fill=LINE)
    d.ellipse(16, y + 14, 48, 48, WHITE, stroke=LINE)
    d.text(16, y + 25, '♡', size=21, color=INK, w=48, align='center', lh=26)
    button(d, 72, y + 14, 104, 48, '알림 받기', kind='secondary', icon='bell', size=13)
    button(d, 184, y + 14, 190, 48, main_label, size=15, to=main_to)


def s_product_online(d):
    d.screen('product-online', '상품 상세 · 온라인 가격', 15, '어느 화면에서든 상품을 누르면 들어오는 화면 (예: 쿠로미 마스코트 인형)', 0, 3)
    y = product_header(d, 'online')
    malls = [('오픈마켓 A', '12,900원 · 무료배송 · API · 20분 전', '12,900원', True, False),
             ('오픈마켓 B', '11,900원 + 배송 3,000원 · API · 1시간 전', '14,900원', False, False),
             ('공식 온라인몰', '15,000원 · 무료배송 · 수집 · 3시간 전', '15,000원', False, False),
             ('굿즈 전문몰 C', '수집 · 어제', '—', False, True)]
    for name, sub, price, best, soldout in malls:
        c = SUB if soldout else INK
        d.text(16, y, name, size=14, weight='SemiBold', color=c, lh=20)
        d.text(16, y + 22, sub, size=11, color=SUB, lh=15)
        pw = d.fonts.width(price, 14, 'Bold')
        d.text(268 - pw, y, price, size=14, weight='Bold', color=c, lh=20)
        if best:
            pill(d, 268 - 38, y + 22, '최저', ORANGE, ORANGE_BG, size=10, h=18)
        if soldout:
            button(d, 280, y + 2, 94, 32, '품절', kind='disabled', size=12)
        else:
            button(d, 280, y + 2, 94, 32, '구매하러 가기', size=12, to='external-mall')
        y += 50
        d.rect(16, y, 358, 1, fill=LINE)
        y += 12
    d.text(0, y + 4, '배송비 포함 총액 순 · 가격은 몰에서 바뀔 수 있어요', size=11, color=SUB, w=W, align='center', lh=15)
    product_bottom(d, '최저가로 구매하러 가기', 'external-mall')


def s_product_offline(d):
    d.screen('product-offline', '상품 상세 · 오프라인 매장', 16, '상품 상세에서 [오프라인 매장] 탭을 누른 화면', 1, 3)
    y = product_header(d, 'offline')
    chips(d, y, ['가까운 순 ▼', '✓ 재고 있는 곳만'], sel=1, dark=False, size=12, h=30)
    t = '지도 ›'
    d.text(W - 16 - d.fonts.width(t, 13, 'Medium'), y + 6, t, size=13, weight='Medium', color=BLUE, lh=18)
    d.hs(W - 70, y - 4, 60, 38, 'stores-map')
    y += 44
    rows = [('굿즈샵 홍대점', '4.1km · 영업 중 · 21:00까지', 'many', '사장님 확인 · 2시간 전'),
            ('키덜트샵 건대점', '5.6km · 영업 중 · 21:00까지', 'few', '제보 · 어제'),
            ('캐릭터스토어 강남점', '6.3km · 영업 중 · 22:00까지', 'check', '수집 · 3일 전')]
    for name, sub, st, src in rows:
        dim = st == 'check'
        d.text(16, y, name, size=14, weight='SemiBold', color=SUB if dim else INK, lh=20)
        d.text(16, y + 22, sub, size=11, color=SUB, lh=15)
        stock_badge(d, 0, y, st, source=src, right=374)
        d.hs(16, y - 4, 240, 44, 'store-detail')
        button(d, 16, y + 46, 76, 30, '길찾기', kind='secondary', size=12, to='external-app')
        button(d, 98, y + 46, 64, 30, '전화', kind='secondary', size=12, to='external-app')
        y += 92
        d.rect(16, y - 8, 358, 1, fill=LINE)
    product_bottom(d, '지도에서 매장 보기', 'stores-map')


def s_product_similar(d):
    d.screen('product-similar', '상품 상세 · 비슷한 굿즈', 15, '상품 상세의 [비슷한 굿즈] 탭: 사진 · 글 임베딩이 가까운 굿즈', 2, 3)
    y = product_header(d, 'similar')
    d.text(16, y, '사진 · 이름이 비슷한 굿즈 (EmbeddingGemma 2)', size=12, color=SUB, lh=17)
    y += 26
    for i, k in enumerate(['kuromi_key', 'mymelo']):
        product_card(d, 16 + i * 185, y, k)
    product_bottom(d, '최저가로 구매하러 가기', 'external-mall')


def stores_top(d, mode):
    d.text(16, 16, '매장 찾기', size=22, weight='Bold', lh=30)
    d.rect(W - 16 - 132, 14, 132, 34, fill=BG, r=17)
    for i, (k, label, to) in enumerate([('list', '리스트', 'stores-list'), ('map', '지도', 'stores-map')]):
        x = W - 16 - 132 + 3 + i * 63
        if k == mode:
            d.rect(x, 17, 63, 28, fill=WHITE, r=14, stroke=LINE)
        d.text(x, 21, label, size=13, weight='SemiBold' if k == mode else 'Medium', color=INK if k == mode else SUB, w=63, align='center', lh=18)
        d.hs(x, 14, 63, 34, to)
    search_box(d, 58, '매장 이름 · 지역 검색')
    chips(d, 114, ['✓ 재고 있는 곳만', '팝업 포함', '굿즈: 내 IP ▼'], sel=0, dark=False, size=12, h=30)
    d.emoji('pin', 16, 158, 16)
    d.text(36, 157, '현재 위치 · 용산구 한강로', size=13, weight='Medium', lh=18)
    d.text(W - 16 - d.fonts.width('변경', 13, 'SemiBold'), 157, '변경', size=13, weight='SemiBold', color=BLUE, lh=18)
    return 188


def s_stores_list(d):
    d.screen('stores-list', '매장 찾기 · 리스트', 17, '하단 탭 [매장 찾기]', 0, 4)
    y = stores_top(d, 'list')
    for key in ['yongsan', 'hongdae', 'popup', 'kondae']:
        name, kind, dist, stock, popup = STORES[key]
        d.rect(16, y, 358, 126, fill=WHITE, r=14, stroke=LINE)
        d.text(30, y + 14, name, size=15, weight='SemiBold', lh=21)
        x = 30 + d.fonts.width(name, 15, 'SemiBold') + 8
        x += pill(d, x, y + 14, kind, ORANGE if kind == '팝업' else SUB, ORANGE_BG if kind == '팝업' else BG, size=10, h=20) + 6
        if popup:
            pill(d, x, y + 14, popup, RED, RED_BG, size=10, h=20)
        d.text(30, y + 40, dist, size=12, color=SUB, lh=17)
        fg, bg = (GREEN, GREEN_BG) if stock[0] == 'green' else (SUB, BG)
        pill(d, 30, y + 62, stock[1], fg, bg, size=11, h=22)
        if key == 'yongsan':
            d.hs(16, y, 358, 88, 'store-detail')
        for i, (label, to) in enumerate([('길찾기', 'external-app'), ('전화', 'external-app'), ('저장', None)]):
            button(d, 30 + i * 82, y + 92, 74, 26, label, kind='secondary', size=12, to=to)
        y += 138
    tabbar(d, 'stores-list')


def s_stores_map(d):
    d.screen('stores-map', '매장 찾기 · 지도', 18, '매장 찾기에서 [지도] 를 누른 화면', 1, 4)
    top = stores_top(d, 'map')
    mh = H - 66 - top
    d.rect(0, top, W, mh, fill='#EEF1E8')
    d.rect(0, top + 210, W, 46, fill='#CFE3F5')  # 강
    d.rect(250, top + 40, 110, 90, fill='#DCEBCF', r=10)  # 공원
    for x in (70, 170, 300):
        d.rect(x, top, 12, mh, fill=WHITE)
    for y in (top + 80, top + 160, top + 320, top + 420):
        d.rect(0, y, W, 12, fill=WHITE)
    d.rect(16, top + 12, 230, 30, fill=WHITE, r=15, stroke=LINE)
    lx = 28
    for color, label in [(GREEN, '많음'), ('#E3B341', '적음'), ('#B0B5BD', '확인 필요')]:
        d.ellipse(lx, top + 22, 10, 10, color)
        d.text(lx + 14, top + 18, label, size=12, weight='Medium', lh=17)
        lx += 14 + d.fonts.width(label, 12, 'Medium') + 14
    markers = [(110, top + 120, GREEN, True), (220, top + 70, GREEN, False), (330, top + 290, '#E3B341', False),
               (40, top + 360, '#B0B5BD', False), (260, top + 380, GREEN, False)]
    for mx, my, color, sel in markers:
        if sel:
            d.ellipse(mx - 19, my - 19, 38, 38, WHITE, stroke=ORANGE, sw=3)
        d.ellipse(mx - 13, my - 13, 26, 26, color, stroke=WHITE, sw=2)
    d.rect(178, top + 34, 98, 24, fill=WHITE, r=12, stroke=LINE)
    d.text(178, top + 37, '치이카와 팝업', size=11, weight='SemiBold', w=98, align='center', lh=16)
    d.ellipse(150 - 20, top + 220 - 20, 40, 40, BLUE, opacity=0.18)
    d.ellipse(150 - 8, top + 220 - 8, 16, 16, BLUE, stroke=WHITE, sw=3)
    cy = H - 66 - 150
    d.rect(12, cy, 366, 140, fill=WHITE, r=16, stroke=LINE)
    d.text(28, cy + 14, '피규어샵 용산점', size=16, weight='Bold', lh=22)
    d.text(28, cy + 40, '0.8km · 영업 중 · 20:30까지', size=12, color=SUB, lh=17)
    pill(d, 28, cy + 62, '내 IP 굿즈 재고 1개', GREEN, GREEN_BG, size=11, h=22)
    button(d, 28, cy + 96, 80, 32, '길찾기', kind='secondary', size=13, to='external-app')
    button(d, 116, cy + 96, 66, 32, '전화', kind='secondary', size=13, to='external-app')
    button(d, 236, cy + 96, 126, 32, '매장 상세 ›', size=13, to='store-detail')
    tabbar(d, 'stores-list')


def store_detail_body(d, overlay=False):
    app_bar(d, '피규어샵 용산점')
    d.rect(16, 62, 56, 56, fill=BG, r=14)
    d.emoji('store', 26, 72, 36)
    d.text(84, 66, '피규어 · 프라모델', size=14, weight='SemiBold', lh=20)
    pill(d, 84, 92, '영업 중', GREEN, GREEN_BG, size=11, h=22)
    y = 132
    for label, val in [('주소', '서울 용산구 (가상 주소) 2'), ('영업', '10:30 – 20:30 · 화요일 휴무'), ('전화', '02-000-1002')]:
        d.text(16, y, label, size=13, color=SUB, lh=18)
        d.text(64, y, val, size=13, weight='Medium', lh=18)
        y += 24
    d.text(16, y + 2, '정보 출처: 사장님 등록 · 10/28 갱신', size=11, color=SUB, lh=15)
    y += 28
    for i, (ic, label) in enumerate([('compass', '길찾기'), ('phone', '전화'), ('star', '저장'), ('link', '공유')]):
        x = 16 + i * 91
        d.rect(x, y, 83, 70, fill=BG, r=14)
        d.emoji(ic, x + 28, y + 10, 28)
        d.text(x, y + 44, label, size=12, weight='SemiBold', w=83, align='center', lh=17)
        if i < 2:
            d.hs(x, y, 83, 70, 'external-app')
    y += 86
    d.text(16, y, '재고', size=16, weight='Bold', lh=22)
    t = '재고가 다른가요? 제보하기 ›'
    tw = d.fonts.width(t, 13, 'SemiBold')
    d.text(W - 16 - tw, y + 2, t, size=13, weight='SemiBold', color=ORANGE, lh=18)
    d.hs(W - 26 - tw, y - 8, tw + 20, 38, 'stock-report')
    y += 34
    rows = [('RG 1/144 RX-78-2 건담', 'Ver. 2.0 · 사장님 확인 · 2시간 전', 'many', 'robot', '#E3ECFA'),
            ('HG 1/144 자쿠 II', '단품 · 사장님 확인 · 2시간 전', 'few', 'alien', '#E6F2E6'),
            ('세이버 피규어', '갑옷 ver. · 제보 · 어제', 'few', 'swords', '#E8EAF2'),
            ('리볼텍 단보 피규어', '미니 8cm · 수집 · 3일 전', 'check', 'package', '#F0E4D7')]
    for name, sub, st, ic, bg in rows:
        d.rect(16, y, 44, 44, fill=bg, r=10)
        d.emoji(ic, 24, y + 8, 28)
        d.text(70, y + 2, name, size=14, weight='SemiBold', lh=20)
        d.text(70, y + 24, sub, size=11, color=SUB, lh=15)
        stock_badge(d, 0, y + 10, st, right=374)
        y += 58
    t = '매장 정보가 달라요? 수정 제안 ›'
    d.text(0, y + 2, t, size=12, color=SUB, w=W, align='center', lh=17)
    tabbar(d, 'stores-list')


def s_store_detail(d):
    d.screen('store-detail', '매장 상세', 19, '매장 카드 · 지도 마커 · 상품 상세의 매장을 누르면 들어오는 화면', 2, 4)
    store_detail_body(d)


def s_stock_report(d):
    d.screen('stock-report', '재고 제보', 20, '매장 상세의 [제보하기] 를 누르면 아래에서 올라오는 창', 3, 4)
    y = dim_and_sheet(d, store_detail_body, 470)
    d.text(20, y, '재고 제보', size=19, weight='Bold', lh=26)
    y += 40
    for label, val in [('매장', '피규어샵 용산점'), ('굿즈', 'RG 1/144 RX-78-2 건담 · Ver. 2.0   ▼')]:
        d.text(20, y, label, size=13, color=SUB, lh=18)
        d.rect(64, y - 10, 306, 40, fill=BG, r=10)
        d.text(78, y, val, size=13, weight='Medium', lh=18)
        y += 50
    d.text(20, y, '지금 재고', size=13, weight='SemiBold', lh=18)
    y += 26
    for i, (label, fg, bg) in enumerate([('많음', GREEN, GREEN_BG), ('적음', AMBER, AMBER_BG), ('없음', RED, RED_BG)]):
        x = 20 + i * 120
        on = i == 0
        d.rect(x, y, 110, 42, fill=bg if on else WHITE, r=12, stroke=fg if on else LINE, sw=2 if on else 1)
        d.text(x, y + 11, label, size=14, weight='Bold' if on else 'Medium', color=fg if on else INK, w=110, align='center', lh=20)
    y += 58
    d.text(20, y, '사진 (선택)', size=13, weight='SemiBold', lh=18)
    d.rect(20, y + 26, 72, 72, fill=WHITE, r=12, stroke='#B0B5BD', dashes=[5, 4])
    d.text(20, y + 52, '+ 사진', size=12, color=SUB, w=72, align='center', lh=17)
    y += 112
    d.text(20, y, '사장님이 확인하면 반영돼요. 사장님이 없는 매장은 같은 제보가 2건 모이면 반영돼요.', size=12, color=SUB, lh=17, wrap=350)
    button(d, 20, H - 70, 350, 52, '제보하기', to='store-detail')


def s_my(d):
    d.screen('my', '마이', 21, '하단 탭 [마이]', 0, 5)
    d.text(16, 16, '마이', size=22, weight='Bold', lh=30)
    d.emoji('gear', W - 76, 20, 20)
    d.text(W - 52, 20, '설정', size=14, weight='Medium', lh=20)
    y = 64
    d.rect(16, y, 358, 104, fill=BG, r=16)
    d.ellipse(30, y + 18, 56, 56, WHITE)
    d.emoji('smile', 40, y + 28, 36)
    d.text(98, y + 18, '굿즈러버', size=18, weight='Bold', lh=24)
    d.text(98, y + 44, 'goods@example.com · 용산구', size=12, color=SUB, lh=17)
    t = '내 IP 6개 · 바꾸기 ›'
    pill(d, 98, y + 68, t, ORANGE, ORANGE_BG, size=12, h=24)
    d.hs(94, y + 64, 150, 32, 'ip-manage')
    y += 124

    def rows(y, title, items):
        d.text(16, y, title, size=13, weight='SemiBold', color=SUB, lh=18)
        y += 26
        for ic, label, val, to in items:
            d.emoji(ic, 18, y + 12, 22)
            d.text(50, y + 12, label, size=15, weight='Medium', lh=21)
            vw = d.fonts.width(val + ' ›', 14)
            d.text(W - 16 - vw, y + 13, val + ' ›', size=14, color=SUB, lh=20)
            if to:
                d.hs(0, y, W, 46, to)
            y += 46
        return y + 12

    y = rows(y, '내 굿즈', [('red_heart', '찜한 굿즈', '5', None), ('bell', '알림 설정', '3개 켜짐', None), ('star', '저장한 매장', '2', None)])
    y = rows(y, '내 기록', [('cart', '이동 기록', '2', 'history'), ('receipt', '구매 기록', '2', None),
                          ('memo', '내 제보', '2', None), ('speech', '문의 내역', '1', None)])
    d.rect(16, y, 358, 64, fill=ORANGE_BG, r=14)
    d.emoji('store', 30, y + 16, 32)
    d.text(74, y + 12, '사장님이신가요?', size=14, weight='Bold', color=ORANGE, lh=20)
    d.text(74, y + 34, '판매자 센터에서 매장 재고를 관리하세요 ›', size=12, color=INK, lh=17)
    d.hs(16, y, 358, 64, 'seller-inventory')
    tabbar(d, 'my')


def history_body(d, overlay=False):
    app_bar(d, '이동 기록')
    d.rect(16, 62, 358, 40, fill=BLUE_BG, r=10)
    d.emoji('bulb', 28, 72, 18)
    d.text(52, 72, '구매하러 가기를 누른 시점의 가격이 저장돼요', size=13, weight='Medium', color=BLUE, lh=18)
    y = 118
    recs = [('10/27 21:14 · 오픈마켓 A', 'RG 1/144 RX-78-2 건담 · Ver. 2.0', '당시 39,800원 · 무료배송', True, 'robot', '#E3ECFA'),
            ('10/25 13:02 · 공식 온라인몰', '쿠로미 마스코트 인형 · 일반 10cm', '당시 15,000원 · 무료배송', False, 'horns', '#ECE0F5'),
            ('10/20 18:40 · 오픈마켓 B', '피카츄 인형 · M', '당시 21,000원 + 배송 3,000원', False, 'bolt', '#FFF6CC')]
    for i, (when, name, price, bought, ic, bg) in enumerate(recs):
        d.rect(16, y, 358, 132, fill=WHITE, r=14, stroke=LINE)
        d.text(30, y + 14, when, size=12, color=SUB, lh=17)
        d.rect(30, y + 38, 44, 44, fill=bg, r=10)
        d.emoji(ic, 38, y + 46, 28)
        d.text(86, y + 38, name, size=14, weight='SemiBold', lh=20)
        d.text(86, y + 62, price, size=13, weight='Medium', color=INK, lh=18)
        if bought:
            button(d, 30, y + 92, 104, 30, '✓ 구매함', kind='green', size=12)
        else:
            button(d, 30, y + 92, 104, 30, '구매했어요', kind='secondary', size=12)
        button(d, 142, y + 92, 92, 30, '문제 제기', kind='secondary', size=12, to='issue-report' if i == 0 else None)
        y += 146


def s_history(d):
    d.screen('history', '이동 기록', 22, '마이 → 이동 기록', 1, 5)
    history_body(d)


def s_issue(d):
    d.screen('issue-report', '문제 제기', 23, '이동 기록 · 구매 기록에서 [문제 제기] 를 누르면 올라오는 창', 2, 5)
    y = dim_and_sheet(d, history_body, 470)
    d.text(20, y, '문제 제기', size=19, weight='Bold', lh=26)
    y += 38
    d.rect(20, y, 350, 40, fill=BG, r=10)
    d.emoji('cart', 32, y + 11, 18)
    d.text(58, y + 11, '10/27 · 오픈마켓 A · RG 1/144 RX-78-2 건담', size=13, weight='Medium', lh=18)
    y += 56
    d.text(20, y, '어떤 문제인가요?', size=13, weight='SemiBold', lh=18)
    y += 26
    y = chips(d, y, ['가격이 달랐어요', '재고가 없었어요'], sel=0, x=20, dark=False, size=13, h=34) + 8
    y = chips(d, y, ['가품이 의심돼요', '기타'], sel=-1, x=20, dark=False, size=13, h=34) + 14
    d.rect(20, y, 350, 74, fill=WHITE, r=12, stroke=LINE)
    d.text(34, y + 12, '결제 화면에서 41,000원으로 나왔어요', size=14, lh=20)
    y += 86
    d.rect(20, y, 350, 40, fill=BLUE_BG, r=10)
    d.text(32, y + 11, '당시 가격 39,800원과 지금 가격 41,000원이 함께 전달돼요', size=12, weight='Medium', color=BLUE, lh=17)
    button(d, 20, H - 70, 350, 52, '보내기', to='history')


def seller_top(d, tab):
    d.text(16, 16, '판매자 센터', size=22, weight='Bold', lh=30)
    t = '피규어샵 용산점 ▼'
    d.text(W - 16 - d.fonts.width(t, 14, 'SemiBold'), 22, t, size=14, weight='SemiBold', lh=20)
    tabs = [('inv', '재고 관리', 'seller-inventory'), ('reg', '상품 등록', 'seller-register'), ('rep', '제보 2', None), ('info', '매장 정보', None)]
    x = 16
    for k, label, to in tabs:
        on = k == tab
        tw = d.fonts.width(label, 14, 'Bold' if on else 'Medium')
        d.text(x, 64, label, size=14, weight='Bold' if on else 'Medium', color=INK if on else SUB, lh=20)
        if on:
            d.rect(x, 92, tw, 3, fill=ORANGE, r=1.5)
        if to:
            d.hs(x - 8, 56, tw + 16, 40, to)
        x += tw + 22
    d.rect(0, 95, W, 1, fill=LINE)
    return 110


def seg3(d, x, y, sel, w=150, h=30):
    labels = [('많음', GREEN, GREEN_BG), ('적음', AMBER, AMBER_BG), ('없음', RED, RED_BG)]
    d.rect(x, y, w, h, fill=BG, r=h / 2)
    sw_ = w / 3
    for i, (label, fg, bg) in enumerate(labels):
        on = i == sel
        if on:
            d.rect(x + i * sw_ + 2, y + 2, sw_ - 4, h - 4, fill=bg, r=(h - 4) / 2, stroke=fg)
        d.text(x + i * sw_, y + (h - 17) / 2, label, size=12, weight='Bold' if on else 'Medium', color=fg if on else SUB, w=sw_, align='center', lh=17)


def s_seller_inventory(d):
    d.screen('seller-inventory', '판매자 센터 · 재고 관리', 24, '사장님 계정 · 마이 → 판매자 센터', 3, 5)
    y = seller_top(d, 'inv')
    d.rect(16, y, 358, 64, fill=GREEN_BG, r=14, stroke=GREEN)
    d.emoji('check', 30, y + 18, 26)
    d.text(66, y + 12, '오늘 재고 그대로예요', size=16, weight='Bold', color=GREEN, lh=22)
    d.text(66, y + 36, '상태는 그대로, 전 품목 확인 시각만 지금으로', size=12, color=GREEN, lh=17)
    y += 76
    d.text(16, y, '마지막 확인: 어제 19:30 · 품목 12개', size=12, color=SUB, lh=17)
    y += 28
    rows = [('RG 1/144 RX-78-2 건담', 'Ver. 2.0', 0, False), ('RG 1/144 RX-78-2 건담', '구판', 2, True),
            ('HG 1/144 자쿠 II', '단품', 1, False), ('세이버 피규어', '갑옷 ver.', 1, True),
            ('세이버 피규어', '드레스 ver.', 0, False), ('리볼텍 단보 피규어', '미니 8cm', 1, False)]
    for name, ver, sel, changed in rows:
        if changed:
            d.rect(8, y - 6, W - 16, 58, fill='#FFF8F3', r=10)
        d.text(16, y, name, size=14, weight='SemiBold', lh=20)
        d.text(16, y + 22, ver, size=12, color=SUB, lh=17)
        if changed:
            pill(d, 16 + d.fonts.width(ver, 12) + 8, y + 21, '변경', ORANGE, ORANGE_BG, size=10, h=19)
        seg3(d, 224, y + 6, sel)
        y += 62
    button(d, 16, H - 112, 358, 52, '변경 저장 (2건)')
    d.text(0, H - 48, '사용자 화면으로 돌아가기', size=13, color=SUB, w=W, align='center', lh=18)
    d.hs(100, H - 56, 190, 36, 'my')


def s_seller_register(d):
    d.screen('seller-register', '판매자 센터 · 상품 등록', 25, '판매자 센터 → [상품 등록]', 4, 5, height=1010)
    y = seller_top(d, 'reg')

    def step(y, n, title):
        d.ellipse(16, y, 24, 24, ORANGE)
        d.text(16, y + 3, str(n), size=12, weight='Bold', color=WHITE, w=24, align='center', lh=18)
        d.text(48, y + 2, title, size=16, weight='Bold', lh=22)
        return y + 36

    y = step(y, 1, '사진 올리기')
    d.rect(16, y, 358, 120, fill='#E3ECFA', r=14)
    d.emoji('robot', W / 2 - 36, y + 22, 72)
    pill(d, 282, y + 86, '다시 찍기', INK, WHITE, size=12, h=26)
    y += 128
    d.text(16, y, '박스 앞면이 잘 보이게 찍어 주세요', size=12, color=SUB, lh=17)
    y += 26
    d.text(16, y, '상품명 (선택)', size=13, weight='SemiBold', lh=18)
    d.rect(16, y + 24, 358, 44, fill=BG, r=12)
    d.text(32, y + 36, 'RG 건담', size=14, weight='Medium', lh=20)
    y += 86
    y = step(y, 2, '같은 굿즈 고르기')
    d.text(16, y, 'AI가 찾은 후보', size=13, weight='SemiBold', color=SUB, lh=18)
    y += 26
    cands = [('RG 1/144 RX-78-2 건담', 'Ver. 2.0', '81%', True), ('RG 1/144 RX-78-2 건담', '구판', '80%', False),
             ('HG 1/144 자쿠 II', '단품', '61%', False)]
    for name, ver, sim, on in cands:
        d.rect(16, y, 358, 60, fill=ORANGE_BG if on else WHITE, r=12, stroke=ORANGE if on else LINE, sw=2 if on else 1)
        d.ellipse(28, y + 20, 20, 20, ORANGE if on else WHITE, stroke=None if on else LINE)
        if on:
            d.ellipse(34, y + 26, 8, 8, WHITE)
        d.rect(58, y + 8, 44, 44, fill='#E3ECFA' if '자쿠' not in name else '#E6F2E6', r=10)
        d.emoji('robot' if '자쿠' not in name else 'alien', 66, y + 16, 28)
        d.text(112, y + 10, name, size=14, weight='SemiBold', lh=20)
        pill(d, 112, y + 32, ver, ORANGE, WHITE if on else ORANGE_BG, size=10, h=19)
        sw_ = d.fonts.width(sim, 15, 'Bold')
        d.text(360 - sw_, y + 20, sim, size=15, weight='Bold', color=ORANGE if on else SUB, lh=20)
        y += 68
    d.rect(16, y, 358, 50, fill=AMBER_BG, r=12)
    d.emoji('warning', 28, y + 15, 18)
    d.text(54, y + 8, 'Ver. 2.0과 구판은 박스가 비슷해요.\n박스 오른쪽 위 표기를 확인하세요.', size=12, weight='Medium', color=AMBER, lh=17)
    y += 60
    d.text(16, y, '찾는 굿즈가 없어요 → 새 굿즈 요청 ›', size=13, weight='Medium', color=BLUE, lh=18)
    y += 38
    y = step(y, 3, '재고 · 판매가')
    seg3(d, 16, y, 0, w=210, h=36)
    d.rect(236, y, 138, 36, fill=BG, r=10)
    d.text(248, y + 9, '판매가 39,000원', size=13, weight='Medium', lh=18)
    y += 52
    button(d, 16, y, 358, 52, '내 매장에 추가', to='seller-inventory')
    d.text(0, y + 66, '사용자 화면으로 돌아가기', size=13, color=SUB, w=W, align='center', lh=18)
    d.hs(100, y + 58, 190, 36, 'my')


def s_external_mall(d):
    d.screen('external-mall', '외부 쇼핑몰로 이동', 15, '[구매하러 가기]: 앱 밖 몰로 이동하고, 이동 기록에 당시 가격을 저장', 3, 3)
    d.emoji('bags', W / 2 - 44, 230, 88)
    d.text(0, 336, '오픈마켓 A로 이동해요', size=22, weight='Bold', w=W, align='center', lh=30)
    d.text(40, 378, '구매하러 가기를 누른 시점의 가격 12,900원을\n이동 기록에 저장했어요', size=14, color=SUB, w=310, align='center', lh=21)
    d.rect(40, 444, 310, 1, fill=LINE)
    d.text(0, 460, '프로토타입이라 실제 몰로는 이동하지 않아요', size=12, color=SUB, w=W, align='center', lh=17)
    button(d, 24, 690, 342, 50, '이동 기록 보기', kind='secondary', to='history')
    button(d, 24, 750, 342, 52, '굿모닝으로 돌아가기', to='back')


def s_external_app(d):
    d.screen('external-app', '지도 앱 · 전화 앱 연결', 19, '[길찾기] · [전화]: 지도 앱 · 전화 앱으로 바로 연결', 4, 4)
    d.emoji('map', W / 2 - 44, 230, 88)
    d.text(0, 336, '지도 앱 · 전화 앱으로 연결돼요', size=21, weight='Bold', w=W, align='center', lh=30)
    d.text(40, 378, '길찾기는 지도 앱 딥링크, 전화는 전화 앱(tel:)으로\n앱 밖에서 열려요', size=14, color=SUB, w=310, align='center', lh=21)
    d.text(0, 446, '프로토타입이라 실제 앱은 열지 않아요', size=12, color=SUB, w=W, align='center', lh=17)
    button(d, 24, 750, 342, 52, '굿모닝으로 돌아가기', to='back')


SCREENS = [s_login, s_signup, s_signup_ip, s_home, s_home_online, s_home_offline, s_photo_pick, s_photo_search,
           s_notifications, s_search, s_explore, s_ip_manage, s_ip_sanrio, s_character, s_product_online,
           s_product_offline, s_product_similar, s_external_mall, s_stores_list, s_stores_map, s_store_detail,
           s_stock_report, s_external_app, s_my, s_history, s_issue, s_seller_inventory, s_seller_register]


def figcraft_cmd():
    custom = os.environ.get('FIGCRAFT_CLI')
    if custom:
        return shlex.split(custom)
    return ['flatpak', 'run', f'--filesystem={ROOT}', '--command=figcraft-cli', 'ai.storyteller.figcraft']


def main():
    d = Doc()
    for fn in SCREENS:
        fn(d)
    d.finish('login')

    WORK.mkdir(parents=True, exist_ok=True)
    if SCREEN_DIR.exists():
        shutil.rmtree(SCREEN_DIR)
    SCREEN_DIR.mkdir(parents=True)
    script = WORK / 'script.json'
    script.write_text(json.dumps(d.cmds, ensure_ascii=False), encoding='utf-8')
    print(f'명령 {len(d.cmds)}개, 화면 {len(d.screens)}장 → figcraft-cli run')
    res = subprocess.run(figcraft_cmd() + ['run', str(script), '--out', str(OUT_FIG)], capture_output=True, text=True)
    lines = [json.loads(line) for line in res.stdout.splitlines() if line.startswith('{')]
    if res.returncode != 0 or not lines or not all(x.get('ok') for x in lines):
        bad = [x for x in lines if not x.get('ok')]
        print(res.stdout[-2000:], res.stderr[-2000:])
        raise SystemExit(f'figcraft-cli 실패: {bad[:1]}')
    by_step = {x['step']: x for x in lines}
    wrong = [(step, nid, by_step[step]['result'].get('id')) for step, nid in d.expect
             if by_step[step]['result'].get('id') != nid]
    if wrong:
        raise SystemExit(f'레이어 id 예측이 어긋남: {wrong[:5]}')

    manifest = {
        'title': '굿모닝 · 클릭 프로토타입',
        'source': 'prototype/goodmorning.figcraft (FigCraft에서 열어 수정 · 발표 모드로 재생)',
        'start': 'login', 'width': W,
        'screens': [{'slug': s['slug'], 'title': s['title'], 'slide': s['slide'], 'desc': s['desc'],
                     'image': f"screens/{s['slug']}.png", 'height': s['height'],
                     'hotspots': [{k: h[k] for k in ('x', 'y', 'w', 'h', 'to')} for h in s['hotspots']]}
                    for s in d.screens],
    }
    (SITE / 'screens.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding='utf-8')
    n_links = sum(len(s['hotspots']) for s in d.screens)
    print(f'완료: {OUT_FIG.relative_to(ROOT)}, PNG {len(d.screens)}장, 클릭 영역 {n_links}개')


if __name__ == '__main__':
    main()
