# Kubernetes / Helm 매니페스트 점검

## 원칙

- **전량 읽기 전용.** 클러스터 리소스와 원본 파일을 변경하지 않는다
- 조치는 `<출력루트>/<run-id>/cce/remediation/` 에 **복사본**으로만 생성한다
- 안전하게 해석 가능한 범위에서 표준 라이브러리 파싱을 사용한다. 전체 YAML 시맨틱이 필요한데 파서가 없으면 **잘못 해석하기보다 `Blocked` 처리**한다
- 환경에 이미 있는 도구(`kubectl --dry-run=client`, `helm template`)는 렌더링 용도로 사용 가능하다 (apply 금지)

## 점검 항목

| 항목 | Vulnerable 조건 |
|------|-----------------|
| root 실행 | `runAsNonRoot` 미설정/false, `runAsUser: 0` |
| privileged | `securityContext.privileged: true` |
| privilege escalation | `allowPrivilegeEscalation` 미설정 또는 true |
| capabilities | `drop: [ALL]` 부재, 불필요 `add` 존재 |
| host namespace | `hostNetwork` / `hostPID` / `hostIPC` true |
| hostPath | `hostPath` 볼륨 사용 |
| seccomp | `seccompProfile` 미설정 |
| read-only rootfs | `readOnlyRootFilesystem` 미설정/false |
| 리소스 제한 | `resources.limits` cpu/memory 부재 |
| 시크릿 취급 | 매니페스트 내 평문 시크릿, `env`에 자격증명 직접 기입 |
| 이미지 고정 | digest 미고정, `latest` 태그 사용 |

## 조치 파일

```text
remediation/
  Dockerfile              # 이미지·파일시스템 항목 조치
  kubernetes-patch.yaml   # 워크로드 securityContext 등 조치
  values-cce.yaml         # Helm values override
```

작성 규칙:

- 발견된 항목을 해소하는 **최소 변경**만 담는다
- 원본 파일 경로와 원본 값을 함께 기록해 diff를 추적 가능하게 한다
- 생성 후 **다시 파싱**해 항목이 실제로 해소되었는지 확인한 뒤 `조치 결과`에 반영한다
- 사용자가 실제 적용(apply/upgrade)을 수행한다. 스킬은 적용하지 않는다

## securityContext 조치 예시

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
  seccompProfile:
    type: RuntimeDefault
resources:
  limits:
    cpu: "1"
    memory: "1Gi"
  requests:
    cpu: "100m"
    memory: "256Mi"
```

`readOnlyRootFilesystem: true`는 쓰기 경로가 필요한 애플리케이션을 중단시킬 수 있다. 적용 전 필요한 `emptyDir` 마운트를 함께 제안하고, 영향 가능성을 리포트에 명시한다.
