# Confluence 읽기 전용 정책 (CRITICAL)

## 선언 문장

실행 시작 시 아래 문장을 그대로 출력하고 실행 로그에 남긴다.

```text
Confluence mode: READ ONLY. No page, comment, attachment, or metadata changes will be made.
```

## 허용 도구 (조회 계열만)

- `getConfluencePage`
- `getConfluencePageDescendants`
- `searchConfluenceUsingCql`
- 읽기 전용 `fetch`

## 금지 도구 (절대 호출 금지)

- `createConfluencePage`
- `updateConfluencePage`
- `createConfluenceFooterComment`
- `createConfluenceInlineComment`
- 첨부 업로드 / 라벨 변경 / 이동 / 삭제 등 일체의 변경 API

위 이름들은 **이 정책 블록과 검증용 문서에서만** 등장해야 한다. 실행 지시문·명령 예시에 나타나면 실패한 실행이다.

## 자가 점검

GATE 2에서 아래를 확인한다.

- [ ] 이번 실행의 도구 호출 목록에 금지 도구 0건
- [ ] SKILL.md·실행 로그·증거 파일에서 금지 도구 이름이 "호출" 맥락으로 등장하지 않음
- [ ] Confluence API 토큰을 요청·저장하지 않음

검증 명령 예:

```bash
grep -nE 'createConfluence|updateConfluence|ConfluenceFooterComment|ConfluenceInlineComment' \
  outputs/<run-id>/cce/evidence/ -r
```

기대: 정책 인용 외 호출 흔적 0건.

## 기준 페이지 재수집 원칙

- CCE 기준 문서는 계속 갱신된다. **매 실행마다 다시 읽는다**
- 내장 사본·이전 run의 캐시를 "현재 기준"으로 사용하지 않는다
- 페이지를 읽지 못하면 진단을 중단하거나 기준선을 `blocked`로 표시한다. 조용한 fallback 금지
- 페이지 버전 번호가 이전 run과 다르면 변경 사실을 리포트 `기준 정보` 시트에 남긴다
