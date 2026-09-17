# Security Check 스킬 환경 구성 가이드

`security-check-cve` / `security-check-cce` / `security-check-sparrow` 세 스킬을 **처음 쓰는 환경**에서 필요한 설정을 모았다.
스킬은 도구를 자동 설치하거나 자격증명을 자동 등록하지 않는다. 빠진 항목은 ❌로 보고하고 여기 조치를 안내한다.

## 0. 조직 값은 어디에 두나

이 저장소는 팀 공유 플러그인이다. **계정·프로젝트 키·서버 주소·프로젝트별 매핑을 스킬 파일에 하드코딩하지 않는다.**

| 값 성격 | 저장 위치 |
|---------|-----------|
| 자격증명 (ID/PW/토큰) | 셸 환경변수 (`~/.zshrc` 등). git에 올리지 않는다 |
| 조직 공통 값 (서버 URL, 부모 프로젝트 키, 기준 문서 URL) | 워크스페이스 `.cairn/profile/` |
| 저장소↔프로젝트 키 매핑 | 워크스페이스 `.cairn/profile/` |
| 개인 경로 (클라이언트 설치 위치 등) | 환경변수 |

---

## 1. 공통 — 세 스킬 전부

| 항목 | 확인 | 없을 때 |
|------|------|---------|
| Python 3 | `python3 --version` | OS 패키지 매니저로 설치 |
| `openpyxl` (엑셀 리포트) | `python3 -c "import openpyxl"` | `pip install openpyxl`. **스킬은 자동 설치하지 않는다** |
| 출력 루트 | 기본 `<현재 작업 디렉터리>/outputs` | 다른 위치를 쓰려면 스킬 실행 시 인자로 전달 |

> 산출물은 항상 `outputs/<run-id>/...` 아래에만 쓴다. 스캔 대상 소스 디렉터리에는 쓰지 않는다.

---

## 2. `security-check-cve` — 컨테이너 이미지 CVE

### 필수

| 항목 | 확인 | 없을 때 |
|------|------|---------|
| 컨테이너 런타임 | `docker version` 또는 `nerdctl version` | Docker Desktop / containerd + nerdctl 설치 |
| 취약점 스캐너 | `trivy --version` | Trivy 설치. 불가 시 Harbor 스캔 결과를 기준선으로 사용(리포트에 Harbor 스캐너 메타데이터로 라벨링) |
| 레지스트리 인증 | `docker login <registry>` 완료 상태 | credential helper 설정, 또는 robot-account 환경변수 |

### 선택

| 항목 | 용도 |
|------|------|
| robot-account 환경변수 | CI/무인 실행. **변수명만** 스킬에 알려주고 값은 노출하지 않는다 |
| 사설 CA 인증서 경로 | 사내 레지스트리 TLS. 명시적으로만 사용하며 TLS 검증을 끄지 않는다 |

### 아키텍처 주의

호스트와 이미지 아키텍처(amd64/arm64)가 다르면 에뮬레이션으로 검증된다. 결과는 `emulated / not production-verified`로 라벨링되고 네이티브 검증으로 인정되지 않는다. 운영 검증이 필요하면 **동일 아키텍처 머신**에서 실행한다.

---

## 3. `security-check-cce` — 컨테이너/K8s 보안 설정

### 필수

| 항목 | 확인 | 없을 때 |
|------|------|---------|
| 컨테이너 런타임 | `docker version` 또는 `nerdctl version` | 위와 동일 |
| Harbor 접근 | 레지스트리 로그인 완료 | credential helper 또는 robot-account |
| Confluence **읽기** 접근 | Atlassian 조회 도구 동작 확인 | 계정 권한 요청. **변경 권한은 불필요하며 사용하지 않는다** |

### 기준 문서

CCE 기준은 Confluence 2개 페이지에서 **매 실행마다 다시 읽는다** (계속 갱신되는 문서라 캐시 사용 금지).

페이지 URL은 워크스페이스 `.cairn/profile/cce.env` 에 둔다:

```bash
cp config/cce.env.example <워크스페이스>/.cairn/profile/cce.env
# CCE_GUIDE_URL / CCE_ITEMS_URL 을 조직 기준 문서로 설정
```

Confluence 접근이 안 되면 진단은 **중단**된다. 과거 사본으로 진행하지 않는다.

### 선택

| 항목 | 용도 |
|------|------|
| CCE 진단 스크립트 로컬 사본 | 첨부 다운로드가 막힌 환경에서 `--local-dir` 성격으로 제공 |
| `kubectl` / `helm` | 매니페스트 렌더링 (읽기 전용. apply 하지 않는다) |

### 진단 대상 제약

- shell 없는 distroless 이미지는 스크립트 진단 불가 → `Blocked`. 스크립트를 돌리려고 이미지를 변조하지 않는다
- 권한 있는 파일 읽기가 필요하면 root 진단 컨테이너를 **별도로** 띄우며, GATE 1에서 사용자 승인이 필요하다

---

## 4. `security-check-sparrow` — 소스코드 SAST

### 필수 4항목 (preflight)

| 항목 | 확인 | 없을 때 조치 |
|------|------|--------------|
| **내부망 도달** | `nc -z -w5 <서버호스트> <포트>` | 내부망/사내 VPN 연결. 방화벽에서 해당 호스트:포트 허용 확인 |
| **`SPARROW_ID` / `SPARROW_PW`** | set 여부만 확인 | SourceChecker 계정 발급 후 `~/.zshrc` 에 등록 (아래 주의) |
| **`SPARROW_PROJECT_KEY`** | set 여부 | 콘솔에서 본인 권한의 **부모** 프로젝트 키 확인 후 등록 |
| **클라이언트 설치** | `~/sparrow_client/sparrow-client.sh` 존재 | 벤더 배포 패키지를 받아 `~/sparrow_client/` 에 풀고 `bash ~/sparrow_client/setup.sh` 실행. 다른 경로면 `SPARROW_CLIENT=<경로>` |

점검은 번들 스크립트로 한 번에 한다 (자격증명 값은 출력되지 않는다):

```bash
bash skills/security-check-sparrow/scripts/preflight.sh    # exit 0 = 통과
```

### 설정 2곳으로 나눈다

**① 조직 공통값 → `.cairn/profile/sparrow.env`** (팀이 공유, git 관리 가능)

```bash
cp config/sparrow.env.example <워크스페이스>/.cairn/profile/sparrow.env
# SPARROW_URL, SPARROW_PROJECT_KEY, (선택) SPARROW_CA / SPARROW_CLIENT 를 채운다
```

스크립트가 현재 디렉터리에서 상위로 올라가며 이 파일을 찾는다. 이미 export 된 환경변수가 항상 우선한다.

**② 자격증명 → 셸 환경변수만** (파일에 두지 않는다)

```bash
export SPARROW_ID='<계정>'
export SPARROW_PW='<비밀번호>'   # 반드시 작은따옴표
```

> 개인 머신 사정(다른 설치 경로 등)은 `SPARROW_CLIENT` 로 각자 override 한다. 스킬·스크립트에는 개인 경로가 없다.

> ⚠ **비밀번호는 반드시 작은따옴표.** 큰따옴표면 `$`, `!` 등 특수문자가 셸에서 치환되어 틀린 PW가 전송되고 403이 난다.
> 등록 후 새 셸을 열거나 `set -a; source ~/.zshrc; set +a`.

### 계정 잠금 주의

인증 실패(403 등)가 반복되면 **계정이 잠길 수 있다.** 스킬은 인증 실패 시 자동 재시도하지 않고 원인만 보고한다. 사용자도 PW를 바꿔가며 반복 시도하지 말고, 따옴표 → 계정/비번 → 권한/IP 순으로 원인을 좁힌다.

### 동시 실행 금지

단일 계정/클라이언트 제약으로 두 개 이상 스캔을 동시에 돌리면 `[-140]` 충돌이 난다. 여러 저장소는 **순차 실행**한다.

### 클라이언트는 공개 배포되지 않는다

`sparrow-client`는 벤더 배포물이라 공개 다운로드 경로가 없다. 사내 배포 채널로 받아야 한다. 스킬은 자동 설치하지 않는다.

---

## 5. 최초 1회 점검 스크립트

```bash
echo "── 공통 ──"
python3 --version 2>/dev/null && echo "✅ python3" || echo "❌ python3"
python3 -c "import openpyxl" 2>/dev/null && echo "✅ openpyxl" || echo "❌ openpyxl (pip install openpyxl)"

echo "── 컨테이너 (cve / cce) ──"
docker version >/dev/null 2>&1 && echo "✅ docker" || echo "－ docker 없음"
nerdctl version >/dev/null 2>&1 && echo "✅ nerdctl" || echo "－ nerdctl 없음"
trivy --version >/dev/null 2>&1 && echo "✅ trivy" || echo "❌ trivy (없으면 Harbor 스캔 결과로 대체)"
kubectl version --client >/dev/null 2>&1 && echo "✅ kubectl" || echo "－ kubectl 없음(선택)"
helm version >/dev/null 2>&1 && echo "✅ helm" || echo "－ helm 없음(선택)"

echo "── sparrow ──"
bash skills/security-check-sparrow/scripts/preflight.sh
```

컨테이너 런타임은 docker/nerdctl 중 **하나만** 있으면 된다.

---

## 6. 자주 막히는 지점

| 증상 | 원인 | 조치 |
|------|------|------|
| 엑셀 리포트가 안 나옴 | `openpyxl` 미설치 | `pip install openpyxl`. 스킬은 자동 설치하지 않고 차단한다 |
| 이미지 pull 실패 | 인증·아키텍처·연결성 | 스킬이 원인을 좁혀 보고한다. 검증되지 않은 공개 이미지로 조용히 대체하지 않는다 |
| CCE 진단이 전부 Blocked | Confluence 조회 실패 또는 진단 스크립트 미확보 | 읽기 권한 확인, 또는 스크립트 로컬 사본 제공 |
| Sparrow 403 | PW 따옴표 / 계정 / 권한 | 재시도 금지. 위 4절 주의 참조 |
| `SPARROW_URL 이 없습니다` | 조직 공통값 미설정 | `config/sparrow.env.example` 를 `.cairn/profile/sparrow.env` 로 복사해 채운다 |
| TLS 인증서 오류 | 사내 사설 CA | `SPARROW_CA=<CA 경로>` 설정. `SPARROW_INSECURE=true` 는 최후 수단 |
| 검증 결과가 emulated | 호스트↔이미지 아키텍처 불일치 | 동일 아키텍처 머신에서 재실행 |

---

## 관련 문서

- `docs/SECURITY_CHECK_SKILLS_DESIGN.md` — CVE/CCE 스킬 설계 근거
- `config/sparrow.env.example` — Sparrow 조직 공통값 템플릿
- `config/cce.env.example` — CCE 기준 문서 URL 템플릿
- `skills/security-check-sparrow/references/troubleshooting.md` — Sparrow 에러 코드별 조치
- `scripts/verify-security-skills.py` — 세 스킬 구조 검증기 (`python3 scripts/verify-security-skills.py`)
- `rules/skill-governance.md` — 스킬 생성·GATE 규약
