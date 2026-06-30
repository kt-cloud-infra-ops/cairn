#!/usr/bin/env python3
"""하네스 자산을 바꾼 PR이 plugin.json version을 bump했고 marketplace.json과 동기화됐는지 강제.

ADR-015 (version no-op 트랩 봉쇄):
  /plugin update는 version 문자열만 비교한다. 자산(skills/hooks/rules…)이 바뀌어도 version이
  그대로면 동일버전=동일캐시로 취급해 재clone을 스킵 → 엔진 변경이 팀 세션에 0% 도달.
  이 게이트는 "자산 변경 ⇒ version 증가"를 main 머지 조건으로 만들어 트랩을 구조적으로 차단한다.

usage: version-bump-gate.py <base-ref>   # 예: origin/main
"""
import json
import subprocess
import sys

base = sys.argv[1]

ASSET_PREFIXES = ("skills/", "hooks/", "rules/", "rules-on-demand/", "agents/", "templates/")


def sh(*args):
    return subprocess.run(args, capture_output=True, text=True).stdout


def ver(s):
    return tuple(int(x) for x in s.strip().split("."))


changed = sh("git", "diff", "--name-only", f"{base}...HEAD").split()
asset_changed = any(c.startswith(ASSET_PREFIXES) or c == "AGENTS.md" for c in changed)

new_plugin = json.load(open(".claude-plugin/plugin.json"))["version"]
mkt = json.load(open(".claude-plugin/marketplace.json"))
new_mkt = next(p["version"] for p in mkt["plugins"] if p["name"] == "cairn")

errors = []

# 1) 두 매니페스트 version 동기화
if new_plugin != new_mkt:
    errors.append(
        f"plugin.json({new_plugin}) != marketplace.json({new_mkt}) — 두 version을 동기화하세요."
    )

# 2) 자산 변경 시 bump(증가) 강제
if asset_changed:
    old_raw = sh("git", "show", f"{base}:.claude-plugin/plugin.json")
    if not old_raw.strip():
        print("base에 plugin.json 없음 — 신규 도입, bump 게이트 skip")
    else:
        old_plugin = json.loads(old_raw)["version"]
        if ver(new_plugin) <= ver(old_plugin):
            errors.append(
                f"하네스 자산(skills/hooks/rules 등)이 변경됐으나 plugin.json version이 "
                f"{old_plugin} -> {new_plugin} 로 증가하지 않았습니다. "
                f"version no-op 트랩 봉쇄(ADR-015): 최소 patch bump가 필요합니다."
            )
        else:
            print(f"version bump 확인: {old_plugin} -> {new_plugin}")
else:
    print("하네스 자산 변경 없음 — bump 게이트 skip")

if errors:
    for e in errors:
        print(f"::error::{e}")
    sys.exit(1)

print("version-bump-gate 통과")
