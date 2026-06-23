# 인시던트 관리 시스템 description 표준 양식 (8섹션 ADF)

인시던트 관리 시스템 표준 양식. 조직의 incident management 도구에 맞게 조정하여 사용한다.

## 8섹션 구조

| 순서 | 섹션 | 작성 주체 | 필수 |
|------|------|---------|------|
| 가 | 타임 테이블 | 상황반장 (관제팀) | O |
| 나 | 인시던트 내부 공지 내용(해소) | 상황반장 | O |
| 다 | (선택) 발생 이벤트 정보 | 신고자 / 외부 운영팀 | △ |
| 라 | 참고/첨부 | 상황반장 | O (상황창 링크 등) |
| 마 | **대응내용** | 복구반장 | **O** (본 스킬 append) |
| 바 | **원인분석내용** | 복구반장 | **O** (본 스킬 append) |
| 사 | **향후대책** | 복구반장 | **O** (본 스킬 append) |
| 아 | **비고** | 복구반장 | **O** (본 스킬 append) |

## ADF 작성 패턴

### 헤딩 (각 섹션 시작)

각 섹션은 굵은 paragraph로 시작:

```json
{
  "type": "paragraph",
  "content": [
    {"type": "text", "text": "마. 대응내용", "marks": [{"type": "strong"}]}
  ]
}
```

### 내용 (멀티라인)

```json
{
  "type": "paragraph",
  "content": [
    {"type": "text", "text": "- 첫 번째 항목"},
    {"type": "hardBreak"},
    {"type": "text", "text": "- 두 번째 항목"}
  ]
}
```

### 빈 줄 (섹션 구분)

```json
{"type": "paragraph"}
```

## 마/바/사/아 4섹션 내용 가이드

### 마. 대응내용

**원칙**: 무엇을 했는지 (시각 + 액션) 짧게. 누가 했는지 명시.

```
- {임시 회피 액션} (시각 / 책임자)
- {시스템 정상화 확인} (시각)
```

예:
```
- (예: 특정 모니터링 DB에서 장애 row 격리로 임시 회피)
- (예: 적재 재개 + 데이터 정상 처리 확인, 시스템 정상화(HH:MM))
```

### 바. 원인분석내용

**원칙**: 메커니즘 + 증빙. bullet 3~6개. 코드 라인 번호/파일 경로 포함.

```
- {시스템/컴포넌트} 의 {대상 기능} 에서 {정책 불일치/버그/외부 의존 실패}
- 메커니즘: {파일 line 번호} 가 {처리 A} 만 수행, {처리 B} 누락
- 증빙: PG 로그 / Jira 캐시 / 시계열 분석 / 로컬 재현 검증
- (재현 시) 로컬 환경 + 패턴 + 동일 에러 메시지 100% 재현 검증
```

### 사. 향후대책

**원칙**: 코드 변경 + 배포 일정. 추상 표현 금지.

```
1) {개선 항목 1} — {구체 코드 변경} (기한 ~YYYY.MM.DD)
2) {개선 항목 2} — {구체 변경} (기한 ~YYYY.MM.DD)
- 주관: {담당팀}
- 관련 운영개선 태스크: {${JIRA_PROJECT_KEY}-NNN}
```

### 아. 비고

**원칙**: 보고서 링크, 영향 범위, VOC, 기타 메모.

```
- 상세 장애보고서: {Confluence URL}
- 영향 범위: {채널/서비스 한정 여부}
- VOC: {건수}, {고객 영향 여부}
```

## ADF append 예시 (Python)

```python
def heading(text):
    return {
        "type": "paragraph",
        "content": [{"type": "text", "text": text, "marks": [{"type": "strong"}]}]
    }

def lines(*items):
    content = []
    for i, item in enumerate(items):
        if i > 0:
            content.append({"type": "hardBreak"})
        content.append({"type": "text", "text": item})
    return {"type": "paragraph", "content": content}

def blank():
    return {"type": "paragraph"}

# 기존 description (가/나/다/라) 끝에 append
append_blocks = [
    blank(),
    heading("마. 대응내용"),
    lines("- ...", "- ..."),
    blank(),
    heading("바. 원인분석내용"),
    lines("- ...", "- ...", "- ..."),
    blank(),
    heading("사. 향후대책"),
    lines("1) ...", "2) ...", "- 주관: ...", "- 관련 운영개선 태스크: ..."),
    blank(),
    heading("아. 비고"),
    lines("- 상세 보고서: ...", "- 영향 범위: ...", "- VOC: ..."),
]

desc['content'].extend(append_blocks)
```

## Jira REST API 업데이트

```bash
CREDS_FILE="${JIRA_CREDENTIALS_FILE:-~/.jira-credentials.json}"
EMAIL=$(jq -r '.email' "$CREDS_FILE")
TOKEN=$(jq -r '.apiToken' "$CREDS_FILE")
BASE=$(jq -r '.baseUrl' "$CREDS_FILE")
AUTH=$(echo -n "$EMAIL:$TOKEN" | base64)

# 1. 현재 description 가져오기 (ADF JSON 그대로)
curl -s -H "Authorization: Basic $AUTH" \
  "${BASE}/rest/api/3/issue/INCIDENT-{N}?fields=description" \
  | jq '.fields.description' > /tmp/incident_desc.json

# 2. Python으로 마/바/사/아 append (위 예시)

# 3. PUT
payload='{"fields": {"description": '$(cat /tmp/incident_desc.json)'}}'
echo "$payload" > /tmp/incident_payload.json

curl -s -X PUT \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d @/tmp/incident_payload.json \
  "${BASE}/rest/api/3/issue/INCIDENT-{N}"
# HTTP 204 = 성공
```

## 운영팀 기록 우선

가/나/다/라 4섹션은 **상황반장(관제팀)이 작성한 내용을 절대 수정하지 않는다**. 본 스킬은 **끝에 마/바/사/아 4섹션을 append**만 수행. 운영팀 권위 있는 기록 보존.

이미 마/바/사/아 중 일부가 작성되어 있으면 사용자 확인 후 update 또는 skip.

## 참고 이슈

(사용 환경의 대표 인시던트 이슈로 교체)

| 이슈 | summary | 비고 |
|------|---------|------|
| INCIDENT-N | [YYMMDD\|장애등급] 장애 내용 요약 | 표준 가/나/다/라 구조 사례 |
| INCIDENT-N | [YYMMDD\|이상징후] 이상징후 사례 요약 | 이상징후 사례 |
| INCIDENT-N | [YYMMDD\|관리장애] 마/바/사/아 append 적용 사례 | 복구반 작성 append 사례 |
