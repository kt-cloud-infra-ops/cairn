---
tags:
  - type/automation
  - domain/jira/api
  - audience/claude
---

> 상위: [자동화 패턴](README.md)

# 009: Jira REST API 자동화 패턴

## 개요

Jira MCP 도구의 한계를 REST API 직접 호출로 우회하는 자동화 패턴입니다.

**발견일**: 2026-02-02
**우선순위**: HIGH
**상태**: Active

---

## 문제 상황

Jira MCP는 다음 기능을 지원하지 않음:
- 이슈 필드 업데이트 (duedate, description, 커스텀 필드)
- 상태 전환 (transitions)
- 에픽 링크 설정
- 이슈 삭제

---

## 해결 패턴

### 1. 인증 정보 로드 + preflight

환경변수 우선, 이후 파일 fallback:

```python
import json
import os
from pathlib import Path

def load_jira_auth():
    env = os.environ
    if env.get('ATLASSIAN_BASE_URL') and env.get('ATLASSIAN_EMAIL') and env.get('ATLASSIAN_API_TOKEN'):
        return {
            'base_url': env['ATLASSIAN_BASE_URL'],
            'email': env['ATLASSIAN_EMAIL'],
            'token': env['ATLASSIAN_API_TOKEN'],
            'source': 'env:ATLASSIAN_*',
        }

    if env.get('JIRA_EMAIL') and env.get('JIRA_API_TOKEN'):
        return {
            'base_url': env.get('JIRA_BASE_URL', 'https://yourcompany.atlassian.net'),  # Set JIRA_BASE_URL env var
            'email': env['JIRA_EMAIL'],
            'token': env['JIRA_API_TOKEN'],
            'source': 'env:JIRA_*',
        }

    cred_path = Path(os.environ.get('JIRA_CREDENTIALS_FILE', str(Path.home() / '.jira-credentials.json')))
    if cred_path.exists():
        config = json.loads(cred_path.read_text())
        return {
            'base_url': config['baseUrl'],
            'email': config['email'],
            'token': config['apiToken'],
            'source': str(cred_path),
        }

    raise RuntimeError(
        "Jira 인증 정보 없음. 환경변수(JIRA_EMAIL/JIRA_API_TOKEN) 또는 "
        f"{cred_path} 를 설정하세요. (MCP 설정 의존은 제거됨)"
    )
```

### 2. REST API 호출

```python
import requests

class JiraRestAPI:
    def __init__(self):
        auth = load_jira_auth()
        self.base_url = auth['base_url']
        self.auth = (auth['email'], auth['token'])
        self.auth_source = auth['source']
        self.headers = {'Content-Type': 'application/json'}

    def auth_check(self):
        response = requests.get(
            f"{self.base_url}/rest/api/3/myself",
            auth=self.auth,
            headers=self.headers,
        )
        if response.status_code == 401:
            raise RuntimeError(
                f"Jira authentication failed: {self.auth_source}. "
                "Refresh token before reading issues."
            )
        response.raise_for_status()
        return response.json()

    def update_issue(self, issue_key: str, fields: dict):
        """이슈 필드 업데이트"""
        url = f"{self.base_url}/rest/api/3/issue/{issue_key}"
        response = requests.put(
            url,
            auth=self.auth,
            headers=self.headers,
            json={'fields': fields}
        )
        response.raise_for_status()
        return response

    def transition_issue(self, issue_key: str, transition_id: str):
        """이슈 상태 전환"""
        url = f"{self.base_url}/rest/api/3/issue/{issue_key}/transitions"
        response = requests.post(
            url,
            auth=self.auth,
            headers=self.headers,
            json={'transition': {'id': transition_id}}
        )
        response.raise_for_status()
        return response

    def get_transitions(self, issue_key: str):
        """가능한 상태 전환 목록 조회"""
        url = f"{self.base_url}/rest/api/3/issue/{issue_key}/transitions"
        response = requests.get(url, auth=self.auth)
        response.raise_for_status()
        return response.json()['transitions']
```

이슈 조회/수정 전에 `auth_check()`를 먼저 실행한다.
특히 `Issue does not exist or you do not have permission to see it.` 응답이 나와도 `/myself`가 `401`이면 권한 문제가 아니라 인증 실패다.

---

## 사용 예시

### 기한 설정

```python
jira = JiraRestAPI()
jira.update_issue('PROJ-NNN', {
    'duedate': '2026-02-09'
})
```

### 에픽 링크 설정

```python
jira.update_issue('PROJ-NNN', {
    'customfield_10014': 'PROJ-NNN'  # Epic Link 필드
})
```

### 상태 전환 (In Progress)

```python
# 1. 가능한 전환 확인
transitions = jira.get_transitions('PROJ-NNN')
for t in transitions:
    print(f"{t['id']}: {t['name']}")

# 2. 전환 실행
jira.transition_issue('PROJ-NNN', '4')  # In Progress
```

### ADF 형식 체크박스로 description 업데이트

```python
description_adf = {
    "type": "doc",
    "version": 1,
    "content": [
        {
            "type": "taskList",
            "attrs": {"localId": "tasks"},
            "content": [
                {
                    "type": "taskItem",
                    "attrs": {"localId": "t1", "state": "TODO"},
                    "content": [{"type": "text", "text": "첫 번째 할 일"}]
                },
                {
                    "type": "taskItem",
                    "attrs": {"localId": "t2", "state": "TODO"},
                    "content": [{"type": "text", "text": "두 번째 할 일"}]
                }
            ]
        }
    ]
}

jira.update_issue('PROJ-NNN', {
    'description': description_adf
})
```

### A.C. 체크박스 완료 처리

체크박스 상태값:
- `state: "TODO"` → 미완료 (빈 체크박스)
- `state: "DONE"` → 완료 (체크된 체크박스)

```python
import uuid

def make_done_checklist(items: list[str]):
    """모든 항목이 완료된 체크리스트 ADF 생성"""
    return {
        "type": "doc",
        "version": 1,
        "content": [{
            "type": "taskList",
            "attrs": {"localId": str(uuid.uuid4())},
            "content": [{
                "type": "taskItem",
                "attrs": {"localId": str(uuid.uuid4()), "state": "DONE"},
                "content": [{"type": "text", "text": item}]
            } for item in items]
        }]
    }

# A.C. 필드 완료 처리
jira.update_issue('PROJ-NNN', {
    'customfield_14516': make_done_checklist([
        'DB만 삭제 프로세스 확정',
        '이력 관리 방식 확정',
        '이해관계자 리뷰 완료'
    ])
})
```

---

## Done 태스크 A.C. 일괄 완료 처리

Done 상태인 태스크들의 A.C. 체크박스를 일괄 완료 처리:

```python
def bulk_complete_ac(issue_keys: list[str]):
    """Done 태스크들의 A.C.를 일괄 완료 처리"""
    jira = JiraRestAPI()

    for key in issue_keys:
        # 1. 이슈 조회하여 A.C. 항목 추출
        url = f"{jira.base_url}/rest/api/3/issue/{key}"
        response = requests.get(url, auth=jira.auth,
                                params={'fields': 'customfield_14516'})
        ac = response.json()['fields'].get('customfield_14516')

        if not ac:
            continue

        # 2. 기존 항목 텍스트 추출
        items = []
        for content in ac.get('content', []):
            if content.get('type') == 'taskList':
                for item in content.get('content', []):
                    if item.get('type') == 'taskItem':
                        for c in item.get('content', []):
                            if c.get('type') == 'text':
                                items.append(c.get('text', ''))

        # 3. 모두 DONE 상태로 업데이트
        jira.update_issue(key, {
            'customfield_14516': make_done_checklist(items)
        })
        print(f"✓ {key}: A.C. 완료 처리됨")
```

---

## 월별 이슈 복사 패턴

매월 반복되는 기성 이슈 등을 자동 복사:

```python
def copy_monthly_issue(source_key: str, new_month: str):
    """월별 반복 이슈 복사 (REST API 직접 호출, MCP 의존 없음)"""
    jira = JiraRestAPI()

    # 1. 원본 이슈 조회
    source = jira.get_issue(source_key)

    # 2. 새 이슈 생성 (필수 인자 reporter/assignee account_id, start/due date,
    #    description, acceptance_criteria 등은 create_task 시그니처 참조)
    new_issue = jira.create_task(
        project_key=source['fields']['project']['key'],
        issue_type_name=source['fields']['issuetype']['name'],
        summary=source['fields']['summary'].replace('12월', new_month),
        assignee_account_id=source['fields']['assignee']['accountId'],
        # ... 나머지 필수 인자
    )

    # 3. 추가 필드 업데이트

    # 에픽 링크
    if source['fields'].get('customfield_10014'):
        jira.update_issue(new_issue['key'], {
            'customfield_10014': source['fields']['customfield_10014']
        })

    # 기한 (원본 + 1달)
    # ... 날짜 계산 로직

    # 체크박스 초기화
    # ... ADF 생성 로직

    return new_issue['key']
```

---

## Jira 참고 정보 (환경별 설정 필요)

### 프로젝트
- `${JIRA_PROJECT_KEY}`: 팀 프로젝트 키

### 상태 전환 ID (프로젝트별 실제 값 확인 필요)
| ID | 상태 |
|----|------|
| 2 | Backlog(백로그) |
| 3 | To Do(할일) |
| 4 | In Progress(진행 중) |
| 5 | In Review(검토 중) |
| 6 | Done(완료) |
| 7 | Cancel(취소) |

### 주요 커스텀 필드
| 필드 ID | 이름 |
|---------|------|
| customfield_10014 | Epic Link |
| customfield_10302 | Acceptance Criteria |
| customfield_14516 | A.C.(Acceptance Criteria) |

### JQL 검색 팁

**주의**: `parent = EPIC-KEY` JQL 검색이 불안정할 수 있음

```python
# 비권장: JQL parent 검색
jql = 'parent = PROJ-NNN'  # 결과 없을 수 있음

# 권장: 개별 이슈 직접 조회
for i in range(227, 250):
    key = f"PROJ-{i}"
    response = requests.get(f"{base_url}/rest/api/3/issue/{key}", ...)
    if response.status_code == 200:
        # 처리
```

---

## 관련 문서

- MCP 도구 가이드 — 팀 knowledge base 참조
- [Jira REST API 공식 문서](https://developer.atlassian.com/cloud/jira/platform/rest/v3/)
