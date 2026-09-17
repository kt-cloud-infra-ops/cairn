# CCE 기준선 수집·파싱

## 기준 페이지 해석

기준 문서 URL은 **조직마다 다르므로 이 파일에 하드코딩하지 않는다.** 아래 순서로 해석한다.

| 순위 | 소스 | 비고 |
|------|------|------|
| PRIMARY | 사용자가 이번 실행에서 직접 지정한 URL | 일회성 override |
| SECONDARY | 워크스페이스 `.cairn/profile/cce.env` 의 `CCE_GUIDE_URL` / `CCE_ITEMS_URL` | 팀 공통값. 템플릿: `config/cce.env.example` |
| FORBIDDEN | 이전 run의 캐시·내장 사본을 "현재 기준"으로 사용 | 금지 — 기준 문서는 계속 갱신된다 |

두 URL을 모두 해석하지 못하면 진단을 **중단**한다. 임의의 페이지를 추측해 읽지 않는다.

## 수집 시 기록 항목

- 페이지 ID, 제목, 버전 번호, 수집 시각(ISO8601)
- 본문 콘텐츠 해시
- 첨부 링크 목록, 코드블록 스크립트 존재 여부

## 파싱 산출물 (`evidence/confluence-baseline.json`)

```json
{
  "schemaVersion": 1,
  "fetchedAt": "2026-09-17T14:25:00+09:00",
  "guide":  {"pageId": "1925678414", "title": "...", "version": 8, "contentHash": "..."},
  "items":  {"pageId": "1925088343", "title": "...", "version": 5, "contentHash": "..."},
  "applicableItems": [{"code": "U-05", "name": "...", "risk": "High"}],
  "naItems": [{"code": "U-01", "reason": "컨테이너 미해당"}],
  "commands": ["..."],
  "scriptCandidates": [{"type": "attachment|codeblock", "name": "script_1.sh", "url": "", "hash": ""}],
  "warnings": []
}
```

## 항목 코드 체계 (설계 시점 기준)

- 적용 범위: **U-05 ~ U-36**
- 컨테이너 N/A·제거 항목: **U-01, U-02, U-03, U-04, U-18, U-35**

> 위 목록은 설계 시점의 스냅샷이다. **하드코딩된 영구 기준이 아니다.** 매 실행에서 파싱한 값이 항상 우선하며, 파싱 결과와 이 문서가 다르면 파싱 결과를 따르고 차이를 리포트에 기록한다.

## 점검 항목군 (현재 페이지 기준)

- 패스워드·계정 파일 보호
- root 경로 및 홈 디렉터리 권한
- 파일 소유자·권한
- SUID / SGID / sticky bit / world-writable 파일
- 시작 파일 및 환경 파일
- cron 파일
- 불필요 네트워크 서비스: Finger, FTP, r-services, NFS, RPC, NIS, TFTP, Talk, Sendmail, DNS
- 로그 검토 통제
- 컨테이너·Kubernetes 통제: root 실행, privilege escalation, capabilities, privileged 모드, host namespace, hostPath, seccomp, read-only root filesystem, 리소스 제한, 시크릿 취급

## 파싱 실패 처리

| 상황 | 처리 |
|------|------|
| 페이지 조회 실패 | 중단 또는 기준선 `blocked`. 과거 사본 사용 금지 |
| 항목표 미발견 | 해당 항목군 `Blocked`, 매니페스트 점검만 진행 |
| 명령 블록 미발견 | 런타임에 맞춰 명령을 재구성하되 재구성 사실을 기록 |
| 첨부 스크립트 미확보 | 스크립트 기반 항목 `Blocked`, 누락 사실 리포트 명시 |
