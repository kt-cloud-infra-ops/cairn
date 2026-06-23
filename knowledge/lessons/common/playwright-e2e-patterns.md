---
tags:
  - type/guide
  - domain/testing
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# 학습: Playwright E2E 테스트 작성 패턴 및 베스트 프랙티스

## 날짜
2026-01-30

## 세션/프로젝트
E2E 테스트 자동화

## 배운 것

### 1. "없으면 스킵" 패턴의 위험성

**문제점**:
- 선택자가 없을 때 자동으로 스킵하는 패턴은 버그를 숨김
- 테스트가 통과하지만 실제 기능은 깨져있을 수 있음

**안티패턴**:
```typescript
// 나쁜 예: 선택자가 없으면 조용히 스킵됨
if (await page.locator('selector').isVisible()) {
  // 테스트 진행
}
```

**올바른 패턴**:
```typescript
// 좋은 예: 명시적으로 존재를 검증
await expect(page.locator('selector')).toBeVisible()
// 선택자가 없으면 테스트 실패 → 버그 감지
```

### 2. TUI Grid vs 일반 HTML 테이블 선택자

**차이점**:
- **일반 테이블**: `<table>` → `<tr>` → `<td>` 구조로 쉬운 선택
- **TUI Grid**: 내부적으로 다양한 div/span으로 렌더링되어 일반 선택자로 접근 불가

**선택자 전략**:
```typescript
// 일반 테이블
const row = page.locator('table tr').nth(1).locator('td').nth(0)

// TUI Grid: 특정 속성/클래스로 타겟팅
const cell = page.locator('[data-row-key="123"][data-col="name"]')
const cellText = page.locator('.tui-grid-cell:has-text("검색값")')
```

**권장 사항**:
- TUI Grid의 내부 구조를 개발자 도구로 검사
- `data-*` 속성, `role` 속성, 고유 클래스 사용
- 가능한 한 `getByRole()` 사용 (더 안정적)

### 3. 팝업 선택자 패턴

**효과적인 팝업 선택자**:
```typescript
// 표시된 팝업만 선택 (숨겨진 팝업 제외)
const visiblePopup = page.locator('article.popup:not(.hide)')

// 팝업 내 버튼
const confirmBtn = page.locator('article.popup:not(.hide)').locator('button:has-text("확인")')
```

**구조 예시**:
```html
<!-- 팝업 표시 상태 -->
<article class="popup">
  <button>확인</button>
</article>

<!-- 팝업 숨겨진 상태 -->
<article class="popup hide">
  <button>확인</button>
</article>
```

**주의사항**:
- `:not(.hide)` 사용으로 숨겨진 팝업 선택 방지
- 모달이나 다중 팝업 환경에서 필수적

### 4. 버그 검출 테스트 작성 방법

**원칙**: 버그를 검출하는 테스트는 명시적 검증 필수

**안티패턴 - 버그를 놓치는 테스트**:
```typescript
test('버튼 클릭 후 데이터 로드', async ({ page }) => {
  await page.click('button')
  // 기대 동작을 검증하지 않음
  // 화면 전환만 확인 → 실제 데이터 누락 감지 불가
})
```

**올바른 패턴 - 버그를 검출하는 테스트**:
```typescript
test('버튼 클릭 후 데이터 로드', async ({ page }) => {
  // 1. 초기 상태 검증
  await expect(page.locator('#data-table')).toHaveCount(0)

  // 2. 액션 실행
  await page.click('button[id="load-btn"]')

  // 3. 로딩 상태 확인
  await expect(page.locator('.loading')).toBeVisible()

  // 4. 데이터 로드 완료 대기
  await expect(page.locator('#data-table')).toBeVisible()

  // 5. 명시적 데이터 검증
  const rows = page.locator('#data-table tbody tr')
  await expect(rows).toHaveCount(5) // 정확히 5개 로드됨

  // 6. 데이터 내용 검증
  await expect(rows.nth(0)).toContainText('예상 값')
})
```

**핵심**:
- `expect()`로 모든 중요 상태 검증
- 버그가 있으면 테스트가 명확하게 실패
- 각 단계별 검증으로 어느 부분이 깨졌는지 즉시 파악

### 5. 동일한 텍스트의 여러 버튼 구분 - nth() 사용

**문제상황**:
```html
<button>확인</button>  <!-- 첫 번째 -->
<button>확인</button>  <!-- 두 번째 -->
<button>확인</button>  <!-- 세 번째 -->
```

**잘못된 접근**:
```typescript
// 모두 첫 번째 버튼을 선택함
await page.click('button:has-text("확인")')
```

**올바른 접근 - nth() 사용**:
```typescript
// 첫 번째 "확인" 버튼
await page.locator('button:has-text("확인")').nth(0).click()

// 두 번째 "확인" 버튼
await page.locator('button:has-text("확인")').nth(1).click()

// 세 번째 "확인" 버튼
await page.locator('button:has-text("확인")').nth(2).click()
```

**문맥 기반 선택 (권장)**:
```typescript
// 팝업 내의 "확인" 버튼
const popup = page.locator('article.popup:not(.hide)')
await popup.locator('button:has-text("확인")').click()

// 모달 내의 "확인" 버튼
const modal = page.locator('div.modal:visible')
await modal.locator('button:has-text("확인")').click()

// 특정 섹션 내의 "확인" 버튼
const section = page.locator('section[data-role="user-form"]')
await section.locator('button:has-text("확인")').click()
```

**우선순위**:
1. 문맥 기반 선택 (가장 안정적)
2. `nth()` 사용 (문맥이 없을 때)
3. ID/data 속성 추가 요청 (개발팀)

---

## 적용 가능한 상황

### 즉시 적용
- <YOUR_SERVICE> Web E2E 테스트 작성
- 팝업/모달 관련 테스트
- 테이블/그리드 데이터 검증 테스트
- 버그 검출 테스트

### 향후 프로젝트
- 다른 Playwright 기반 E2E 테스트
- Web UI 자동화 테스트
- 복잡한 대화형 요소 테스트

---

## 참고 자료

### 공식 문서
- [Playwright Locator Guide](https://playwright.dev/docs/locators)
- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Assertions](https://playwright.dev/docs/test-assertions)

### 관련 학습 문서
- `docs/learnings/e2e-testing-guide.md` (필요시 신규 작성)

### 프로젝트 참고
- `<your_service>_e2e/tests/` - E2E 테스트 구현 예시 (프로젝트에 맞게 교체)
- `<your_service>_e2e/README.md` - 테스트 작성 가이드

---

## 체크리스트 - E2E 테스트 작성 시

테스트 작성 전 다음을 확인하세요:

- [ ] 선택자가 실제로 존재하는가? (`toBeVisible()` 검증)
- [ ] "없으면 스킵"은 사용하지 않았는가?
- [ ] 팝업/모달은 `:not(.hide)` 패턴 사용했는가?
- [ ] 모든 주요 상태 변화를 `expect()`로 검증했는가?
- [ ] 버그를 감지할 수 있는 명시적 검증이 있는가?
- [ ] 동일한 텍스트 요소는 문맥 기반 또는 `nth()` 사용했는가?
- [ ] 테스트가 일관되게 통과하는가? (플래키 테스트 없음)

---

## 버전 이력

| 날짜 | 변경사항 |
|------|---------|
| 2026-01-30 | 초기 작성 - 5가지 핵심 패턴 문서화 |
