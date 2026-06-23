---
tags:
  - type/guide/lesson
  - domain/sre
  - audience/team
---

> 상위: [lessons](../README.md) · [knowledge](../../README.md)

# K8s 클러스터 이사 — 운영/크로스체크 명령어 사례집

> **맥락**: `<old-cluster>`(old) → `<new-cluster>`(new) 서비스 이관 사례.
> 실제 작업 세션에서 사용한 명령어를 **스터디용 사례**로 정리. 자격증명·구체 IP는 일반화함.
> 본 사례의 핵심 역할은 **"크로스체크"** — 실제 변경(배포)은 다른 세션이 하고, 이 명령들은 *대조·검증·모니터링* 용도다.

---

## 0. 등장 클러스터 정리

| 구분 | cluster 이름 | context | API server | 비고 |
|------|------|---------|-----------|------|
| OLD | `<old-cluster>` | `<old-context>` | `<old-api-server>` | 단일 namespace |
| NEW | `<new-cluster>` | `<ns-*>` | `<new-api-server>` | namespace 분리 |

---

## 1. kubeconfig 다중 클러스터 통합

여러 namespace별 인증파일(각각 ServiceAccount 토큰)을 **한 파일로 merge**하여 context 전환만으로 오가게 한다.

```bash
# 1) old 원본 백업 (항상 먼저)
cp ~/.kube/kubeconfig-<old-cluster> ~/.kube/kubeconfig-<old-cluster>.bak.$(date +%Y%m%d)

# 2) old + new(combined)를 self-contained 한 파일로 flatten merge
#    --flatten: 외부 파일 참조 없이 토큰/인증서를 인라인으로 박아 단일 파일로 완결
KUBECONFIG=~/.kube/kubeconfig-<old-cluster>:~/.kube/kubeconfig-<new-cluster> \
  kubectl config view --flatten > ~/.kube/kubeconfig-merged

chmod 600 ~/.kube/kubeconfig-merged

# 3) 기본 config가 가리키도록 symlink 교체 (원본 보존)
ln -sf kubeconfig-merged ~/.kube/config
```

**개념 핵심**
- kubeconfig는 "네트워크 통로"가 아니라 **인증 정보(신분증) 묶음**. API server endpoint는 어차피 동일.
- merge = 흩어진 SA 토큰들을 한 지갑에 모은 것. **각 context의 권한 범위(namespace 한정)는 그대로**.
- `--flatten` 덕분에 원본 조각 파일을 지워도 동작.

**되돌리기**: `ln -sf kubeconfig-<old-cluster> ~/.kube/config`

---

## 2. context 전환 / 확인

```bash
# 통합된 전체 context 목록 (CURRENT 표시)
kubectl config get-contexts
kubectl config get-contexts -o name   # 이름만

# 전환
kubectl config use-context <old-context>          # OLD
kubectl config use-context <new-context>          # NEW

# 1회성 전환 없이 특정 context로만 명령 (안전)
kubectl --context <new-context> get pod -n <new-namespace>

# 지금 어디를 보고 있는지 — 작업 전 습관적으로 확인 (오발사 방지)
kubectl config current-context
```

> **사고 예방**: old/new를 오가다 엉뚱한 클러스터에 명령하는 사고가 잦다. `--context`를 매 명령에 명시하거나, 작업 전 `current-context`를 확인한다.

---

## 3. k9s context별 색 구분 (skin)

통합 kubeconfig는 한 화면에 1개 context만 보여준다. **색 테마로 old/new를 시각 구분**하면 오발사를 막는다.

```bash
# k9s 설정 경로 확인 (macOS는 ~/.config 아님!)
k9s info
# → Skins:          ~/Library/Application Support/k9s/skins
# → Context Configs: ~/Library/Application Support/k9s/clusters
```

**(a) skin 파일 2종** — `skins/oss-red.yaml`(old), `skins/oss-blue.yaml`(new). 핵심 키만 지정해도 나머지는 stock skin이 채운다.

```yaml
# skins/oss-red.yaml (발췌) — 부분 skin 허용
k9s:
  body:    { fgColor: "#d0d0d0", bgColor: "#1a0606", logoColor: "#ff5f5f" }
  frame:
    border: { fgColor: "#ff5f5f", focusColor: "#ff8787" }
    crumbs: { fgColor: "#000000", bgColor: "#d70000" }   # 하단 breadcrumb 배경
    title:  { fgColor: "#ff8787", bgColor: "#1a0606" }
```

**(b) context별 config에 skin 지정** — `clusters/<cluster>/<context>/config.yaml`의 `k9s.ui.skin`.

```yaml
# clusters/cluster-mgmt01/ns-oss-db/config.yaml (발췌)
k9s:
  cluster: cluster-mgmt01
  namespace: { active: ns-oss-db }
  ui:
    skin: oss-blue       # ← 이 줄이 핵심
```

**검증**: k9s 실행 → `:ctx`로 전환 시 화면 색이 바뀌면 성공. 안 되면 로그 확인:
```bash
grep -i skin "$HOME/Library/Application Support/k9s/k9s.log" | tail -20
```

---

## 4. 클러스터 상태 크로스체크

### 4-1. namespace별 배포 리소스 유무 (이관 진척도)

```bash
T="--request-timeout=15s"
NS_LIST=(ns-<svc-a> ns-<svc-b> ns-<svc-c>)  # 환경에 맞게 교체

for ns in "${NS_LIST[@]}"; do
  out=$(kubectl --context "$ns" $T -n "$ns" get deploy,sts,cronjob,job,pod,pvc,svc 2>&1)
  cnt=$(echo "$out" | grep -vc "No resources\|^$")
  echo "===== [$ns] (리소스 행수: $cnt) ====="
  echo "$out" | grep -v "No resources" | head -15
done
```

### 4-2. CNPG Postgres / PVC Bound 검증 (배포 성공 + StorageClass 실증)

```bash
kubectl --context <new-db-context> -n <new-db-ns> \
  get cluster.postgresql.cnpg.io,pod,pvc,svc,secret
# 확인 포인트:
#  - cluster INSTANCES/READY (예: 3/3 healthy)
#  - PVC STATUS=Bound + STORAGECLASS 이름 + ACCESS MODE(RWO/RWX) ← SC 유효성 실증
```

### 4-3. old workload 가동 현황 (영향도/이관대상 식별)

```bash
kubectl --context <old-context> -n <old-namespace> get deploy,sts,cronjob
# deployment AGE/READY로 실제 가동 서비스 파악 → 이관 매핑 누락 교차 검증
```

---

## 5. RBAC 권한 범위 확인 (namespace-scoped SA의 한계)

```bash
# 이 context(SA)가 namespace 안에서 뭘 할 수 있나
kubectl --context <new-context> -n <new-namespace> auth can-i --list
# → "*.* [*]" 면 namespace 내 풀권한

# cluster-scoped 리소스는 막힘 (실제 사례)
kubectl --context <new-context> get storageclass
# Error: ... storageclasses ... is forbidden ... at the cluster scope
```

> **교훈**: namespace SA로는 StorageClass/Node/CRD 등 **cluster-scoped 조회 불가**.
> 그 정보(예: 사용 가능한 StorageClass 이름)는 **Platform 팀에 직접 문의**해야 한다.
> "old 클러스터에서 spec export → new apply" 전략도 권한 부족으로 막히므로,
> **GitOps values 레포를 Source of Truth로 재생성**하는 방식이 현실적.

---

## 6. DB 정합성 baseline & 크로스체크 (old ↔ new)

마이그레이션 검증은 **DB 크기 + 테이블 개수 + 핵심테이블 실제 count(*)** 3축으로 한다.
(`pg_stat_user_tables.n_live_tup`은 통계 미수집 시 0으로 나와 신뢰 불가 → 실제 count 사용)

```bash
# DB별 크기
kubectl --context <ctx> -n <ns> exec <pg-pod> -- \
  psql -U postgres -d postgres -tA -c \
  "SELECT datname||' | '||pg_size_pretty(pg_database_size(datname))
   FROM pg_database WHERE datname NOT IN ('template0','template1','postgres');"

# public 스키마 테이블 개수 (정합성 기준값)
kubectl --context <ctx> -n <ns> exec <pg-pod> -- \
  psql -U postgres -d <db> -tA -c \
  "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"
```

**실측 baseline 예시 (OLD)**: 마이그레이션 전 DB 크기/테이블 수를 기록하고,
복원 완료 후 NEW가 이 값에 수렴하는지 대조.

---

## 7. 데이터 복원 진행 모니터링 (백그라운드 폴링 패턴)

긴 pg_restore(수 GB)는 **완료 조건을 폴링**하다 충족 시 자동 재진입시킨다.
(foreground sleep은 막혀 있어 `run_in_background`로 실행 — 10분 청크로 끊어 진행보고)

```bash
KCTL_ARGS=(--context <new-db-context> --request-timeout=20s -n <new-db-ns> \
           exec <pg-pod-name> -- psql -U postgres -d postgres -tA -c)
END=$((SECONDS+560)); last=""
while [ $SECONDS -lt $END ]; do
  row=$(kubectl "${KCTL_ARGS[@]}" \
    "SELECT pg_database_size('<db1>')||'|'||pg_database_size('<db2>')" 2>/dev/null | tr -d ' \r')
  db1=${row%%|*}; db2=${row##*|}
  [ -n "$row" ] && last="db1=$((db1/1024/1024))MB db2=$((db2/1024/1024))MB"
  if [ -n "$db1" ] && [ "$db1" -gt <THRESHOLD_BYTES> ]; then  # baseline의 ~93%로 설정
    echo "RESTORE_DONE $last"; exit 0
  fi
  sleep 60
done
echo "STILL_RESTORING $last"
```

> **포인트**: 완료 임계는 baseline(old 9.7GB)의 ~93%(9GB)로 잡아 조기 트리거 → 트리거 후 정밀 정합성 검증. 한 번 실행이 timeout(10분) 안에 끝나도록 청크로 끊고, 미완이면 재실행.

---

## 8. cmux 멀티세션 협업 (옆세션 크로스체크)

```bash
# 세션 트리 (workspace/pane/surface ID 확인)
cmux tree

# 옆세션 화면 읽기 (--workspace 까지 명시)
cmux read-screen --workspace workspace:4 --surface surface:9 --lines 45

# 옆세션에 메시지 — 4대 규칙: ID명시 + send/enter분리 + 발신자헤더
cmux send     --workspace workspace:4 --surface surface:9 -- "[workspace:4 surface:28] ...메시지..."
cmux send-key --workspace workspace:4 --surface surface:9 enter
```

> 상세 규칙: [cmux CLI 사용법](../../../.claude/...) — 메모리 `cmux-cli.md` 참조.

---

## 9. zsh 함정 / 팁

| 함정 | 증상 | 해결 |
|------|------|------|
| **word splitting 미동작** | `for x in $VAR` 가 전체를 1단어로 취급 | 배열 사용 `VAR=(a b c); for x in "${VAR[@]}"` |
| 비밀번호 특수문자 | `$`,`` ` ``,`!` 쉘 해석 | `PGPASSWORD=$'...'`(ANSI-C) 또는 `~/.pgpass` |
| kubectl exec 경고 | `Defaulted container ...` stderr 혼입 | `2>/dev/null` + `tr -dc '0-9'` 로 숫자만 추출 |

---

## 핵심 교훈 (요약)

1. **kubeconfig 통합 ≠ 권한 통합** — 신분증을 모은 것일 뿐, 각 SA의 namespace 한정 권한은 그대로.
2. **색 구분(k9s skin)** 은 old/new 오발사를 막는 값싼 보험.
3. **namespace SA는 cluster-scoped 조회 불가** → StorageClass 등은 Platform 문의 / GitOps 레포 재생성.
4. **정합성은 크기+테이블수+실제count 3축** — n_live_tup 통계는 0일 수 있어 신뢰 금지.
5. **데이터 복원은 app sync보다 선행** — 빈 DB에 app 붙으면 부팅 실패.
6. **크로스체크 세션 분리** — 변경 주체와 검증 주체를 나누면 실수를 상호 포착.

---

## 관련 문서

- [브루 PostgreSQL dyld 픽스](brew-postgresql-dyld-fix.md) — 로컬 psql 환경
- 마이그레이션 계획 원본: `temp/<migration-plan>.md`
