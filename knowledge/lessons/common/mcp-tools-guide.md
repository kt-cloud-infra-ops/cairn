---
tags:
  - type/guide
  - domain/jira/api
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# MCP Tools Integration Guide

## 개요

이 문서는 MCP(Model Context Protocol) 도구 사용 시 알아야 할 기능 범위, 한계, 그리고 REST API로 우회하는 방법을 정리합니다.

---

## 1. Jira MCP 도구

### 사용 가능한 기능

| 도구 | 설명 | 비고 |
|------|------|------|
| `read_jira_issue` | 이슈 상세 조회 | issueKey로 조회 |
| `create_jira_issue` | 이슈 생성 | 기본 필드만 지원 |
| `add_jira_comment` | 댓글 추가 | - |
| `search_jira_issues` | JQL로 검색 | 결과 제한 있음 |
| `list_jira_projects` | 프로젝트 목록 | - |
| `get_jira_current_user` | 현재 사용자 정보 | - |

### 지원되지 않는 기능 (REST API 필요)

| 기능 | 대안 |
|------|------|
| 이슈 필드 업데이트 (duedate, description 등) | `PUT /rest/api/3/issue/{key}` |
| 커스텀 필드 업데이트 | `PUT /rest/api/3/issue/{key}` |
| 상태 전환 | `POST /rest/api/3/issue/{key}/transitions` |
| 이슈 삭제 | `DELETE /rest/api/3/issue/{key}` |
| 에픽 링크 설정 | `PUT` + `customfield_10014` |

---

## 2. Jira REST API 직접 호출

### 인증 방식

```bash
# Basic Auth: email:api_token을 base64 인코딩
AUTH=$(echo -n 'email@example.com:API_TOKEN' | base64)
curl -H "Authorization: Basic $AUTH" ...
```

### 인증 정보 위치

`~/.claude.json` 파일의 `mcpServers.atlassian.env`:
- `ATLASSIAN_BASE_URL`: Jira URL
- `ATLASSIAN_EMAIL`: 이메일
- `ATLASSIAN_API_TOKEN`: API 토큰

### 주요 API 엔드포인트

#### 이슈 업데이트
```bash
curl -X PUT \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  "https://example.atlassian.net/rest/api/3/issue/PROJ-123" \
  -d '{
    "fields": {
      "duedate": "2026-02-09",
      "customfield_10014": "PROJ-100"
    }
  }'
```

#### 상태 전환
```bash
curl -X POST \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  "https://example.atlassian.net/rest/api/3/issue/PROJ-123/transitions" \
  -d '{
    "transition": {
      "id": "4"
    }
  }'
```

#### 전환 ID 확인
```bash
curl -H "Authorization: Basic $AUTH" \
  "https://example.atlassian.net/rest/api/3/issue/PROJ-123/transitions"
```

---

## 3. Atlassian Document Format (ADF)

Jira의 description, 댓글 등은 ADF 형식을 사용합니다.

### 체크박스 (Task List)

```json
{
  "type": "taskList",
  "attrs": {"localId": "task-list-1"},
  "content": [
    {
      "type": "taskItem",
      "attrs": {"localId": "task-1", "state": "TODO"},
      "content": [{"type": "text", "text": "할 일 항목"}]
    }
  ]
}
```

- `state`: `"TODO"` (미완료) 또는 `"DONE"` (완료)

### 프로젝트 타입별 ADF 지원 차이 (2026-02-10 확인)

| 기능 | TECHIOPS26 (팀관리형) | LUPR (회사관리형) | Confluence |
|------|:---:|:---:|:---:|
| 코멘트 taskList | O | **X** (INVALID_INPUT) | - |
| 코멘트 bulletList | O | O | - |
| 코멘트 codeBlock | O | O | - |
| ac:task-list 매크로 | - | - | O |

**LUPR 대안**: bulletList + ☐/☑ 이모지로 체크박스 표현

```json
{"type": "listItem", "content": [
  {"type": "paragraph", "content": [
    {"type": "text", "text": "☐ 체크 항목"}
  ]}
]}
```

### 기본 구조

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        {"type": "text", "text": "텍스트 내용"}
      ]
    }
  ]
}
```

### 불릿 리스트

```json
{
  "type": "bulletList",
  "content": [
    {
      "type": "listItem",
      "content": [
        {
          "type": "paragraph",
          "content": [{"type": "text", "text": "항목 1"}]
        }
      ]
    }
  ]
}
```

---

## 4. Confluence MCP 도구

### 사용 가능한 기능

| 도구 | 설명 |
|------|------|
| `read_confluence_page` | 페이지 조회 |
| `create_confluence_page` | 페이지 생성 |
| `update_confluence_page` | 페이지 수정 |
| `search_confluence_pages` | CQL로 검색 |
| `list_confluence_spaces` | 스페이스 목록 |

### Confluence 첨부파일 다운로드 (2026-02-23 확인)

첨부파일 다운로드 시 **version + modificationDate 파라미터가 필수**. 없으면 0바이트 파일 반환.

```bash
# 1단계: 첨부파일 목록 조회
curl -s -H "Authorization: Basic $AUTH" \
  "https://example.atlassian.net/wiki/rest/api/content/{pageId}/child/attachment" \
  | jq '.results[] | "\(.title) -> \(._links.download)"'

# 2단계: 다운로드 (version + modificationDate 파라미터 포함)
curl -s -L -H "Authorization: Basic $AUTH" \
  "https://example.atlassian.net/wiki/download/attachments/{pageId}/{filename}?version=1&modificationDate=1771829172542&cacheVersion=1&api=v2" \
  -o output.sql

# 주의: 파라미터 없이 다운로드하면 0바이트 반환!
```

### Confluence 단축 링크 해석 (2026-02-23 확인)

`wiki/x/xxxxx` 형식의 단축 링크를 페이지 ID로 변환하는 방법:

```bash
# auth 헤더 포함하여 리다이렉트 추적
curl -s -L -H "Authorization: Basic $AUTH" \
  "https://example.atlassian.net/wiki/x/75tzZw" \
  -o /dev/null -w "Final URL: %{url_effective}"

# 결과: https://example.atlassian.net/wiki/spaces/SREP/pages/1735629807/26+3+배포
# → 페이지 ID: 1735629807
```

- WebFetch 도구는 인증이 필요한 Confluence URL에 실패함 (로그인 리다이렉트)
- 반드시 REST API + Basic Auth로 접근해야 함

---

## 5. 회사 정책으로 불가능한 MCP

### OneDrive

| 시도 | 결과 |
|------|------|
| Azure AD 앱 등록 | 권한 없음 |
| Device Code Flow (공개 앱 ID) | IT 정책 차단 |

**결론**: IT 부서 협조 없이는 API 접근 불가

### Slack

| 시도 | 결과 |
|------|------|
| Bot Token (xoxb) | 앱 등록 + 관리자 승인 필요 |
| User OAuth (xoxp) | 앱 등록 + 관리자 승인 필요 |
| Stealth Mode (xoxc/xoxd) | 세션 토큰이라 매번 재추출 필요 |

**결론**: 실용적인 방법 없음

---

## 6. MCP vs REST API 선택 기준

```
MCP 도구 사용:
- 단순 조회, 생성, 검색
- 빠른 프로토타이핑

REST API 직접 호출:
- 필드 업데이트 필요 시
- 커스텀 필드 작업
- 상태 전환
- MCP에서 지원하지 않는 기능
```

---

## 관련 문서

- [Jira REST API 자동화 패턴](../../../skills/jira-rest-ops/references/automation-pattern.md)
- [Jira REST API 공식 문서](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
- [ADF 공식 문서](https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/)
