---
tags:
  - type/guide
  - domain/java
  - audience/claude
---

> 상위: [java](README.md) · [lessons](../README.md)

# 디자인 패턴 가이드

> <YOUR_ORG> Java 프로젝트 공통 가이드

---

## 생성 패턴 (Creational Patterns)

### 1. Singleton (싱글톤)
**용도**: 인스턴스가 하나만 필요한 경우 (설정, 커넥션 풀 등)

```java
// Spring에서는 기본적으로 Bean이 Singleton
@Service
public class ConfigService {
    // Spring이 싱글톤으로 관리
}

// 직접 구현 시
public class Singleton {
    private static final Singleton INSTANCE = new Singleton();
    private Singleton() {}
    public static Singleton getInstance() { return INSTANCE; }
}
```

**주의**: 상태를 가지면 안 됨 (Thread-safe 문제)

### 2. Factory (팩토리)
**용도**: 객체 생성 로직을 캡슐화

```java
public interface NotificationFactory {
    Notification create(String type);
}

@Component
public class NotificationFactoryImpl implements NotificationFactory {
    @Override
    public Notification create(String type) {
        switch (type) {
            case "EMAIL": return new EmailNotification();
            case "SLACK": return new SlackNotification();
            case "SMS": return new SmsNotification();
            default: throw new IllegalArgumentException("Unknown type: " + type);
        }
    }
}
```

### 3. Builder (빌더)
**용도**: 복잡한 객체 생성, 선택적 파라미터가 많은 경우

```java
// Lombok @Builder 사용 권장
@Builder
@Getter
public class SearchRequest {
    private String keyword;
    private LocalDate startDate;
    private LocalDate endDate;
    private int page;
    private int size;
}

// 사용
SearchRequest request = SearchRequest.builder()
    .keyword("test")
    .startDate(LocalDate.now())
    .page(1)
    .size(20)
    .build();
```

---

## 구조 패턴 (Structural Patterns)

### 4. Adapter (어댑터)
**용도**: 호환되지 않는 인터페이스를 연결

```java
// 외부 API 응답을 내부 모델로 변환
public class ZabbixResponseAdapter {
    public List<HostInfo> adapt(ZabbixApiResponse response) {
        return response.getResult().stream()
            .map(this::toHostInfo)
            .collect(Collectors.toList());
    }

    private HostInfo toHostInfo(ZabbixHost host) {
        return HostInfo.builder()
            .id(host.getHostid())
            .name(host.getHost())
            .ip(host.getInterfaces().get(0).getIp())
            .build();
    }
}
```

### 5. Facade (퍼사드)
**용도**: 복잡한 서브시스템을 단순한 인터페이스로 제공

```java
@Service
@RequiredArgsConstructor
public class ReportFacade {
    private final DataCollector dataCollector;
    private final ReportGenerator reportGenerator;
    private final NotificationService notificationService;

    // 복잡한 리포트 생성 과정을 단순화
    public void generateAndSendReport(ReportRequest request) {
        List<Data> data = dataCollector.collect(request);
        Report report = reportGenerator.generate(data);
        notificationService.send(report);
    }
}
```

### 6. Decorator (데코레이터)
**용도**: 객체에 동적으로 기능 추가

```java
// 로깅 데코레이터 예시
public class LoggingServiceDecorator implements ApiService {
    private final ApiService delegate;
    private final Logger log = LoggerFactory.getLogger(this.getClass());

    @Override
    public Response call(Request request) {
        log.info("API 호출 시작: {}", request);
        Response response = delegate.call(request);
        log.info("API 호출 완료: {}", response.getStatus());
        return response;
    }
}
```

---

## 행위 패턴 (Behavioral Patterns)

### 7. Strategy (전략)
**용도**: 알고리즘을 캡슐화하여 교체 가능하게 함

```java
public interface RetryStrategy {
    boolean shouldRetry(int attempt, Exception e);
    long getDelay(int attempt);
}

@Component
public class ExponentialBackoffStrategy implements RetryStrategy {
    @Override
    public boolean shouldRetry(int attempt, Exception e) {
        return attempt < 3 && isRetryable(e);
    }

    @Override
    public long getDelay(int attempt) {
        return (long) Math.pow(2, attempt) * 1000; // 2초, 4초, 8초
    }
}
```

### 8. Template Method (템플릿 메서드)
**용도**: 알고리즘의 골격을 정의하고 일부 단계를 서브클래스에서 구현

```java
public abstract class AbstractDataProcessor {
    // 템플릿 메서드
    public final void process() {
        validate();
        Data data = fetch();
        Data transformed = transform(data);
        save(transformed);
        notify();
    }

    protected abstract Data fetch();
    protected abstract Data transform(Data data);

    // 공통 구현
    protected void validate() { /* 기본 검증 */ }
    protected void save(Data data) { /* 기본 저장 */ }
    protected void notify() { /* 기본 알림 */ }
}
```

### 9. Observer (옵저버)
**용도**: 상태 변화를 다른 객체에 자동 통지

```java
// Spring Event 활용
@Component
public class EventPublisher {
    @Autowired
    private ApplicationEventPublisher publisher;

    public void publishIncident(Incident incident) {
        publisher.publishEvent(new IncidentCreatedEvent(incident));
    }
}

@Component
public class SlackNotifier {
    @EventListener
    public void onIncidentCreated(IncidentCreatedEvent event) {
        // Slack 알림 발송
    }
}

@Component
public class EmailNotifier {
    @EventListener
    public void onIncidentCreated(IncidentCreatedEvent event) {
        // 이메일 알림 발송
    }
}
```

### 10. Chain of Responsibility (책임 연쇄)
**용도**: 요청을 처리할 수 있는 객체를 체인으로 연결

```java
public interface ValidationHandler {
    void setNext(ValidationHandler next);
    void validate(Request request);
}

public abstract class AbstractValidationHandler implements ValidationHandler {
    protected ValidationHandler next;

    @Override
    public void setNext(ValidationHandler next) {
        this.next = next;
    }

    protected void validateNext(Request request) {
        if (next != null) {
            next.validate(request);
        }
    }
}

// 사용: 인증 → 권한 → 데이터 검증 체인
```

---

## 패턴 선택 가이드

| 상황 | 권장 패턴 |
|------|----------|
| 객체 생성이 복잡하거나 파라미터가 많음 | Builder |
| 타입에 따라 다른 객체 생성 | Factory |
| 외부 시스템 연동 | Adapter |
| 복잡한 작업 흐름 단순화 | Facade |
| 알고리즘 교체 필요 | Strategy |
| 상태 변화 알림 필요 | Observer (Spring Event) |
| 단계별 처리 | Template Method |
| 검증/필터 체인 | Chain of Responsibility |

---

## Anti-Patterns (피해야 할 패턴)

### 1. God Object
- 하나의 클래스가 너무 많은 책임을 가짐
- **해결**: 단일 책임 원칙(SRP) 적용, 클래스 분리

### 2. Magic Numbers/Strings
```java
// Bad
if (status.equals("20")) { ... }

// Good
private static final String STATUS_COMPLETED = "20";
if (status.equals(STATUS_COMPLETED)) { ... }
```

### 3. Copy-Paste Programming
- 중복 코드 복사
- **해결**: 공통 메서드/클래스로 추출

### 4. Premature Optimization
- 필요 없는 최적화
- **해결**: 먼저 동작하게, 프로파일링 후 최적화

---

## 적용 시점
- 새로운 기능 설계 시 적합한 패턴 검토
- 코드 리뷰 시 패턴 적용 가능 여부 확인
- 리팩토링 시 Anti-Pattern 제거

---

관련: [<YOUR_ORG> 스타일](kt-cloud-style.md) · [SRE 코딩](sre-coding.md) · [MyBatis](mybatis-sql-patterns.md) · [코드 리뷰 함정](code-review-traps.md)
