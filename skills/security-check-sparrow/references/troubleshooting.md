# 트러블슈팅

## 인증·권한

| 증상 | 원인 | 조치 |
|------|------|------|
| `403 null [-87]` | 인증 실패 | ① `~/.zshrc`의 `SPARROW_PW`가 **작은따옴표**인지 확인 (특수문자 mangle → 틀린 PW) ② 계정/비번 ③ 권한·IP. **자동 재시도 금지 — 계정 잠금 위험** |
| `/api/1/checkers/groups 403` | 관리 API 권한 없음 | 로그인(`/api/1/login`)이 200이면 **자격증명은 정상**이고 스캔에는 영향 없다. 프로젝트 목록 조회만 REST `/api/1/projects`로 우회 |
| `[-26] Unable to find the project. Or no permission` | 해당 계정에 그 프로젝트 키 권한 없음 | 콘솔에서 권한 부여 요청. 키를 바꿔가며 재시도하지 않는다 |

> 인증 계열 오류는 **원인 보고까지만** 한다. 자동 재시도·자동 키 탐색은 계정 잠금으로 이어진다.

## 실행

| 증상 | 원인 | 조치 |
|------|------|------|
| `sparrow-client 가 없습니다` | 클라이언트 미설치 또는 경로 불일치 | `~/sparrow_client` 확인, 다른 경로면 `SPARROW_CLIENT=<경로>` (env 또는 `.cairn/profile/sparrow.env`) |
| `SPARROW_URL 이 없습니다` | 조직 서버 주소 미설정 | `.cairn/profile/sparrow.env` 생성 (`config/sparrow.env.example` 복사) 또는 `export SPARROW_URL=...` |
| TLS 인증서 오류 | 사내 사설 CA | `SPARROW_CA=<CA 경로>` 설정. 최후 수단으로만 `SPARROW_INSECURE=true` |
| 스캔이 즉시 스킵됨 | 자동업데이트 실패 (로컬 macOS ↔ 서버 linux 엔진 404) | `SPARROW_NOUPDATE=true`(기본, `-NU`) 사용 + 클라이언트 경로의 `err_update` 잔재 제거 |
| `[-140]` 충돌 | 동시 스캔 | 단일 계정/클라이언트 제약. **순차 실행**으로 전환 |
| 스캔 경로 없음 | `-SD` 해석 오류 | `scan-execution.md` 2절 규칙으로 경로 재해석, 각 경로 존재 확인 |
| 백그라운드 exit 0인데 결과 없음 | 런처 리턴을 완료로 오인 | `ps` + 로그 tail로 실제 종료 확인 |

## 집계

| 증상 | 원인 | 조치 |
|------|------|------|
| `Total Risk Sum: 0` 인데 콘솔엔 결함 존재 | 체커명의 `.`(예: `.KOTLIN`) 때문에 집계 정규식 미매칭 | 번들 래퍼는 수정됨. 다른 래퍼를 쓴다면 정규식 확인 + REST `/api/1/scans/<id>/issues` 재확인 (`result-reporting.md` 1절) |

## 환경 미구성

preflight에서 ❌가 나오면 스캔하지 않고 `docs/SECURITY_CHECK_SETUP.md` 의 Sparrow 섹션을 안내한다. 자동 설치·자동 export는 하지 않는다.
