---
name: skill-sync-claude-2-codex
description: "Claude Code의 스킬을 Codex(${CODEX_HOME:-~/.codex}/skills/)로 심볼릭 링크. Claude/Codex 양쪽에서 같은 스킬 세트를 쓰고 싶을 때 실행."
model: haiku
---

<!-- symlink 생성 스크립트 1회 실행 + 파일 수 대조가 전부. 토큰 절약 목적 haiku. -->


## 스킬 규칙
### ALWAYS
- Claude Code 스킬이 canonical (agents/skills/ 원본)
- Codex는 심볼릭 링크로만 동기화 (원본 수정 시 자동 반영)
- 새 스킬 추가/이름 변경/삭제 후 재실행
### NEVER
- Codex 쪽 스킬 원본을 수정 금지 (심볼릭 링크 대상이므로 원본이 바뀜)
- ${CODEX_HOME:-~/.codex}/skills/.system/ 건드리기 금지 (Codex 시스템 스킬)
- vendor/ 동기화 금지 (Claude 전용 외부 스킬)

## 실행 절차

1. 스크립트 실행:
   ```bash
   bash agents/skills/skill-sync-claude-2-codex/scripts/sync.sh
   ```
2. `agents/skills/` 아래 `SKILL.md`를 가진 모든 스킬(vendor/self 제외)이 `${CODEX_HOME:-~/.codex}/skills/{name}` 심볼릭 링크로 생성됨
3. Codex 세션 재시작 → 슬래시 커맨드로 사용 가능
4. Claude에서 스킬 추가/수정 시 — Claude는 즉시 반영, Codex는 폴더 추가/삭제 시 재실행 필요

## 완료 조건 (DONE WHEN)
- [ ] [FILE] `${CODEX_HOME:-~/.codex}/skills/` 아래 심볼릭 링크가 `agents/skills/`의 전체 스킬 수(vendor/self 제외)와 일치
- [ ] [CONTENT] `${CODEX_HOME:-~/.codex}/skills/.system/` 폴더는 건드려지지 않음
- [ ] [MANUAL] Codex 세션 재시작 후 스킬이 슬래시 커맨드로 검색됨

## 참고

- 스크립트: `scripts/sync.sh`
- Codex 공식 스킬 경로: `${CODEX_HOME:-~/.codex}/skills/` ([Codex 확인](../../../base/guides/decisions/harness-engineering/))
- 향후 Claude ↔ Codex 양방향 동기화가 필요해지면 `sync-bidirectional` 옵션 추가 검토
