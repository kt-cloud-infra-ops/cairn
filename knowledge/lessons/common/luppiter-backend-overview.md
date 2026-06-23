---
tags:
  - type/guide
  - domain/java/spring
  - service/luppiter
  - audience/claude
---

> 상위: [common](README.md) · [lessons](../README.md)

# 학습: Luppiter 백엔드 프로젝트들

## 날짜
2026-01-19

## 프로젝트
luppiter_inv, luppiter_scheduler

---

## luppiter_inv (Spring Boot API)

### 개요
- **목적**: 외부 인벤토리 전달 API
- **Stack**: Spring Boot 2.7.9, Java 17, PostgreSQL
- **Port**: 8081

### 프로젝트 구조
```
luppiter_inv/
├── src/main/java/com/framework/
│   ├── ProjectApplication.java
│   ├── controller/
│   │   └── ApiController.java
│   ├── service/
│   │   └── ApiService.java
│   └── mapper/
│       └── ApiMapper.java
├── src/main/resources/
│   ├── application.properties
│   └── mapper/ApiMapper.xml
└── pom.xml
```

### 패키지 구조
- `com.framework` 패키지 사용 (luppiter-web과 동일)
- Controller → Service → Mapper 레이어 구조

### API 엔드포인트
```
POST /ext/api/host-manage/list
```

**Request:**
```json
{
  "searchHostName": "호스트명",
  "searchHostIP": "IP주소",
  "filterLayerL1": "L1 코드",
  "searchStartDate": "2024-01-01",
  "searchEndDate": "2024-12-31"
}
```

**Response:**
```json
{
  "result_code": 200,
  "message": "success",
  "total_count": 10,
  "data": [...]
}
```

### 빌드 및 실행
```bash
mvn clean package
mvn spring-boot:run
# 또는
java -jar target/luppiter_web-2.0.0.war
```

---

## luppiter_scheduler (Java/Maven)

### 개요
- **목적**: 스케줄링 작업 처리
- **Stack**: Java, Maven

### 프로젝트 구조
```
luppiter_scheduler/
├── cmdscript/          # 명령어 스크립트
├── config/             # 설정 파일
├── DDML/               # DDML 관련
├── luppiter_scheduler/ # 메인 소스
├── service/            # 서비스 관련
├── src/                # Java 소스
└── pom.xml
```

---

## 공통 인사이트

### Java 프로젝트 공통
- **패키지 구조**: `com.framework.{도메인}`
- **빌드 도구**: Maven
- **레이어**: Controller → Service → Mapper

### Spring Boot 프로젝트 특성
- **DB**: PostgreSQL (MyBatis Mapper XML)
- **응답 형식**: `result_code`, `message`, `data` 구조
- **날짜 검색**: `searchStartDate`, `searchEndDate` 패턴

### 적용 시점
- luppiter 관련 백엔드 API 개발 시 참고
- 외부 API 연동 시 응답 형식 참고
- 스케줄러 작업 추가 시 luppiter_scheduler 구조 참고
