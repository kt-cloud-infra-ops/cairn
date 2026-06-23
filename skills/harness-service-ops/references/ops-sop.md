# Service Ops SOP

Confluence page `${CONFLUENCE_SPACE_KEY} / ${CONFLUENCE_PAGE_ID} / demo 를 이용한 개발 환경 만들기`에서
운영 반영 단계에 해당하는 절차만 정규화한 요약이다.

## 범위

- Vault Secret 등록
- Observability 연동 확인
- GitHub Actions build 확인
- ArgoCD sync
- DB 생성
- DDL / DML 적용
- 관리자 권한 부여
- 웹 접속 검증

## 단계 요약

1. Vault Secret 등록
2. Observability 연동 확인
3. GitHub F/E, B/E Action 수행 및 build 성공 확인
4. chart/value push 후 ArgoCD sync
5. 필요 시 deployment restart와 env 반영 확인
6. DB 생성
7. template `doc/ddl`, `doc/dml` 기준 DDL / DML 적용
8. 특정 사용자 관리자 권한 추가
9. hostname 접속 검증

## 정규화 메모

- HTTPRoute 파일 생성 자체는 bootstrap 단계에서 준비할 수 있다.
  실제 sync/적용/검증은 ops 단계에서 다룬다.
- 페이지의 kubectl 예시는 "env 값 반영 안 될 때 restart"에 대한 운영 보조 절차다.
  스킬에서는 rollout 검증 단계로 일반화한다.
- DDL/DML 경로는 backend template 기준 예시다.
  실제 적용 시점에는 서비스별 rename 결과 경로를 사용한다.
