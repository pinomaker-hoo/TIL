# Go 에러 처리

> Go는 try-catch 같은 예외 처리 대신, 에러를 값으로 반환하는 명시적인 에러 처리 방식을 사용한다. Go의 에러 처리 패턴과 관용적 사용법을 정리한다.

## 목차

1. [에러 처리 기본](#1-에러-처리-기본)
2. [에러 생성](#2-에러-생성)
3. [커스텀 에러 타입](#3-커스텀-에러-타입)
4. [에러 래핑 (Error Wrapping)](#4-에러-래핑-error-wrapping)
5. [errors.Is와 errors.As](#5-errorsis와-errorsas)
6. [panic과 recover](#6-panic과-recover)
7. [에러 처리 베스트 프랙티스](#7-에러-처리-베스트-프랙티스)
8. [핵심 요약](#8-핵심-요약)

---

## 1. 에러 처리 기본

Go에서 에러는 **함수의 마지막 반환값**으로 전달된다. `error` 인터페이스를 사용한다.

```go
// error 인터페이스 (내장)
type error interface {
    Error() string
}
```

### 기본 패턴

```go
import (
    "fmt"
    "os"
)

// 에러를 반환하는 함수
func readFile(path string) ([]byte, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }
    return data, nil
}

// 호출 측에서 에러 확인
data, err := readFile("config.json")
if err != nil {
    fmt.Println("파일 읽기 실패:", err)
    return
}
fmt.Println(string(data))
```

### 관용적 에러 처리

```go
// ✅ Go 관용적 패턴 - 에러를 먼저 처리하고 정상 흐름을 이어감
func processUser(id int) error {
    user, err := findUser(id)
    if err != nil {
        return fmt.Errorf("유저 조회 실패: %w", err)
    }

    err = validateUser(user)
    if err != nil {
        return fmt.Errorf("유저 검증 실패: %w", err)
    }

    err = saveUser(user)
    if err != nil {
        return fmt.Errorf("유저 저장 실패: %w", err)
    }

    return nil
}

// ❌ 안티 패턴 - 에러를 무시
data, _ := readFile("config.json")  // 에러 무시하면 안 됨!
```

---

## 2. 에러 생성

### errors.New

```go
import "errors"

func divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, errors.New("0으로 나눌 수 없습니다")
    }
    return a / b, nil
}
```

### fmt.Errorf

동적인 메시지를 포함하는 에러를 생성한다.

```go
import "fmt"

func findUser(id int) (*User, error) {
    // ...
    if user == nil {
        return nil, fmt.Errorf("ID %d인 유저를 찾을 수 없습니다", id)
    }
    return user, nil
}
```

### 센티널 에러 (Sentinel Error)

패키지 수준에서 미리 정의된 에러 변수이다.

```go
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
    ErrForbidden    = errors.New("forbidden")
    ErrInternal     = errors.New("internal server error")
)

func findUser(id int) (*User, error) {
    user := db.Find(id)
    if user == nil {
        return nil, ErrNotFound
    }
    return user, nil
}

// 호출 측에서 에러 비교
user, err := findUser(123)
if err == ErrNotFound {
    fmt.Println("유저를 찾을 수 없습니다")
}
```

---

## 3. 커스텀 에러 타입

`error` 인터페이스를 구현하면 어떤 타입이든 에러로 사용할 수 있다.

```go
// 커스텀 에러 타입
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("검증 오류 [%s]: %s", e.Field, e.Message)
}

func validateAge(age int) error {
    if age < 0 {
        return &ValidationError{
            Field:   "age",
            Message: "나이는 0 이상이어야 합니다",
        }
    }
    if age > 150 {
        return &ValidationError{
            Field:   "age",
            Message: "나이가 올바르지 않습니다",
        }
    }
    return nil
}

// HTTP 에러 타입
type HTTPError struct {
    StatusCode int
    Message    string
}

func (e *HTTPError) Error() string {
    return fmt.Sprintf("HTTP %d: %s", e.StatusCode, e.Message)
}

func fetchData(url string) ([]byte, error) {
    resp, err := http.Get(url)
    if err != nil {
        return nil, err
    }
    if resp.StatusCode != 200 {
        return nil, &HTTPError{
            StatusCode: resp.StatusCode,
            Message:    "요청 실패",
        }
    }
    // ...
}
```

---

## 4. 에러 래핑 (Error Wrapping)

Go 1.13부터 `%w` 포맷 동사로 에러를 래핑할 수 있다. 원본 에러 정보를 유지하면서 컨텍스트를 추가한다.

```go
func getUser(id int) (*User, error) {
    user, err := db.FindByID(id)
    if err != nil {
        // 원본 에러를 래핑하여 컨텍스트 추가
        return nil, fmt.Errorf("getUser(id=%d): %w", id, err)
    }
    return user, nil
}

func handleRequest(userID int) error {
    user, err := getUser(userID)
    if err != nil {
        return fmt.Errorf("요청 처리 실패: %w", err)
    }
    // ...
    return nil
}

// 에러 메시지 체인
// "요청 처리 실패: getUser(id=123): sql: no rows in result set"
```

### errors.Unwrap

래핑된 에러에서 원본 에러를 꺼낸다.

```go
import "errors"

wrappedErr := fmt.Errorf("래핑: %w", ErrNotFound)
original := errors.Unwrap(wrappedErr)
fmt.Println(original)  // "not found"
```

---

## 5. errors.Is와 errors.As

### errors.Is - 에러 값 비교

에러 체인에서 특정 에러 값이 포함되어 있는지 확인한다.

```go
var ErrNotFound = errors.New("not found")

func findItem(id int) error {
    return fmt.Errorf("findItem 실패: %w", ErrNotFound)
}

err := findItem(123)

// ❌ 직접 비교 - 래핑된 에러에서는 실패
if err == ErrNotFound {
    // 이 블록은 실행되지 않음!
}

// ✅ errors.Is - 에러 체인을 따라가며 비교
if errors.Is(err, ErrNotFound) {
    fmt.Println("아이템을 찾을 수 없습니다")
}
```

### errors.As - 에러 타입 변환

에러 체인에서 특정 타입의 에러를 추출한다.

```go
func processRequest() error {
    return fmt.Errorf("처리 실패: %w", &ValidationError{
        Field:   "email",
        Message: "유효하지 않은 이메일 형식",
    })
}

err := processRequest()

// errors.As로 커스텀 에러 타입 추출
var validErr *ValidationError
if errors.As(err, &validErr) {
    fmt.Printf("필드: %s, 메시지: %s\n", validErr.Field, validErr.Message)
    // 필드: email, 메시지: 유효하지 않은 이메일 형식
}
```

---

## 6. panic과 recover

`panic`은 프로그램을 즉시 중단시키는 비정상 상황에 사용한다. `recover`로 panic을 잡을 수 있다.

### panic

```go
// panic - 프로그램 중단 (일반적인 에러 처리에는 사용하지 않음!)
func mustParseConfig(path string) Config {
    data, err := os.ReadFile(path)
    if err != nil {
        panic(fmt.Sprintf("설정 파일 읽기 실패: %v", err))
    }
    // ...
}
```

### recover

```go
func safeFunction() {
    defer func() {
        if r := recover(); r != nil {
            fmt.Println("panic 복구:", r)
        }
    }()

    // panic 발생해도 프로그램이 중단되지 않음
    panic("something went wrong")
}

func main() {
    safeFunction()
    fmt.Println("프로그램이 계속 실행됩니다")
}
```

### panic 사용 지침

```go
// ✅ panic이 적절한 경우
// 1. 프로그램 초기화 실패 (설정 파일 없음, DB 연결 실패)
func init() {
    if os.Getenv("DATABASE_URL") == "" {
        panic("DATABASE_URL 환경 변수가 필요합니다")
    }
}

// 2. 발생하면 안 되는 프로그래밍 에러
func MustCompile(pattern string) *regexp.Regexp {
    re, err := regexp.Compile(pattern)
    if err != nil {
        panic(fmt.Sprintf("잘못된 정규식: %s", err))
    }
    return re
}

// ❌ panic이 부적절한 경우
// 일반적인 에러 (파일 없음, 네트워크 오류 등) → error 반환 사용
```

---

## 7. 에러 처리 베스트 프랙티스

### 1. 에러를 무시하지 말 것

```go
// ❌ 에러 무시
data, _ := json.Marshal(user)

// ✅ 에러 처리
data, err := json.Marshal(user)
if err != nil {
    return fmt.Errorf("JSON 직렬화 실패: %w", err)
}
```

### 2. 에러에 컨텍스트 추가

```go
// ❌ 원본 에러만 반환
if err != nil {
    return err
}

// ✅ 컨텍스트 추가
if err != nil {
    return fmt.Errorf("유저 %d 생성 중 DB 에러: %w", userID, err)
}
```

### 3. 에러는 한 번만 처리

```go
// ❌ 에러를 로깅하고 또 반환 (중복 처리)
if err != nil {
    log.Printf("에러 발생: %v", err)  // 여기서 로깅
    return err                         // 상위에서도 또 로깅하게 됨
}

// ✅ 반환만 하거나, 최종 호출자에서 로깅
if err != nil {
    return fmt.Errorf("operation failed: %w", err)
}
```

### 4. 센티널 에러로 API 계약 정의

```go
package user

var (
    ErrNotFound      = errors.New("user not found")
    ErrAlreadyExists = errors.New("user already exists")
    ErrInvalidInput  = errors.New("invalid input")
)

// 사용 측
user, err := user.Find(id)
if errors.Is(err, user.ErrNotFound) {
    // 404 응답
} else if err != nil {
    // 500 응답
}
```

---

## 8. 핵심 요약

- Go는 **에러를 값으로 반환**하는 명시적인 에러 처리 방식을 사용한다 (try-catch 없음)
- `errors.New`와 `fmt.Errorf`로 에러를 생성하며, `%w`로 에러를 **래핑**한다
- **커스텀 에러 타입**은 `error` 인터페이스의 `Error() string` 메서드를 구현한다
- `errors.Is`는 에러 체인에서 **값을 비교**하고, `errors.As`는 **타입을 추출**한다
- `panic`은 복구 불가능한 상황에만 사용하고, 일반 에러에는 `error` 반환을 사용한다
- 에러에 **컨텍스트를 추가**하되, **한 번만 처리**한다 (로깅 + 반환 중복 금지)

## 참고 자료

- [Go Blog - Error handling and Go](https://go.dev/blog/error-handling-and-go)
- [Go Blog - Working with Errors in Go 1.13](https://go.dev/blog/go1.13-errors)
- [Effective Go - Errors](https://go.dev/doc/effective_go#errors)
