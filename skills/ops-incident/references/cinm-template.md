# CINM 인시던트 description 표준 양식 (8섹션 ADF)

KT cloud CINM 프로젝트(인시던트 관리) 표준. 다른 CINM 종료 이슈(CINM-22, CINM-138) 패턴 + 본 사고(CINM-149) 보완.

## 8섹션 구조

| 순서 | 섹션 | 작성 주체 | 필수 |
|------|------|---------|------|
| 가 | 타임 테이블 | 상황반장(Cloud통합관제팀) | O |
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

예 (CINM-149):
```
- Zabbix DB에서 깨진 row(eventid=713802965) 삭제로 임시 회피
- COPY 적재 재개 + x01_if_event_data 정상 적재 확인, 시스템 정상화(17:05)
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
- 관련 운영개선 태스크: {TECHIOPS26-N 또는 devops 프로젝트 키}
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
EMAIL=$(jq -r '.email' ~/.jira-credentials.json)
TOKEN=$(jq -r '.apiToken' ~/.jira-credentials.json)
BASE=$(jq -r '.baseUrl' ~/.jira-credentials.json)
AUTH=$(echo -n "$EMAIL:$TOKEN" | base64)

# 1. 현재 description 가져오기 (ADF JSON 그대로)
curl -s -H "Authorization: Basic $AUTH" \
  "${BASE}/rest/api/3/issue/CINM-{N}?fields=description" \
  | jq '.fields.description' > /tmp/cinm_desc.json

# 2. Python으로 마/바/사/아 append (위 예시)

# 3. PUT
payload='{"fields": {"description": '$(cat /tmp/cinm_desc.json)'}}'
echo "$payload" > /tmp/cinm_payload.json

curl -s -X PUT \
  -H "Authorization: Basic $AUTH" \
  -H "Content-Type: application/json" \
  -d @/tmp/cinm_payload.json \
  "${BASE}/rest/api/3/issue/CINM-{N}"
# HTTP 204 = 성공
```

## 운영팀 기록 우선

가/나/다/라 4섹션은 **상황반장(Cloud통합관제팀)이 작성한 내용을 절대 수정하지 않는다**. 본 스킬은 **끝에 마/바/사/아 4섹션을 append**만 수행. 운영팀 권위 있는 기록 보존.

이미 마/바/사/아 중 일부가 작성되어 있으면 사용자 확인 후 update 또는 skip.

## 참고 이슈

| 이슈 | summary | 비고 |
|------|---------|------|
| CINM-22 | [260301\|장애3등급]C-HUB 이용 고객 일시적 서비스 불가 | 표준 가/나/다/라 구조 |
| CINM-138 | [260514\|이상징후]aih012.nexr.com 외 다수 Dedication 장비 접속 불가 해소 | 이상징후 사례 |
| CINM-149 | [260521\|관리장애] m1-jpt-prd-mon-d01에서 Zabbix 이벤트 DB문제로 유피테르 이벤트 삽입 불가 현상 종료 | 본 사고, 마/바/사/아 append 적용 사례 |
