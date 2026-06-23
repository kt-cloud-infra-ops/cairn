---
tags:
  - type/lesson
  - audience/team
  - domain/messaging
aliases: []
---

> 상위: [lessons](../../README.md) · [common](../README.md)

# Slack Payload curl 검증 SOP

## 적용 시점

- mb / message_bridge 발송이 의심스러울 때
- Slack Block Kit Builder UI 가 invalid 표시하는데 진짜인지 확실하지 않을 때
- payload 자체 정합성을 빠르게 확인할 때

## 핵심 원칙

**Block Kit Builder UI 의 invalid ≠ 실제 발송 invalid.**
진짜 검증은 chat.postMessage API 직접 호출이다.

| 검증 도구 | 신뢰성 | 비고 |
|----------|:---:|------|
| **chat.postMessage API curl** | ★★★ | 진짜 Slack 검증. 본 SOP 의 핵심 |
| Block Kit Builder web UI | ★ | 간단한 section/header 디자인용. `text` outer / `rich_text` 거부 케이스 다수 — 실제 발송과 무관 |

### Block Kit Builder UI 한정 거부 사례

- root level `text` 필드 → "invalid additional property: text"
- `rich_text` block 편집 모드 — display 만 가능, 입력으로는 어색
- nested rich_text_list / rich_text_section 일부 케이스

→ 실제 chat.postMessage API 는 위 모두 정상 처리. spec 상 `text` 는 fallback notification 으로 권장 필드.

## 검증 절차 (3단계)

### 1. 토큰 + 사용자 ID 확보

```bash
# Bot token 위치 (luppiter)
# workspace/message_bridge/config/message_bridge/application-{env}.properties
# slack.token=xoxb-...
TOKEN='xoxb-...'

# email → user ID
EMAIL='target@kt.com'
curl -s -G "https://slack.com/api/users.lookupByEmail" \
  -H "Authorization: Bearer $TOKEN" \
  --data-urlencode "email=$EMAIL" | jq '{ok, error, user_id: .user.id, name: .user.name}'
```

기대: `{"ok":true, "user_id":"U..."}`

### 2. payload JSON 파일 준비

mb-mock 로그의 raw 페이로드 그대로 + `channel` 필드만 추가:

```json
{
  "channel": "U...USER_ID...",
  "blocks": [...],
  "text": "fallback text"
}
```

### 3. chat.postMessage 직접 호출

```bash
curl -sS -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-binary @payload.json | jq '{ok, error, warning, response_metadata, scopes_warning, deprecation, ts}'
```

판정:
- `{"ok":true, "warning":null, ...}` → **payload 정상.** 실 발송 실패는 mb 코드/환경 문제
- `{"ok":false, "error":"invalid_blocks"|"missing_scope"|"channel_not_found"|...}` → 메시지가 단서

## 흔한 응답 케이스

| 응답 | 의미 | 다음 조치 |
|------|------|---------|
| `ok:true, warning:null` | payload 100% valid | mb 코드/환경 측 점검 |
| `error:"invalid_auth"` / `not_authed` | token 만료/잘못 | env properties 토큰 확인 |
| `error:"missing_scope"` | bot scope 부족 | Slack App OAuth scope 추가 (chat:write 등) |
| `error:"channel_not_found"` | 채널 ID 오타 / 봇 미초대 | 채널에 봇 invite |
| `error:"invalid_blocks"` | block 형식 오류 | response_metadata 의 messages 확인 |

## 채널별 지원 차이 (참고)

| 호출 방식 | rich_text block | text outer fallback |
|---------|:---:|:---:|
| **chat.postMessage** (Bot token) | **지원** | **권장** |
| **Incoming Webhook** (`hooks.slack.com/services/...`) | **미지원** | 지원 |

→ webhook 발송이 필요하면 rich_text 를 section + mrkdwn 으로 평탄화.

## 실제 적용 사례 (TECHIOPS26-543 세션, 2026-04-28)

- mb-mock log raw 페이로드를 Block Kit Builder UI 에 넣으니 `invalid additional property: text` 에러
- chat.postMessage API 로 직접 발송 → `ok:true, warning:null, deprecation:null, scopes_warning:null` 깨끗
- **결론**: payload 100% valid. stg 발송 실패는 mb 코드 측 (mb-mock 의 unmatched endpoint `/slack/sendDirect/blockkit` 가 단서)

## 안티패턴

- ❌ Block Kit Builder UI 에러만 보고 payload 가 invalid 라고 결론
- ❌ token 평문을 코드 또는 git 에 노출
- ❌ webhook URL 로 rich_text 페이로드 보내고 webhook 측 응답을 chat.postMessage 응답처럼 처리

## 관련 문서

- [apidog-token-security-playbook.md](apidog-token-security-playbook.md) — 토큰 노출/회수 절차
