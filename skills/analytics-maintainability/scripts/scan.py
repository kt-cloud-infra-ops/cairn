#!/usr/bin/env python3
"""
결정층 문서 건강 스캔 (유지가능성 측정).

전 서비스의 도메인 에이전트(agents/domain/*.md)와 ADR(docs/decisions/*.md)을 스캔해
stale(신선도) · 충실도 · 커버리지 신호를 리포트한다. 읽기 전용.

사용: python3 scan.py [workspace-root] [stale-days]
  기본 root: ~/Documents/develop/workspace, 기본 stale: 90일
종료코드: 항상 0 (분석 도구). stale/빈 문서가 있으면 리포트에 표시.
"""
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Documents/develop/workspace"
STALE_DAYS = int(sys.argv[2]) if len(sys.argv) > 2 else 90
TODAY = date.today()

WHY_SECTIONS = ("결정 이력", "판단 시나리오")  # 비면 충실도 LOW


def parse_frontmatter(text: str) -> dict:
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        return {}
    fm = {}
    for line in m.group(1).splitlines():
        mm = re.match(r'\s*([\w_]+):\s*"?([^"#]*?)"?\s*(?:#.*)?$', line)
        if mm and mm.group(2).strip():
            fm[mm.group(1)] = mm.group(2).strip()
    return fm


def days_since(iso: str):
    try:
        d = date.fromisoformat(iso[:10])
        return (TODAY - d).days
    except Exception:
        return None


def why_filled(text: str) -> bool:
    """결정 이력/판단 시나리오 섹션에 placeholder(_예:) 외 실제 표 행이 있나."""
    for sec in WHY_SECTIONS:
        m = re.search(rf"##[^\n]*{sec}.*?(?=\n## |\Z)", text, re.S)
        if not m:
            continue
        for line in m.group(0).splitlines():
            s = line.strip()
            if not s.startswith("|"):
                continue
            if "---" in s or "결정" in s and "배경" in s:  # 구분선/헤더 skip
                continue
            cells = [c.strip() for c in s.strip("|").split("|")]
            real = [c for c in cells if c and not c.startswith("_") and not c.startswith("예:")]
            if real:
                return True
    return False


def scan():
    domain = sorted(ROOT.glob("*/agents/domain/*.md"))
    adr = sorted(ROOT.glob("*/docs/decisions/*.md"))
    domain = [p for p in domain if not p.name.startswith("_")]
    adr = [p for p in adr if not p.name.startswith("_")]

    rows = []
    for p in domain + adr:
        kind = "domain" if "/agents/domain/" in str(p) else "adr"
        svc = p.relative_to(ROOT).parts[0]
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        fm = parse_frontmatter(text)
        lv = fm.get("last_verified", "")
        age = days_since(lv) if lv else None
        flags = []
        if not lv:
            flags.append("NO-last_verified")
        elif age is not None and age > STALE_DAYS:
            flags.append(f"STALE({age}d)")
        if kind == "domain" and not why_filled(text):
            flags.append("WHY-EMPTY")
        if not fm.get("maintainer"):
            flags.append("NO-maintainer")
        rows.append((svc, kind, p.name, fm.get("maintainer", "-"), lv or "-", flags))

    print(f"=== 결정층 건강 스캔 (root={ROOT}, stale>{STALE_DAYS}d, today={TODAY}) ===")
    print(f"도메인 에이전트 {len(domain)}건, ADR {len(adr)}건\n")
    if not rows:
        print("⚠️ 결정층 문서 0건 — 스캐폴드 미적용 서비스일 수 있음.")
        return
    healthy = [r for r in rows if not r[5]]
    issues = [r for r in rows if r[5]]
    by_maint = {}
    for svc, kind, name, maint, lv, flags in issues:
        by_maint.setdefault(maint, []).append((svc, kind, name, lv, flags))
    print(f"✅ 건강 {len(healthy)}건 / ⚠️ 조치 필요 {len(issues)}건\n")
    for maint, items in sorted(by_maint.items()):
        print(f"── maintainer: {maint} ({len(items)}건) ──")
        for svc, kind, name, lv, flags in items:
            print(f"  [{svc}/{kind}] {name} (last_verified={lv}) → {', '.join(flags)}")
        print()


if __name__ == "__main__":
    scan()
