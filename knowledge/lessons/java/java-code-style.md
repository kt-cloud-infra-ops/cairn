---
tags:
  - type/guide
  - domain/java
  - audience/claude
---

> 상위: [java](README.md) · [lessons](../README.md)

# Java 코드 스타일 가이드

## 날짜
2026-01-22

## 프로젝트
전체 Java 프로젝트

## 출처 문서
- Java 코드 스타일 가이드 (intellij_formatter.xml / checkstyle.xml 기반)

---

# 1. 파일 (File)

## 1-1. 파일 인코딩

### UTF-8

모든 소스, 텍스트 문서 파일의 인코딩은 UTF-8로 통일한다.

## 1-2. 파일 새줄 형식

### LF 형식

Unix 형식의 새줄(newLine)인 LF(Line Feed, 0x0A)을 사용한다.

Window 형식인 CRLF가 섞이지 않도록 편집기와 Git설정 등을 확인한다.

### 마지막 새줄

파일의 마지막은 새줄 문자 LF로 끝나야 한다.

---

# 2. 이름 (Naming)

## 2-1. 이름 규칙

### 식별자에는 영문/숫자/언더스코어만 허용

변수명, 클래스명, 메서드명 등에는 영어와 숫자만을 사용한다.

상수에는 단어 사이의 구분을 위하여 언더스코어( _ )를 사용한다.

정규 표현식 [^A-Za-z0-9_]에 부합해야 한다.

### 한국어 발음대로의 표기 금지

한글 발음을 영어로 옮겨서 표기하지 않는다.

한국어 고유명사는 예외이다.

`예) "무형자산" 이름의 변수명`

```java
// 나쁜 예
moohyungJasan

// 좋은 예
intangibleAssets
```

### 대문자로 표기할 약어 명시

프로젝트 내에서 정의한 단어 목록이 없다면, 기본적으로 약어의 중간 단어를 소문자로 표기하도록 한다.

`예) "HTTP + API + URL" 클래스 이름`

```java
// 나쁜 예
HTTPAPIURL.java

// 좋은 예
HttpApiUrl.java
```

`예) 프로젝트 내, 정의한 단어`

```java
// 좋은 예
VPC.java
```

## 2-2. 패키지 이름

### 패키지 이름은 소문자로 구성

패키지 이름은 소문자를 사용하여 작성한다.

단어별 구분을 위해 언더스코어( _ )나 대문자를 섞지 않는다.

`예) "API Gateway" 패키지 이름`

```java
// 나쁜 예
package com.<your_org>.apiGateway
package com.<your_org>.ApiGateway
package com.<your_org>.api_gateway

// 좋은 예
package com.<your_org>.apigateway
```

## 2-3. 클래스 이름

### 파스칼 표기법(Pascal Case) 적용

클래스 이름은 단어의 첫 글자를 대문자로 시작하는 파스칼 표기법을 사용한다.

`예) "reservation" 클래스 이름`

```java
// 나쁜 예
public class reservation

// 좋은 예
public class Reservation
```

### 클래스 이름은 명사 사용

클래스 이름은 명사나 명사절로 짓는다.

## 2-4. 인터페이스 이름

### 인터페이스 이름은 명사/형용사 사용

인터페이스(Interface)의 이름은 명사/명사절로 혹은 형용사/형용사절로 짓는다.

`예) "Click" 기능 관련, 인터페이스 이름`

```java
// 나쁜 예
public interface Click

// 좋은 예
public interface Clickable
```

## 2-5. 메소드 이름

### 카멜 표기법(Camel Case) 적용

메소드 이름은 첫 번째 단어를 소문자로 작성하고, 이어지는 단어의 첫 글자를 대문자로 작성한다.

`예) "read message" 메소드 이름`

```java
// 나쁜 예
public void ReadMessage()

// 좋은 예
public void readMessage()
```

### 메소드 이름은 동사/전치사로 시작

메소드 이름은 기본적으로는 동사로 시작한다.

다른 타입으로 전환하는 메소드나 빌더 패턴을 구현한 클래스의 메소드에는 전치사를 쓸 수 있다.

`예) 메소드 이름은 동사, 전치사 시작`

```java
// 나쁜 예
html()

// 좋은 예
(동사 시작) renderHtml()
(타입 변환 - 전치사 시작) toString()
(Builder 패턴 - 전치사 시작) withUserId(String id)
```

## 2-6. 상수 이름

### 대문자와 언더스코어로 구성

상태를 가지지 않는 자료형이면서 static final 로 선언되어 있는 필드일 때를 상수로 간주한다.

상수 이름은 대문자로 작성하며, 복합어는 언더스코어( _ )를 사용하여 단어를 구분한다.

`예) "Rest API Version" 상수 이름`

```java
// 나쁜 예 (잘못된 변수 이름 & 상수 선언 시, static final 미선언)
public static final String RestApiVersion = "/api/v1";
private String REST_API_VERSION = "/api/v1";

// 좋은 예
public static final String REST_API_VERSION = "/api/v1";
```

## 2-7. 변수 이름

### 카멜 표기법(Camel Case) 적용

상수가 아닌 클래스의 멤버변수/지역변수/메소드 파라미터에는 카멜 표기법을 사용한다.

`예) "access token" 변수 이름`

```java
// 나쁜 예
private String AccessToken;

// 좋은 예
private String accessToken;
```

### 임시 변수 외에는 1글자 금지

메소드 블럭 범위 이상의 생명 주기를 가지는 변수에는 1글자로 된 이름을 쓰지 않는다.

반복문의 인덱스나 람다 표현식의 파라미터 등 짧은 범위의 임시 변수에는 관례적으로 1글자 변수명을 사용할 수 있다.

`예) ServerEntity 객체 변수 이름`

```java
// 나쁜 예
ServerEntity s = new ServerEntity();

// 좋은 예
ServerEntity serverEntity = new ServerEntity();
```

`예) method 파라미터 이름`

```java
// 나쁜 예
public void example(Throwable t);

// 좋은 예
public void example(Throwable throwable);
```

`예) 반복문/람다 표현식`

```java
// 좋은 예 (반복문)
for (int i = 0; i < 10; i++)

// 좋은 예 (람다 표현식)
resMap.computeIfAbsent(
    key,
    (v) -> {return v}
);
```

---

# 3. 선언 (Declarations)

## 3-1. 탑 레벨 클래스 선언

### 소스 파일 하나당 탑클래스는 1개

소스 파일에는 1개에는 탑레벨 클래스(Top-level Class)만 존재해야 한다.

`예) "LogParser.java" 소스 파일`

```java
// 나쁜 예 (한개의 소스파일에 class 2개)
public class LogParser {
  ...
}

public class LogType {
  ...
}


// 좋은 예 (nested class)
public class LogParser {
  ...
    public static class LogType {
        ...
    }
}
```

## 3-2. 임포트(import) 선언

### import 선언 순서

import 구절은 아래와 같은 순서로 그룹을 묶어서 선언한다.

1. java.*
2. javax.*
3. jakarta.*
4. net.*
5. org.*
6. com.*
7. (1~6) 제외 나머지
8. static import

각 그룹 사이에는 빈 줄을 삽입한다.

같은 그룹 내에서는 알파벳 순으로 정렬한다.

대부분의 IDE에서 자동으로 정리해주기 때문에, IDE 설정을 변경하지 않도록 주의한다.

`예) 패키지 import 순서 예시`

```java
// 좋은 예
import java.util.List;

import javax.annotation.Notnull;

import jakarta.validation.Valid;

import net.javacrumbs.shedlock.spring.annotation.SchedulerLock;

import org.json.JSONArray;
import org.json.JSONObject;
import org.springframework.stereotype.Service;

import com.<your_org>.request.RequestDto;
import com.<your_org>.response.ResponseDto;

import static org.springframework.data.domain.ExampleMatcher.*;
```

### Import / Static Import 와일드 카드

클래스를 Import 할때는 와일드 카드( * ) 없이 모든 클래스명을 다 쓴다.

Static Import 에서는 와일드 카드를 허용한다.

`예) "List", "ArrayList" import 할 때, 클래스명 명시`

```java
// 나쁜 예
import java.util.*;

// 좋은 예
import java.util.List;
import java.util.ArrayList;
```

`예) static import 은 와일드 카드 허용`

```java
// 좋은 예
import static java.lang.Math.*;
```

## 3-3. 제한자 선언

### 제한자 선언의 순서

클래스/메소드/멤버변수의 제한자는 Java Language Specification에서 명시한 아래의 순서로 쓴다.

`예) 제한자 선언 순서`

```java
public protected private abstract static final transient volatile synchronized native strictfp
```

## 3-4. 문장 선언

### 한 줄에 한 문장

문장이 끝나는 세미콜론( ; ) 뒤에는 새줄을 삽입한다.

한줄에 여러 문장을 쓰지 않는다.

`예) 한 줄에 여러개의 변수 선언`

```java
// 나쁜 예
int height = 0; int weight = 2;

// 좋은 예
int height = 0;
int weight= 2;
```

## 3-5. 변수 선언

### 하나의 선언 문에는 하나의 변수만

변수 선언문은 한 문장에서 하나의 변수만을 다룬다.

`예) 변수 선언`

```java
// 나쁜 예
int base, weight;

// 좋은 예
int base;
int weight;
```

## 3-6. 배열 선언

### 대괄호 타입 뒤에 선언

배열 선언에 오는 대괄호( [ ] )는 타입의 바로 뒤에 붙인다.

변수명 뒤에 붙이지 않는다.

`예) 배열 선언`

```java
// 나쁜 예
String names[];

// 좋은 예
String[] names;
```

## 3-7. long 선언

### L 붙이기

long형의 숫자에는 마지막에 대문자 "L"을 붙인다.

소문자 "l"과 숫자 "1" 간의 가독성을 높일 수 있다.

`예) long type 선언`

```java
// 나쁜 예
long example = 544232324211l;

// 좋은 예
long example = 5442323241221L;
```

## 3-8. 특수 문자 선언

### 전용 선언 방식을 활용

\b, \f, \n, \r, \t, \, \\ 와 같이 특별히 정의된 선언 방식이 있는 특수 문자가 있다.

옥텟(\012) 이나 유니코드(
) 과 같은 방식을 사용하지 않는다.

`예) 줄바꿈 선언`

```java
// 나쁜 예
System.out.println("---\012---");

// 좋은 예
System.out.println("---\n---");
```

---

# 4. 들여쓰기 (Indentation)

## 4-1. 하드탭 사용

### 하드 탭으로 들여 쓰기

탭(Tab) 문자를 사용하여 들여 쓴다.

탭 대신 스페이스를 사용하지 않는다.

## 4-2. 탭 크기

### 4개의 스페이스바

1개의 탭의 크기는 스페이스 4개와 같도록 사용 및 설정한다.

## 4-3. 블럭 들여쓰기

### 블럭당 들여쓰기 뎁스

클래스, 메서드, 제어문 등의 코드 블럭이 생길 때마다 1단계를 더 들여쓴다.

---

# 5. 중괄호 (Braces)

## 5-1. K&R 스타일

### K&R 스타일로 중괄호 선언

중괄호 선언은 K&R 스타일(Kernighan and Ritchie style)을 따른다.

줄의 마지막에서 시작 중괄호( { )를 쓰고 열고 새줄을 삽입한다. 블럭을 마친후에는 새줄 삽입 후 중괄호를 닫는다.

`예) K&R 스타일 중괄호`

```java
// 나쁜 예
public class SearchConditionParser
{
    public boolean isValidExpression(String exp)
    {
        if (exp == null)
        {
            return false;
        }

        for (char ch : exp.toCharArray())
        {
             ....
        }

        return true;
    }
}

// 좋은 예
public class SearchConditionParser {
    public boolean isValidExpression(String exp) {
        if (exp == null) {
            return false;
        }

        for (char ch : exp.toCharArray()) {
            ....
        }

        return true;
    }
}
```

## 5-2. 연속된 블럭

### else, catch, finally, while 선언

아래의 키워드는 닫는 중괄호( } ) 와 같은 줄에 쓴다.

- else
- catch, finally
- do-while 문에서의 while

`예) if-else 문`

```java
// 나쁜 예
if (line.startWith(WARNING_PREFIX)) {
    return LogPattern.WARN;
}
else if (line.startWith(DANGER_PREFIX)) {
    return LogPattern.DANGER;
}
else {
    return LogPattern.NORMAL;
}

// 좋은 예
if (line.startWith(WARNING_PREFIX)) {
    return LogPattern.WARN;
} else if (line.startWith(DANGER_PREFIX)) {
    return LogPattern.NORMAL;
} else {
    return LogPattern.NORMAL;
}
```

`예) try-catch 문`

```java
// 나쁜 예
try {
    writeLog();
}
catch (IOException ioe) {
    reportFailure(ioe);
}
finally {
    writeFooter();
}

// 좋은 예
try {
    writeLog();
} catch (IOException ioe) {
    reportFailure(ioe);
} finally {
    writeFooter();
}
```

`예) do-while 문`

```java
// 나쁜 예
do {
    write(line);
    line = readLine();
}
while (line != null);

// 좋은 예
do {
    write(line);
    line = readLine();
} while (line != null);
```

## 5-3. 빈 블럭

### 빈 블럭은 새줄없이 허용

내용이 없는 블럭을 선언 할 때는 같은 줄에서 중괄호를 닫는 것을 허용한다.

`예) 내용이 없는 빈블럭`

```java
// 좋은 예
public void close() {}
```

## 5-4. 생략 불가

### if/else 에 생략 금지

조건, 반복문이 한 줄로 끝더라도 중괄호를 활용한다.

`예) if-else 문 생략 금지`

```java
// 나쁜 예
if (exp == null) return false;
for (char ch : exp.toCharArray()) if (ch == 0) return false;

// 좋은 예
if (exp == null) {
    return false;
}

for (char ch : exp.toCharArray()) {
    if (ch == 0) {
        return false;
    }
}
```

---

# 6. 줄 바꿈 (Line-warpping)

## 6-1. 최대 너비

### 최대 너비는 120

최대 줄 사용 너비는 120자 이다.

## 6-2. 패키지, 임포트 줄 바꿈

### package, import 선언문은 줄 바꿈 금지

package,import 선언문 중간에서는 줄을 바꾸지 않는다.

최대 줄수를 초과하더라도 한 줄로 쓴다.

## 6-3. 줄 바꿈 허용 위치

### 허용 위치

가독성을 위해, 줄을 바꾸는 위치는 다음 중의 하나로 한다.

- extends 선언 전
- implements 선언 전
- throws 선언 전
- 여는 소괄호 ( ( ) 선언 후
- 콤마( , ) 후
- 닷( . ) 전
- 삼항 연산자
  - ? 선언 후
  - : 선언 후
- 연산자 전
  - +, -, *, /, %
  - ==, !=, >=, >, <=, <, &&, ||
  - &,|, ^, >>>, >>, <<, ?
  - instanceof

`예) 줄바꿈 허용 위치`

```java
// 좋은 예

public class ThisIsASampleClass
        extends C1
        implements I1, I2, I3, I4, I5 {

    public boolen isAbnormalAccess(User user,
            AccessLog log) {

        String message =
                (true) ?
                        user
                                .getId()
                                + "|"
                                | log.getPrefix()
                                + "|" + SUFFIX :
                        null;
    }

    public static void test()
            throws Exception {

        foo.foo().bar("arg1", "arg2");
    }
}
```

## 6-4. 줄 바꿈 이후 들여쓰기

### 추가 들여쓰기

줄바꿈 이후 이어지는 줄에서는 최초 시작한 줄에서보다 적어도 1단계의 들여쓰기를 더 추가한다.

`예) 줄바꿈 이후, 들여쓰기`

```java
// 나쁜 예
AbstractAggregateRootTest.AggregateRoot proxyAggregateRoot =
em.getReference(AbstractAggregateRootTest.AggregateRoot.class, aggregateRoot.getId());

// 좋은 예
AbstractAggregateRootTest.AggregateRoot proxyAggregateRoot =
        em.getReference(AbstractAggregateRootTest.AggregateRoot.class, aggregateRoot.getId());
```

## 6-5. 람다 표현식 줄바꿈

람다(lambda) 표현식에서 가독성을 위해 줄바꿈이 필요할 경우, 여는 중괄호 ( ( ) 이후에 줄바꿈을 한다.

`예) 람다 표현식은 여는 중괄호 이후, 줄바꿈`

```java
// 나쁜 예
Optional.of("example")
        .ifPresentOrElse(e -> {
                log.info("present: {}", e);
        },
        () -> {
                throw new NullPointerException();
        });

// 좋은 예 (줄바꿈이 필요할 때)
Optional.of("example")
        .ifPresentOrElse(
                e -> {
                    log.info("present: {}", e);
                },
                () -> {
                    throw new NullPointerException();
                });

// 좋은 예 (줄바꿈이 필요하지 않을 때)
Optional.of("example")
        .ifPresent(e -> log.info("present: {}", e));
```

---

# 7. 빈 줄 (Blank lines)

## 7-1. 패키지

### package 선언 후 빈 줄 삽입

package 선언 후, 빈 줄을 삽입한다.

`예) 패키지 선언 이후, 줄바꿈`

```java
// 나쁜 예
package com.example.util;
import java.util.Date;
import java.util.List;

// 좋은 예
package com.example.util;

import java.util.Date;
import java.util.List;
```

## 7-2. 임포트

### 임포트 그룹별 빈 줄 삽입

import 는 그룹별 빈 줄을 삽입한다.

"3-2. 임포트(import) 선언" 의 import 선언을 참고한다.

## 7-3. 메소드

### 메소드 선언 후 빈 줄 삽입

메서드의 선언이 끝난 후 다음 메서드 선언이 시작되기 전에 빈줄을 1줄을 삽입한다.

`예) 메소드가 끝난 이후, 줄바꿈`

```java
// 나쁜 예
public void setId(int id) {
    this.id = id;
}
public void setName(String name) {
    this.name = name;
}

// 좋은 예
public void setId(int id) {
    this.id = id;
}

public void setName(String name) {
    this.name = name;
}
```

---

# 8. 공백 (Whitespace)

## 8-1. 공백 규칙

### 공백으로 줄을 끝내지 않음

빈줄을 포함하여 모든 줄은 탭이나 공백으로 끝내지 않는다.

## 8-2. 대괄호

### 대괄호 뒤에 공백 삽입

닫는 대괄호( ] ) 뒤에 `;`으로 문장이 끝나지 않고 다른 선언이 올 경우 공백을 삽입한다.

`예) [] 이후, 공백 삽입`

```java
// 나쁜 예
int[]masks = new int[]{0, 1, 1};

// 좋은 예
int[] masks = new int[] {0, 1, 1};
```

## 8-3. 중괄호

### 시작 전, 종료 후에 공백 삽입

여는 중괄호( { ) 앞에는 공백을 삽입한다.

닫는 중괄호( } ) 뒤에 else ,catch 등의 키워드가 있을 경우 중괄호와 키워드 사이에 공백을 삽입한다.

`예) if() 이후 시작에 공백 삽입, 선언이 끝나고 이어지는 키워드 앞에 공백 삽입`

```java
// 좋은 예
public void printWarnMessage(String line) {
    if (line.startsWith(WARN_PREFIX)) {
        ...
    } else {
        ...
    }
}
```

## 8-4. 소괄호

### 제어문 키워드

if, for, while, catch, synchronized, switch와 같은 제어문 키워드의 뒤에 소괄호( () )를 선언하는 경우, 시작 소괄호 앞에 공백을 삽입한다.

`예) if 문 시작할 때, () 앞에 공백 삽입`

```java
// 나쁜 예
if(maxLine > LIMITED) {
    return false;
}

// 좋은 예
if (maxLine > LIMITED) {
    return false;
}
```

### 식별자

식별자와 여는 소괄호( ( ) 사이에는 공백을 삽입하지 않는다.

생성자와 메서드의 선언, 호출, 애너테이션 선언 뒤에 쓰이는 소괄호가 그에 해당한다.

`예) 생성자의 () 앞에 공백 미삽입`

```java
// 나쁜 예
public StringProcessor () {}

// 좋은 예
public StringProcessor() {}
```

`예) 어노테이션의 () 앞에 공백 미삽입`

```java
// 나쁜 예
@Cached ("local")
public String removeEndingDot (String original) {
    assertNotNull (original);
    ...
}

// 좋은 예
@Cached("local")
public String removeEndingDot(String original) {
    assertNotNull(original);
    ...
}
```

### 타입 캐스팅

타입 캐스팅을 위해 선언한 소괄호의 내부에는 공백을 삽입하지 않는다.

`예) 타입 캐스팅 () 안에 공백 미삽입`

```java
// 나쁜 예
String message = ( String ) rawLine;

// 좋은 예
String message = (String)rawLine;
```

## 8-5. 산괄호

### 제너릭 산괄호

제네릭스(Generics) 선언에 쓰이는 산괄호(<,>) 주위의 공백은 다음과 같이 처리한다.

- 제네릭스 메서드 선언 일 때만 < 앞에 공백을 삽입한다.
- < 뒤에 공백을 삽입하지 않는다.
- '>' 앞에 공백을 삽입하지 않는다.
- 아래의 경우를 제외하고는 '>' 뒤에 공백을 삽입한다.
  - 메서드 레퍼런스가 바로 이어질 때
  - 여는 소괄호( ( )가 바로 이어질 때
  - 메서드 이름이 바로 이어질 때

`예) 제너릭 산괄호 선언`

```java
// 좋은 예
public static <A extends Annotation> A find(AnnotatedElement elem, Class<A> type) { // 제네릭스 메서드 선언 시, < 앞에 공백 삽입
    List<Integer> exampleBrace = new ArrayList<>(); // '(' 가 바로 이어질때, 공백 미삽입
    List<String> exampleMethodReference = ImmutableList.Builder<String>::new; // 메서드 레퍼런스가 바로 이어질 때, 공백 미삽입
    int diff = Util.<Integer, String>compare(l1, l2); // 메서드 이름이 바로 이어질 때, 공백 미삽입
}
```

## 8-6. 구분자

### 쉼표(,)

콤마( , ) 뒤에는 공백을 삽입한다.

`예) 함수의 파라미터`

```java
// 나쁜 예
display(level,message,i)

// 좋은 예
display(level, message, i)
```

### 콜론(:)

삼항 연산자와 반복문의 콜론(:)의 앞 뒤에는 공백을 삽입한다.

이때, switch-case 문에서의 콜론(:) 앞에는 예외적으로 공백을 미삽입한다.

`예) 삼항연산자와 switch 문`

```java
// 좋은 예 (for 문, 삼항연산자, switch-case 문)
for (Customer customer : visitedCustomers) {
    AccessPattern pattern = isAbnormal(accessLog) ? AccessPattern.ABUSE : AccessPattern.NORMAL;
    int grade = evaluate(customer, pattern);

    switch (grade) {
        case GOLD:
            sendSms(customer);
        case SILVER:
            sendEmail(customer);
        default:
            inreasePoint(customer)
    }
}
```

### 세미콜론(;)

반복문(while, for)의 구분자로 쓰이는 세미콜론(;)에는 뒤에만 공백을 삽입한다.

`예) 반복문 선언`

```java
// 나쁜 예
for (int i = 0;i < length;i++) {
    ...
}

// 좋은 예
for (int i = 0; i < length; i++) {
    ...
}
```

## 8-7. 연산자

### dot(.) 연산자

닷 ( . ) 연산자 전후에는 공백을 삽입하지 않는다.

`예) 닷 연산자 전후, 공백 미삽입`

```java
// 나쁜 예
list . stream()

// 좋은 예
list.stream()
```

### 2개 콜론 (::)

2개의 콜론 ( :: ) 전후에는 공백을 삽입하지 않는다.

`예) 2개의 콜론 전후에 공백 미삽입`

```java
// 나쁜 예
streamObject.map(this :: convert)

// 좋은 예
streamObject.map(this::convert)
```

### 람다식 화살표 (->)

람다식 화살표 ( -> ) 전후에는 공백을 삽입한다.

`예) 람다 전후에 공백 삽입`

```java
// 나쁜 예
streamObject.filter(t->true)

// 좋은 예
streamObject.filter(t -> true)
```

### 이항/삼항 연산자

이항/삼항 연산자의 앞 뒤에는 공백을 삽입한다.

`예) 이항(산술,비교,논리,할당,비트 연산)/삼항 연산자 전후에 공백 삽입`

```java
// 좋은 예

if (pattern == Access.ABNORMAL) {
    return 0;
}

finalScore += weight * rawScore - absentCount;

if (finalScore > MAX_LIMIT) {
    return MAX_LIMIT;
}

return (finalScore == 0) ? -1 : finalScore
```

### 단항 연산자

단항 연산자와 연산 대상의 사이에는 공백을 삽입하지 않는다.

`예) 단항 연산자(index 전, rank 후) 공백 미삽입`

```java
// 나쁜 예
int point = score[++ index] * rank -- * - 1;

// 좋은 예
int point = score[++index] * rank-- * -1;
```

## 8-8. 가로 맞춤

### 가로 맞춤 금지

가로 맞춤은 때때로 가독성을 높여 주지만, 유지 보수 측면에서는 문제를 일으킨다.

따라서, 가로 맞춤은 허용되지 않는다.

`예) 가로 맞춤 미허용`

```java
// 나쁜 예
private   int      x;
private   Color    color;

// 좋은 예
private int x;
private Color color;
```

---

# 9. 주석 (Comment)

## 9-1. 주석문 규칙

### File and Code Template

Class 또는 파일 최상 위에 설명을 위한 내용을 작성함.

`예) 작성 예시`

```java
/**
 * (설명)
 * @since 1.0.0
 * @author author@example.com
 */
```

### Method Comment

Method 단위에서는 Comment 생성을 단축키 /** <enter> 사용으로 자동 생성이 됨.

`예) 작성 예시`

```java
/**
 * (설명)
 * @param request
 * @return
 */
```

### 주석문 공백

주석의 전후에는 아래와 같이 공백을 삽입한다.

- 명령문과 같은 줄에 주석을 붙일 때 // 앞
- 주석 시작 기호 // 뒤
- 주석 시작 기호 /* 뒤
- 블록 주석을 한 줄로 작성시 종료 기호 */ 앞

`예) 주석에서의 공백`

```java
// 좋은 예

/*
 * 공백 후 주석내용 시작
 */

System.out.print(true); // 주석 기호 앞 뒤로 공백

/* 주석내용 앞에 공백, 뒤에도 공백 */
```

## 9-2. TODO 주석

### TODO 주석 규칙

TODO 주석을 commit/push 하는 것을 지양한다.

하지만, 사용할 경우 대문자 TODO 와 콜론 ( : ) 및 공백을 포함해야한다.

추가적으로, 전달 사항이 있어 언급할때에는 콜론( : ) 뒤에 @사용자ID 으로 주석을 남긴다.

`예) TODO 주석 예시`

```java
// 나쁜 예

//todo-removethis line



// 좋은 예

// TODO: Remove This Line
// TODO: @user123 Remove This Line
```

---

# 10. Next 프로젝트 확장 규칙

Next 프로젝트 내, Java 언어의 백엔드 개발은 본 문서의 규칙들을 기본적으로 준수한다.

"Java 코드 스타일(1. 파일 ~ 9.주석)" 규칙에 추가적으로 아래 사항을 권고한다.

## 10-1. 이름 접두사/접미사 규칙

### 이넘(Enum) 이름 규칙

enum 타입의 이름 앞에는 접두사로 대문자 "E"를 작성한다.

`예) enum 이름 규칙`

```java
// 나쁜 예
UserRole.java

// 좋은 예
EUserRole.java
```

### 인터페이스(Interface) 이름 규칙

interface 타입의 이름 앞에는 접두사로 대문자 "I"를 작성한다.

`예) interface 이름 규칙`

```java
// 나쁜 예
Clickable.java

// 좋은 예
IClickable.java
```

### 엔티티(Entity) 이름 규칙

DB와 매핑되는 Entity의 이름 뒤에는 접미사로 "Entity" 을 작성한다.

`예) Entity 이름 규칙`

```java
// 나쁜 예
User.java

// 좋은 예
UserEntity.java
```

### Configuration 이름 규칙

애플리케이션 관련 설정 또는 그 외 동작에 필요한 설정 사항의 이름 뒤에는 접미사 "Configuration"을 작성한다.

`예) configuration 이름 규칙`

```java
// 나쁜 예
KafkaConfig.java

// 좋은 예
KafkaConfiguration.java
```

### AOP 이름 규칙

AOP(aspect-oriented programming)을 위한, SpringAOP 이름 뒤에는 접미사 "Aspect"를 작성한다.

`예) SpringAOP 이름 규칙`

```java
// 나쁜 예
AccessLogger.java

// 좋은 예
AccessLoggerAspect.java
```

---

## 요약 테이블

| 항목 | 규칙 |
|------|------|
| 인코딩 | UTF-8 |
| 새줄 | LF |
| 들여쓰기 | 하드탭 (4 spaces) |
| 최대 줄 너비 | 120자 |
| 중괄호 | K&R 스타일 |
| 클래스명 | PascalCase |
| 메서드/변수명 | camelCase |
| 상수명 | UPPER_SNAKE_CASE |
| 패키지명 | 소문자 only |
| Enum | E 접두사 |
| Interface | I 접두사 |
| Entity | Entity 접미사 |
| Configuration | Configuration 접미사 |
| AOP | Aspect 접미사 |

---

관련: [디자인 패턴](design-patterns.md) · [SRE 코딩](sre-coding.md) · [MyBatis](mybatis-sql-patterns.md) · [코드 리뷰 함정](code-review-traps.md)
