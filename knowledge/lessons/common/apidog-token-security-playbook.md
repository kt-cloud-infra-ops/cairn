---
tags:
  - type/guide
  - domain/security
  - domain/api
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# Apidog Access Token 보안 운영 플레이북

## 목적

Apidog Personal Access Token 운영 시 노출 사고를 줄이고, 노출 시 빠르게 회수/복구하기 위한 실무 체크리스트.

---

## 토큰 노출 시 즉시 대응

1. Apidog에서 기존 토큰을 즉시 폐기(revoke)한다.
2. 신규 토큰을 발급한다.
3. 자동화 스크립트/환경변수 값을 신규 토큰으로 교체한다.
4. 기존 토큰이 남아있을 수 있는 위치를 점검한다.
5. 필요 시 관련 작업 로그/이력에 로테이션 완료 사실을 남긴다.

권장 목표 시간: 15분 이내

---

## 저장 위치 원칙

우선순위:

1. 세션 환경변수 (`APIDOG_ACCESS_TOKEN`, `APIDOG_PROJECT_ID`)
2. 로컬 파일 `~/.apidog-credentials.json` (권한 600)

권장:

- 토큰은 Git 추적 파일에 저장하지 않는다.
- 스크립트 하드코딩 금지.
- 공유 문서/이슈/채팅에 평문 토큰 복붙 금지.

---

## 로컬 점검 명령어

```bash
# 토큰 패턴 점검 (로컬 저장소)
rg -n "adgp_[A-Za-z0-9]+" .

# 환경변수 확인 (값 직접 출력 대신 존재 여부만 확인)
env | rg "APIDOG_ACCESS_TOKEN|APIDOG_PROJECT_ID"

# credential 파일 권한 확인
ls -l ~/.apidog-credentials.json
```

---

## 최소 권한 운영 가이드

- 프로젝트 단위로 토큰 용도를 분리한다.
- 운영/개발 토큰을 분리한다.
- 장기 토큰 대신 주기적 교체(예: 월 1회) 정책을 둔다.
- 배치/자동화 실패 시 토큰 권한 오류와 스펙 오류를 분리해 진단한다.

---

## 사고 후 검증 체크리스트

- [ ] 신규 토큰으로 `export-openapi` 호출 성공 확인
- [ ] 기존 토큰으로 호출이 실패하는지 확인 (정상 revoke 확인)
- [ ] 로컬/문서/스크립트에 평문 토큰 잔존 여부 점검
- [ ] 후속 작업자에게 새 토큰 전달 방식(보안 채널) 확인

---

## 권장 운영 템플릿

```bash
# 1) 토큰/프로젝트 설정
export APIDOG_ACCESS_TOKEN="***"
export APIDOG_PROJECT_ID="992853"

# 2) 연결 검증  ([미확인] apidog-openapi-sync 스킬은 cairn 엔진 미포함 — 도메인/워크스페이스 스킬로 별도 제공 시 경로 조정)
python3 skills/apidog-openapi-sync/scripts/apidog_rest_api.py export-openapi \
  --scope all \
  --oas-version 3.1 \
  --export-format JSON \
  --output /tmp/<your_service>-openapi.json
```

---

최종 업데이트: 2026-02-25

