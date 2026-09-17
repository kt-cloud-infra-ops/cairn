#!/usr/bin/env python3
"""security-check-* 스킬의 구조 검증기.

rules/skill-governance.md 최소 요건 + GATE 규약 + 참조 무결성을 자동 점검한다.

사용법:
    python3 scripts/verify-security-skills.py [글롭]
      글롭 기본값: skills/security-check-*/SKILL.md

점검 항목:
  - frontmatter: YAML 파싱, name==폴더명, 단일라인 description, triggers(guard-skill-create 요구)
  - 본문: 스킬 규칙(ALWAYS/NEVER), 실행 절차, 완료 조건(DONE WHEN) 태그
  - GATE: 개수 <=3, 번호 0부터 순차, 체크박스 조건, NEVER에 우회 차단 룰 병행
  - 참조 무결성: SKILL.md가 가리키는 파일 실재 + 고아 reference 없음
  - 번들 스크립트: 실행권한, shebang, SKILL.md 언급 여부

종료코드: 0=전부 통과, 1=실패 항목 있음
"""

import pathlib, re, sys, yaml

ROOT = pathlib.Path(".")
GLOB = sys.argv[1] if len(sys.argv) > 1 else "skills/security-check-*/SKILL.md"
targets = sorted(ROOT.glob(GLOB))
fail = []

def check(cond, msg, skill):
    print(("  ✅ " if cond else "  ❌ ") + msg)
    if not cond:
        fail.append(f"{skill}: {msg}")

for f in targets:
    skill = f.parent.name
    print(f"\n===== {skill} =====")
    text = f.read_text(encoding="utf-8")

    # frontmatter
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    check(bool(m), "YAML frontmatter 블록 존재", skill)
    if not m:
        continue
    try:
        fm = yaml.safe_load(m.group(1))
        ok = isinstance(fm, dict)
    except Exception as e:
        fm, ok = {}, False
        print(f"     parse error: {e}")
    check(ok, "frontmatter YAML 파싱 성공", skill)
    check(fm.get("name") == skill, f"name == 폴더명 ({skill})", skill)
    desc = fm.get("description") or ""
    check(isinstance(desc, str) and len(desc) >= 40, "description 존재 및 트리거 서술 충분(>=40자)", skill)
    check("\n" not in desc, "description 단일 라인", skill)
    trig = fm.get("triggers")
    check(isinstance(trig, list) and len(trig) >= 1, "triggers 리스트 존재 (guard-skill-create 요구)", skill)
    check(set(fm) <= {"name", "description", "triggers"}, "frontmatter 필드 최소화", skill)

    body = text[m.end():]
    # governance 최소 요건
    check("## 스킬 규칙" in body, "## 스킬 규칙 섹션", skill)
    always = re.search(r"^### ALWAYS\n((?:- .*\n)+)", body, re.M)
    never = re.search(r"^### NEVER\n((?:- .*\n)+)", body, re.M)
    check(bool(always) or "[ALWAYS]" in body, "ALWAYS 최소 1개", skill)
    check(bool(never) or "[NEVER]" in body, "NEVER 최소 1개", skill)
    steps = re.findall(r"^\d+\. \*\*", body, re.M)
    check("## 실행 절차" in body and len(steps) >= 1, f"## 실행 절차 단계 {len(steps)}개", skill)
    done = re.search(r"^## 완료 조건 \(DONE WHEN\)\n((?:- \[ \] .*\n)+)", body, re.M)
    check(bool(done), "## 완료 조건 (DONE WHEN) 섹션", skill)
    tags = set(re.findall(r"\[(GATE|FILE|CONTENT|GIT|MANUAL)\]", done.group(1) if done else ""))
    check(len(tags) >= 1, f"DONE WHEN 태그 {sorted(tags)}", skill)

    # GATE 규약
    gates = re.findall(r"^#### \[GATE (\d+)\] (.+)$", body, re.M)
    nums = [int(n) for n, _ in gates]
    check(1 <= len(gates) <= 3, f"GATE 개수 {len(gates)} (권장 한도 3 이내)", skill)
    check(nums == sorted(nums) and nums == list(range(len(nums))), f"GATE 번호 0부터 순차 {nums}", skill)
    for n, _ in gates:
        blk = re.search(rf"#### \[GATE {n}\].*?\n(.*?)(?=\n#### |\n## |\Z)", body, re.S).group(1)
        check(len(re.findall(r"^- \[ \] ", blk, re.M)) >= 1, f"GATE {n} 체크박스 조건 존재", skill)
    for n, _ in gates:
        check(re.search(rf"\[GATE {n}\][^\n]*금지", body) is not None,
              f"NEVER에 [GATE {n}] 우회 차단 룰 병행", skill)

    # 참조 무결성
    refs = set(re.findall(r"`([^`]*?references/[a-z0-9-]+\.md)`", body))
    refs |= set(re.findall(r"`(docs/[A-Z0-9_]+\.md)`", body))
    for r in sorted(refs):
        p = (f.parent / r) if not r.startswith("docs/") else (ROOT / r)
        check(p.resolve().exists(), f"참조 실재: {r}", skill)


    # 번들 스크립트 무결성
    sdir = f.parent / "scripts"
    if sdir.is_dir():
        for sf in sorted(sdir.glob("*.sh")):
            rel = f"skills/{skill}/scripts/{sf.name}"
            check(sf.stat().st_mode & 0o111 != 0, f"실행권한: scripts/{sf.name}", skill)
            check(sf.read_text(encoding="utf-8").startswith("#!"), f"shebang: scripts/{sf.name}", skill)
            check(rel in text or "source 전용" in text or sf.name in text,
                  f"scripts/{sf.name} → SKILL.md에서 언급됨", skill)

    # 고아 reference (SKILL.md가 언급하지 않는 파일)
    refdir = f.parent / "references"
    if refdir.is_dir():
        for rf in sorted(refdir.glob("*.md")):
            check(rf.name in text, f"references/{rf.name} → SKILL.md에서 참조됨", skill)

print("\n" + "=" * 50)
if fail:
    print(f"FAIL {len(fail)}건")
    for x in fail:
        print("  - " + x)
    sys.exit(1)
print("ALL PASS")
