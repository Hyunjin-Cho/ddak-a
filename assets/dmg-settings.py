# -*- coding: utf-8 -*-
# 닦아 DMG 설치 창 설정 (2026-09-22)
#
# 🚨 왜 dmgbuild 를 쓰나: 창 모양(배경·아이콘 위치·창 크기)은 .DS_Store 에 저장되는데,
# 그걸 만드는 정상 경로인 Finder AppleScript 의 "배경 그림 지정"이 macOS 27 에서 깨져 있다
# (설정은 오류 없이 무시되고, 읽기는 -10000 오류 — 2026-09-22 실측).
# dmgbuild 는 Finder 를 거치지 않고 .DS_Store 를 직접 만들기 때문에 그 버그와 무관하다.
#
# 🔒 아래 아이콘 좌표는 배경 그림(assets/dmg-background.swift)의 화살표 위치와 같은 값이어야 한다.
#    한쪽만 고치면 화살표가 엉뚱한 곳을 가리킨다.
import os.path

application = defines.get("app", "ddak-a.app")
appname = os.path.basename(application)

format = "UDZO"
compression_level = 9
size = None

files = [application]
symlinks = {"Applications": "/Applications"}

background = defines.get("background", "assets/dmg-background.tiff")

window_rect = ((200, 120), (640, 400))   # 배경 그림과 같은 640x400
default_view = "icon-view"
icon_size = 128
text_size = 13
label_pos = "bottom"
arrange_by = None                         # 자동 정렬을 끄지 않으면 아이콘 좌표가 무시된다

icon_locations = {
    appname: (165, 215),
    "Applications": (475, 215),
}

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
