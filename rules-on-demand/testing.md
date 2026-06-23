# Testing Requirements

## Minimum Test Coverage: 80%

Test Types (ALL required):
1. **Unit Tests** - Individual functions, utilities, components
2. **Integration Tests** - API endpoints, database operations
3. **API Contract Tests** - Request/response/error contract regression (Apidog)
4. **E2E Tests** - Critical user flows (Playwright)

## Layered Test Strategy (Backend/API Default)

Role split:
1. Internal tests (Unit/Integration): business logic, transaction, query behavior
2. Apidog: API contract and backward compatibility checks
3. Playwright: browser-level critical user journey checks

Minimum implementation baseline:
1. Unit: success/failure branch coverage for changed logic
2. Integration: key API마다 `성공 1 + 실패 1` 시나리오
3. Apidog: endpoint마다 `정상 + 인증 실패 + 필수값 오류` 3종 세트
4. Apidog test data/parameters must use DB-validated values and environment variables
5. Playwright: start with 3-5 critical flows, expand only when stable

Execution cadence:
1. PR gate: Unit + Integration + Apidog smoke
2. Pre-merge/pre-release: Playwright critical flows
3. Nightly: broader Apidog regression + expanded Playwright scenarios

## Test-Driven Development

MANDATORY workflow:
1. Write test first (RED)
2. Run test - it should FAIL
3. Write minimal implementation (GREEN)
4. Run test - it should PASS
5. Refactor (IMPROVE)
6. Verify coverage (80%+)

## Troubleshooting Test Failures

1. Use **tdd-guide** agent
2. Check test isolation
3. Verify mocks are correct
4. Fix implementation, not tests (unless tests are wrong)

## Agent Support

- **tdd-guide** - Use PROACTIVELY for new features, enforces write-tests-first
- **e2e-runner** - Playwright E2E testing specialist

