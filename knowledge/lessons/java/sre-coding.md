---
tags:
  - type/guide
  - domain/java
  - domain/sre
  - audience/claude
---

> 상위: [java](README.md) · [lessons](../README.md)

# SRE 코딩 가이드

> KT Cloud Java 프로젝트 공통 가이드 - 운영/회복력 관점

---

## 1. 모니터링 & 로깅

### 로그 레벨 기준

| 레벨 | 용도 | 예시 |
|------|------|------|
| ERROR | 즉시 대응 필요한 오류 | DB 연결 실패, 외부 API 장애 |
| WARN | 잠재적 문제, 모니터링 필요 | 재시도 발생, 임계값 근접 |
| INFO | 주요 비즈니스 이벤트 | 작업 시작/완료, 상태 변경 |
| DEBUG | 디버깅용 상세 정보 | 파라미터 값, 중간 결과 |

### 로그 포맷 규칙

```java
// Good: 구조화된 로그
log.info("작업 완료: jobId={}, duration={}ms, count={}", jobId, duration, count);
log.error("API 호출 실패: url={}, status={}, message={}", url, status, e.getMessage(), e);

// Bad: 비구조화된 로그
log.info("작업이 완료되었습니다.");
log.error("에러 발생: " + e.toString());
```

### 필수 로그 포인트

```java
@Service
@Slf4j
public class CriticalService {

    public Result process(Request request) {
        String traceId = MDC.get("traceId"); // 추적 ID

        // 1. 시작 로그
        log.info("[{}] 처리 시작: requestId={}", traceId, request.getId());

        try {
            // 2. 외부 호출 전후
            log.debug("[{}] 외부 API 호출: url={}", traceId, apiUrl);
            Response response = externalApi.call(request);
            log.debug("[{}] 외부 API 응답: status={}", traceId, response.getStatus());

            // 3. 완료 로그
            log.info("[{}] 처리 완료: requestId={}, result={}", traceId, request.getId(), result);
            return result;

        } catch (Exception e) {
            // 4. 에러 로그 (스택트레이스 포함)
            log.error("[{}] 처리 실패: requestId={}, error={}", traceId, request.getId(), e.getMessage(), e);
            throw e;
        }
    }
}
```

### 메트릭 수집

```java
// Micrometer 사용 예시
@Component
@RequiredArgsConstructor
public class MetricsService {
    private final MeterRegistry registry;

    // 카운터: 발생 횟수
    public void incrementApiCall(String endpoint, String status) {
        registry.counter("api_calls_total",
            "endpoint", endpoint,
            "status", status
        ).increment();
    }

    // 게이지: 현재 값
    public void recordQueueSize(int size) {
        registry.gauge("queue_size", size);
    }

    // 히스토그램: 분포 (응답 시간 등)
    public void recordLatency(String operation, long durationMs) {
        registry.timer("operation_duration",
            "operation", operation
        ).record(Duration.ofMillis(durationMs));
    }
}
```

---

## 2. 에러 핸들링 & 회복력

### 예외 계층 구조

```java
// 비즈니스 예외 (복구 가능)
public class BusinessException extends RuntimeException {
    private final ErrorCode errorCode;
    private final Map<String, Object> context;
}

// 시스템 예외 (복구 불가)
public class SystemException extends RuntimeException {
    private final boolean retryable;
}

// 외부 시스템 예외
public class ExternalServiceException extends RuntimeException {
    private final String serviceName;
    private final int statusCode;
}
```

### 재시도 (Retry) 패턴

```java
@Service
@Slf4j
public class ResilientService {

    // Spring Retry 사용
    @Retryable(
        value = {TransientException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 1000, multiplier = 2)
    )
    public Result callExternalApi(Request request) {
        return externalApi.call(request);
    }

    @Recover
    public Result recover(TransientException e, Request request) {
        log.warn("재시도 모두 실패, 폴백 실행: {}", request.getId());
        return Result.fallback();
    }
}

// 직접 구현
public Result callWithRetry(Request request, int maxRetries) {
    int attempt = 0;
    while (true) {
        try {
            return externalApi.call(request);
        } catch (TransientException e) {
            attempt++;
            if (attempt >= maxRetries) {
                log.error("재시도 한도 초과: attempts={}", attempt);
                throw e;
            }
            long delay = (long) Math.pow(2, attempt) * 1000;
            log.warn("재시도 예정: attempt={}, delay={}ms", attempt, delay);
            Thread.sleep(delay);
        }
    }
}
```

### 서킷 브레이커 (Circuit Breaker)

```java
// Resilience4j 사용
@Service
public class CircuitBreakerService {

    @CircuitBreaker(name = "externalApi", fallbackMethod = "fallback")
    public Result callExternalApi(Request request) {
        return externalApi.call(request);
    }

    public Result fallback(Request request, Exception e) {
        log.warn("서킷 오픈, 폴백 응답: {}", e.getMessage());
        return Result.cached(); // 캐시된 데이터 반환
    }
}

// application.yml 설정
resilience4j:
  circuitbreaker:
    instances:
      externalApi:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
```

### 타임아웃 설정

```java
// 모든 외부 호출에 타임아웃 필수
@Configuration
public class RestTemplateConfig {

    @Bean
    public RestTemplate restTemplate() {
        return new RestTemplateBuilder()
            .setConnectTimeout(Duration.ofSeconds(5))
            .setReadTimeout(Duration.ofSeconds(30))
            .build();
    }
}

// 비동기 작업 타임아웃
CompletableFuture<Result> future = CompletableFuture.supplyAsync(() -> process());
Result result = future.get(30, TimeUnit.SECONDS); // 30초 타임아웃
```

### 벌크헤드 (Bulkhead) 패턴

```java
// 스레드 풀 분리로 장애 격리
@Configuration
public class ThreadPoolConfig {

    @Bean("criticalTaskExecutor")
    public Executor criticalTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("critical-");
        executor.setRejectedExecutionHandler(new CallerRunsPolicy());
        return executor;
    }

    @Bean("batchTaskExecutor")
    public Executor batchTaskExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("batch-");
        return executor;
    }
}
```

---

## 3. 성능 & 리소스 관리

### 커넥션 풀 설정

```yaml
# HikariCP 설정
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      connection-timeout: 30000
      idle-timeout: 600000
      max-lifetime: 1800000
      leak-detection-threshold: 60000  # 커넥션 누수 감지
```

### 캐싱 전략

```java
@Service
@Slf4j
public class CachedService {

    // 1. 로컬 캐시 (짧은 TTL)
    @Cacheable(value = "shortTermCache", key = "#id")
    public Data getFrequentData(String id) {
        return repository.findById(id);
    }

    // 2. 분산 캐시 (Redis)
    @Cacheable(value = "distributedCache", key = "#id", unless = "#result == null")
    public Data getSharedData(String id) {
        return repository.findById(id);
    }

    // 3. 캐시 무효화
    @CacheEvict(value = "shortTermCache", key = "#id")
    public void updateData(String id, Data data) {
        repository.save(data);
    }
}
```

### 배치 처리

```java
// 대량 데이터는 청크 단위로 처리
public void processBatch(List<Item> items) {
    int chunkSize = 100;

    Lists.partition(items, chunkSize).forEach(chunk -> {
        try {
            processChunk(chunk);
            log.info("청크 처리 완료: size={}", chunk.size());
        } catch (Exception e) {
            log.error("청크 처리 실패: size={}", chunk.size(), e);
            // 개별 처리로 폴백
            chunk.forEach(this::processSingle);
        }
    });
}
```

---

## 4. 운영 고려사항

### Health Check 엔드포인트

```java
@Component
public class CustomHealthIndicator implements HealthIndicator {

    @Override
    public Health health() {
        // 외부 의존성 체크
        boolean dbHealthy = checkDatabase();
        boolean redisHealthy = checkRedis();
        boolean externalApiHealthy = checkExternalApi();

        if (dbHealthy && redisHealthy && externalApiHealthy) {
            return Health.up()
                .withDetail("database", "OK")
                .withDetail("redis", "OK")
                .withDetail("externalApi", "OK")
                .build();
        }

        return Health.down()
            .withDetail("database", dbHealthy ? "OK" : "FAIL")
            .withDetail("redis", redisHealthy ? "OK" : "FAIL")
            .withDetail("externalApi", externalApiHealthy ? "OK" : "FAIL")
            .build();
    }
}
```

### Graceful Shutdown

```java
@Component
public class GracefulShutdown implements ApplicationListener<ContextClosedEvent> {

    @Autowired
    private ThreadPoolTaskExecutor taskExecutor;

    @Override
    public void onApplicationEvent(ContextClosedEvent event) {
        log.info("Graceful shutdown 시작");

        // 1. 새 요청 거부
        taskExecutor.setWaitForTasksToCompleteOnShutdown(true);
        taskExecutor.setAwaitTerminationSeconds(30);

        // 2. 진행 중인 작업 완료 대기
        taskExecutor.shutdown();

        log.info("Graceful shutdown 완료");
    }
}
```

### 설정 외부화

```java
// 환경별 설정 분리
@ConfigurationProperties(prefix = "app.external-api")
@Validated
public class ExternalApiProperties {

    @NotBlank
    private String baseUrl;

    @Min(1000) @Max(60000)
    private int timeout = 30000;

    @Min(1) @Max(10)
    private int maxRetries = 3;
}
```

### 기능 플래그 (Feature Flag)

```java
@Service
public class FeatureFlagService {

    @Value("${feature.new-algorithm.enabled:false}")
    private boolean newAlgorithmEnabled;

    public Result process(Request request) {
        if (newAlgorithmEnabled) {
            return newAlgorithm.process(request);
        }
        return legacyAlgorithm.process(request);
    }
}
```

---

## 5. SRE 체크리스트

### 코드 작성 시
- [ ] 모든 외부 호출에 타임아웃 설정
- [ ] 재시도 가능한 예외와 불가능한 예외 구분
- [ ] 구조화된 로그 작성
- [ ] 주요 작업에 메트릭 수집

### 배포 전
- [ ] Health check 엔드포인트 구현
- [ ] Graceful shutdown 구현
- [ ] 설정 외부화 완료
- [ ] 롤백 계획 수립

### 운영 시
- [ ] 알림 임계값 설정
- [ ] 대시보드 구성
- [ ] 장애 대응 런북 작성
- [ ] 정기적인 장애 훈련 (Chaos Engineering)

---

## 참고 자료
- Google SRE Book
- Release It! (Michael Nygard)
- Resilience4j Documentation

---

관련: [KT Cloud 스타일](kt-cloud-style.md) · [디자인 패턴](design-patterns.md) · [MyBatis](mybatis-sql-patterns.md) · [코드 리뷰 함정](code-review-traps.md)
