---
name: security-check-sparrow
description: "Sparrow(SourceChecker) SAST 소스코드 정적분석 스킬. 내부망 SourceChecker 서버에 로컬 소스를 올려 스캔하고 위험 등급별 결함과 결과 콘솔 URL을 보고할 때 사용한다. 환경 preflight(내부망·자격증명·클라이언트) → 스캔 대상/프로젝트 키 해석 → 순차 스캔 실행 → REST 기반 결함 집계 재확인 → 보고 순서로 진행한다. 컨테이너 이미지 CVE는 security-check-cve, 컨테이너/K8s 보안 설정은 security-check-cce 담당."
triggers: [sparrow, 스페로우, SourceChecker, 소스체커, SAST, 정적분석, 소스코드 보안 점검, 시큐어코딩 점검, 보안 결함 스캔]
---

## 스킬 규칙

### ALWAYS
- **순서**: preflight → [GATE 0] → 대상·프로젝트 키 해석 → [GATE 1] → 스캔 실행 → 결과 재집계 → [GATE 2] → 보고
- 자격증명은 **환경변수에서만** 읽는다. `SPARROW_ID` / `SPARROW_PW` 값은 화면·로그·보고·커밋에 절대 출력하지 않고 **set 여부만** 확인한다
- 비밀번호는 명령행 인자로 넘기지 않는다. `umask 077` 임시파일로만 전달하고 종료 시 삭제한다
- 여러 저장소는 **반드시 순차 실행**한다 (단일 계정/클라이언트 → 동시 스캔 시 `[-140]` 충돌)
- 래퍼의 `Total Risk Sum` 값은 **신뢰하지 않고** REST `/api/1/scans/<id>/issues`로 결함 건수를 재확인한다
- 대형 저장소는 백그라운드 실행 + 로그 tail로 진행을 추적한다 (`nohup &`의 exit 0은 런처 리턴일 뿐 완료가 아니다)
- 조직별 값(서버 URL, 부모 프로젝트 키, 저장소↔프로젝트 키 매핑)은 **환경변수 또는 `.cairn/profile/`** 에서 읽는다

### NEVER
- **[GATE 0] 통과 전 스캔 실행 금지** (preflight 4항목 중 하나라도 ❌면 중단)
- **[GATE 1] 통과 전 소스 업로드 금지**
- **[GATE 2] 통과 전 결함 건수 확정 보고 금지**
- **인증 실패(403 등) 시 자동 재시도 금지** — 반복 실패는 **계정 잠금 위험**. 원인만 보고한다
- 자격증명·벤더 배포물 자동 설치/자동 export 금지 — 빠진 항목은 안내만 한다
- 프로젝트 키 추측 금지 — 못 찾으면 사용자에게 되묻는다
- 스캔 대상 저장소가 모호할 때 추측 금지
- 스캔 결과의 코드·취약점 내용을 외부로 전송 금지
- 저장소별 프로젝트 키·계정 등 조직 고유 값을 이 스킬 파일에 하드코딩 금지

## 디스패치 경계

| 요청 | 담당 |
|------|------|
| 소스코드 SAST (Sparrow/SourceChecker) | **이 스킬** |
| 컨테이너 이미지 CVE 분석·패치·재스캔 | `security-check-cve` |
| 컨테이너/Kubernetes 보안 설정 진단 (CCE) | `security-check-cce` |
| 의존성 CVE 분석, CVE 정책 최신화 | `보안전문가` 에이전트 |

## 참조 문서

| 파일 | 읽는 시점 |
|------|-----------|
| `docs/SECURITY_CHECK_SETUP.md` | **신규 환경 최초 1회** — 3개 보안 스킬 공통 환경 구성 가이드 |
| `config/sparrow.env.example` | 신규 환경 — `.cairn/profile/sparrow.env` 템플릿 |
| `references/scan-execution.md` | 3~4단계 — 클라이언트 호출 형식, `-SD` 경로 해석, 실행 옵션 |
| `references/result-reporting.md` | 5~6단계 — 위험 등급 집계, 오집계 우회, 보고 형식 |
| `references/troubleshooting.md` | 오류 발생 시 — 에러 코드별 원인과 조치 |

## 환경변수

| 변수 | 필수 | 용도 |
|------|------|------|
| `SPARROW_ID` | ✅ | SourceChecker 계정 |
| `SPARROW_PW` | ✅ | 비밀번호 (**작은따옴표로 저장** — 특수문자 mangle 시 403) |
| `SPARROW_PROJECT_KEY` | ✅ | 최상위/부모 프로젝트 키 |
| `SPARROW_URL` | | 서버 주소 (조직 기본값) |
| `SPARROW_CLIENT` | | 클라이언트 설치 경로 (기본 `~/sparrow_client`) |
| `SPARROW_LEVEL` | | 분석 레벨 (기본 `all`) |
| `SPARROW_NOUPDATE` | | `true`(기본) → `-NU`로 자동업데이트 우회 |
| `IS_FORCE_EXIT` | | `true`면 위험 1건 이상에서 exit 1 (기본 false) |

세션이 이미 떠 있으면 실행 직전 `set -a; source ~/.zshrc; set +a`로 반영한다.

조직 공통값(`SPARROW_URL`, `SPARROW_PROJECT_KEY`, CA 경로 등)은 워크스페이스 `.cairn/profile/sparrow.env` 에 두고,
자격증명 2개만 셸 환경변수로 받는다. 템플릿: `config/sparrow.env.example`

## 번들 스크립트

| 스크립트 | 용도 |
|----------|------|
| `skills/security-check-sparrow/scripts/preflight.sh` | 환경 4항목 점검 (✅/❌, 자격증명 값 미출력). exit 0=통과 |
| `skills/security-check-sparrow/scripts/resolve_subproject.sh` | 부모 키 하위에서 저장소명 → 자식 프로젝트 키 해석 |
| `skills/security-check-sparrow/scripts/run_sparrow.sh` | 스캔 실행 래퍼. `--dry-run` 지원 |
| `skills/security-check-sparrow/scripts/sparrow-env.sh` | 공통 환경 해석 (source 전용, 단독 실행 안 함) |

세 스크립트 모두 개인 경로·조직 고유값을 코드에 두지 않는다. 해석 우선순위는 **환경변수 > `.cairn/profile/sparrow.env` > 관례 기본값**이다.

## 실행 절차

1. **Preflight** — 환경 4항목을 점검한다. **자격증명 값은 출력하지 않는다(set 여부만).**

```bash
bash skills/security-check-sparrow/scripts/preflight.sh
```

exit 0이면 통과, 1이면 미충족 항목이 있으므로 스캔하지 않는다.

#### [GATE 0] 환경 준비 완료
이 GATE를 통과해야 스캔 단계로 진행한다.
- [ ] 내부망 도달 ✅
- [ ] `SPARROW_ID` / `SPARROW_PW` / `SPARROW_PROJECT_KEY` 모두 set ✅ (값 미출력)
- [ ] `sparrow-client.sh` 존재 ✅
- [ ] 실행 중인 다른 Sparrow 스캔 없음 확인

WARN 처리:
- ❌ 항목 존재 → **스캔하지 않고** `docs/SECURITY_CHECK_SETUP.md` 의 해당 조치를 안내하고 중단
- 다른 스캔 진행 중 → 완료 대기 후 순차 실행 (동시 실행 금지)

2. **스캔 대상 결정** — 사용자가 지정한 저장소, 또는 "이 프로젝트" = 현재 git repo 루트. 중첩 repo가 여럿이고 모호하면 **추측하지 말고 되묻는다**. 멀티모듈은 repo 루트만 넘기면 `*/src`가 자동 수집된다.

3. **자식 프로젝트 키 해석** — `SPARROW_PROJECT_KEY`(부모) 하위에서 저장소명과 일치하는 자식 키를 찾는다. `.cairn/profile/`에 저장소↔키 매핑이 있으면 우선 사용한다. 조회는 `scripts/resolve_subproject.sh <저장소명>` 을 쓴다(REST `/api/1/login` force + `/api/1/projects`). 종료코드 3이면 못 찾은 것이므로 **추측하지 말고** 사용자에게 키를 되묻는다. → `references/scan-execution.md`

#### [GATE 1] 스캔 대상·키 확정 (소스 업로드 직전)
이 GATE를 통과해야 소스를 서버로 올린다.
- [ ] 스캔 대상 저장소 경로와 실제 `-SD` 경로를 사용자에게 제시하고 동의받음
- [ ] 사용할 자식 프로젝트 키 확정 (추측값 아님)
- [ ] 스캔 대상에 자격증명·시크릿 파일이 포함되지 않음 확인
- [ ] 다중 저장소 요청 시 **순차 실행 순서** 확정

WARN 처리:
- 프로젝트 키 미확인 → 중단하고 사용자에게 질문 (임의 생성·추측 금지)
- 대상이 대형 저장소 → 백그라운드 실행 + 로그 추적 방식으로 합의

4. **스캔 실행** — `scripts/run_sparrow.sh <대상DIR> <자식키>` 로 실행한다(비밀번호는 `umask 077` 임시파일로만 전달). 먼저 `--dry-run` 으로 `-SD` 경로와 명령을 확인한다. 대형 저장소는 백그라운드 + 로그 tail. → `references/scan-execution.md`

5. **결과 재집계** — 래퍼 출력의 `Total Risk Sum`은 체커명에 `.`이 포함되면 0으로 오집계된다. 반드시 REST `/api/1/scans/<id>/issues`로 실제 결함 건수를 확인한다. → `references/result-reporting.md`

#### [GATE 2] 결과 확정
이 GATE를 통과해야 결함 건수를 확정 보고한다.
- [ ] 스캔 프로세스가 실제 종료됨 확인 (`ps` + 로그 tail — 런처 exit 0을 완료로 보지 않음)
- [ ] REST 기준 결함 건수로 재확인 완료 (래퍼 집계값 단독 사용 금지)
- [ ] 보고서에 자격증명 노출 0건
- [ ] 실패·중단된 대상이 있으면 그대로 표기

WARN 처리:
- 인증/권한 오류 → 재시도하지 않고 원인만 보고 (계정 잠금 위험)
- 일부 대상만 성공 → 성공/실패를 분리해 보고하고 "전체 통과"로 쓰지 않는다

6. **보고** — 위험 등급별 결함 표, 총계, 결과 콘솔 URL(`/scans/<id>/info`, `/scans/<id>/issues`)을 제시한다. → `references/result-reporting.md`

## 완료 조건 (DONE WHEN)
- [ ] [GATE] GATE 0 통과 — preflight 4항목 ✅
- [ ] [GATE] GATE 1 통과 — 대상·프로젝트 키 사용자 확정
- [ ] [GATE] GATE 2 통과 — REST 재집계로 결함 건수 확정
- [ ] [MANUAL] 위험 등급별 결함 표와 결과 콘솔 URL 보고 완료
- [ ] [MANUAL] 다중 저장소 요청 시 전부 순차 실행되었고 누락 0건
- [ ] [MANUAL] 자격증명 값이 출력·로그·보고에 포함되지 않음 확인
- [ ] [MANUAL] 인증 실패 시 자동 재시도 0회
