# Go 모듈과 패키지

> Go의 코드 구성 단위인 패키지(Package)와 의존성 관리 시스템인 모듈(Module)을 정리한다.

## 목차

1. [패키지 (Package)](#1-패키지-package)
2. [Go Modules](#2-go-modules)
3. [의존성 관리](#3-의존성-관리)
4. [프로젝트 구조](#4-프로젝트-구조)
5. [주요 go 명령어](#5-주요-go-명령어)
6. [핵심 요약](#6-핵심-요약)

---

## 1. 패키지 (Package)

패키지는 Go의 **코드 구성 단위**이다. 모든 Go 파일은 반드시 패키지에 속한다.

### 패키지 기본

```go
// 파일 상단에 패키지 선언
package math

// 같은 패키지 내 파일들은 서로의 함수/변수에 접근 가능
func Add(a, b int) int {
    return a + b
}
```

### 가시성 규칙 (Exported vs Unexported)

Go는 **대문자 시작 = 외부 공개, 소문자 시작 = 내부 전용** 규칙을 사용한다.

```go
package user

// ✅ 대문자 시작 → 외부에서 접근 가능 (Exported)
type User struct {
    ID    int
    Name  string
    Email string
}

func NewUser(name, email string) *User {
    return &User{Name: name, Email: email}
}

// ❌ 소문자 시작 → 같은 패키지에서만 접근 가능 (Unexported)
type config struct {
    maxRetries int
}

func validate(u *User) error {
    // 내부 헬퍼 함수
    return nil
}
```

```go
// 다른 패키지에서 사용
package main

import "myapp/user"

func main() {
    u := user.NewUser("Alice", "alice@example.com") // ✅
    fmt.Println(u.Name)                              // ✅

    // c := user.config{}    // ❌ 컴파일 에러 (unexported)
    // user.validate(u)      // ❌ 컴파일 에러 (unexported)
}
```

### import

```go
// 단일 임포트
import "fmt"

// 복수 임포트
import (
    "fmt"
    "os"
    "strings"

    // 외부 패키지
    "github.com/gin-gonic/gin"

    // 내부 패키지 (모듈 경로 기준)
    "myapp/internal/database"
    "myapp/pkg/utils"
)

// 별칭 사용
import (
    f "fmt"                    // 별칭
    _ "github.com/lib/pq"     // 부수 효과만 사용 (init 함수 실행)
    . "math"                   // 패키지 이름 없이 사용 (비권장)
)

f.Println("별칭 사용")
```

### init 함수

`init()`은 패키지가 로드될 때 자동 실행되는 함수이다. 초기화에 사용된다.

```go
package database

import "fmt"

var DB *sql.DB

func init() {
    // 패키지 로드 시 자동 실행
    var err error
    DB, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        panic(err)
    }
    fmt.Println("데이터베이스 연결 완료")
}
```

```
실행 순서:
1. 임포트된 패키지의 변수 초기화
2. 임포트된 패키지의 init() 실행
3. 현재 패키지의 변수 초기화
4. 현재 패키지의 init() 실행
5. main() 실행
```

---

## 2. Go Modules

Go Modules는 Go 1.11에서 도입된 **공식 의존성 관리 시스템**이다.

### 모듈 초기화

```bash
# 새 모듈 생성
go mod init github.com/username/myapp

# 결과: go.mod 파일 생성
```

### go.mod 파일

```go
// go.mod
module github.com/username/myapp

go 1.22

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    gorm.io/gorm v1.25.5
)

require (
    // indirect - 직접 import하지 않는 간접 의존성
    github.com/bytedance/sonic v1.10.0 // indirect
    github.com/go-playground/validator/v10 v10.15.0 // indirect
)
```

### go.sum 파일

의존성의 **체크섬(해시)**을 기록하여 무결성을 보장한다. 직접 편집하지 않는다.

```
github.com/gin-gonic/gin v1.9.1 h1:4+fr/el88TOO3ewCmQ...
github.com/gin-gonic/gin v1.9.1/go.mod h1:TkL3ewC...
```

---

## 3. 의존성 관리

### 의존성 추가

```bash
# 패키지 설치
go get github.com/gin-gonic/gin

# 특정 버전 설치
go get github.com/gin-gonic/gin@v1.9.1

# 최신 버전으로 업데이트
go get -u github.com/gin-gonic/gin

# 모든 의존성 업데이트
go get -u ./...
```

### 의존성 정리

```bash
# 사용하지 않는 의존성 제거 + 누락된 의존성 추가
go mod tidy
```

### 의존성 교체 (replace)

로컬 개발이나 포크한 패키지를 사용할 때 유용하다.

```go
// go.mod
module myapp

go 1.22

require github.com/original/pkg v1.0.0

// 로컬 경로로 교체
replace github.com/original/pkg => ../my-local-pkg

// 포크한 저장소로 교체
replace github.com/original/pkg => github.com/myfork/pkg v1.0.1
```

### vendor 디렉토리

의존성을 프로젝트 내에 복사하여 오프라인 빌드를 지원한다.

```bash
# vendor 디렉토리 생성
go mod vendor

# vendor를 사용하여 빌드
go build -mod=vendor ./...
```

---

## 4. 프로젝트 구조

### 표준 레이아웃 (커뮤니티 관례)

```
myapp/
├── cmd/                    # 실행 가능한 애플리케이션
│   ├── api/
│   │   └── main.go         # API 서버 진입점
│   └── worker/
│       └── main.go         # 워커 진입점
├── internal/               # 외부에서 import 불가한 내부 패키지
│   ├── handler/
│   │   └── user.go
│   ├── service/
│   │   └── user.go
│   ├── repository/
│   │   └── user.go
│   └── model/
│       └── user.go
├── pkg/                    # 외부에서 import 가능한 공개 패키지
│   ├── logger/
│   │   └── logger.go
│   └── middleware/
│       └── auth.go
├── config/                 # 설정 파일
│   └── config.go
├── migrations/             # DB 마이그레이션
├── go.mod
├── go.sum
└── Makefile
```

### internal 패키지

`internal` 디렉토리 하위의 패키지는 **같은 모듈 내에서만 import 가능**하다. Go 컴파일러가 강제한다.

```
myapp/
├── internal/
│   └── auth/
│       └── auth.go         # myapp 내부에서만 import 가능
├── pkg/
│   └── utils/
│       └── utils.go        # 누구나 import 가능
```

```go
// ✅ 같은 모듈 내에서 import
import "myapp/internal/auth"

// ❌ 외부 모듈에서 import 시 컴파일 에러
// import "github.com/username/myapp/internal/auth"
```

### 간단한 프로젝트 구조

작은 프로젝트에서는 단순하게 구성해도 된다.

```
myapp/
├── main.go
├── handler.go
├── service.go
├── model.go
├── go.mod
└── go.sum
```

---

## 5. 주요 go 명령어

### 빌드와 실행

```bash
# 실행 (빌드 + 실행)
go run main.go
go run .                    # 현재 디렉토리의 main 패키지 실행

# 빌드
go build -o myapp ./cmd/api
go build ./...              # 모든 패키지 빌드

# 크로스 컴파일
GOOS=linux GOARCH=amd64 go build -o myapp-linux ./cmd/api
GOOS=darwin GOARCH=arm64 go build -o myapp-mac ./cmd/api
GOOS=windows GOARCH=amd64 go build -o myapp.exe ./cmd/api

# 설치 (바이너리를 $GOPATH/bin에 설치)
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

### 테스트

```bash
# 테스트 실행
go test ./...               # 모든 패키지 테스트
go test ./internal/service  # 특정 패키지 테스트
go test -v ./...            # 상세 출력
go test -run TestFuncName   # 특정 테스트만 실행
go test -cover ./...        # 커버리지 포함
go test -race ./...         # 레이스 컨디션 검출
go test -bench=. ./...      # 벤치마크 실행
```

### 코드 품질

```bash
# 코드 포맷팅
go fmt ./...                # 공식 포맷터
gofmt -w .                  # 파일에 직접 쓰기

# 정적 분석
go vet ./...                # 잠재적 버그 검출

# 린터 (외부 도구)
golangci-lint run
```

### 모듈 관리

```bash
go mod init module-name     # 모듈 초기화
go mod tidy                 # 의존성 정리
go mod vendor               # vendor 디렉토리 생성
go mod download             # 의존성 다운로드
go mod graph                # 의존성 그래프 출력
go mod why <package>        # 왜 이 패키지가 필요한지 설명
```

### 기타 유용한 명령어

```bash
go doc fmt.Println          # 문서 확인
go env                      # Go 환경 변수 확인
go env GOPATH               # 특정 환경 변수
go generate ./...           # go:generate 지시문 실행
go clean -cache             # 빌드 캐시 삭제
```

---

## 6. 핵심 요약

- **패키지**는 Go의 코드 구성 단위이며, **대문자 시작 = 공개, 소문자 시작 = 비공개** 규칙을 따른다
- **Go Modules**(go.mod)는 공식 의존성 관리 시스템으로, `go get`으로 패키지를 설치하고 `go mod tidy`로 정리한다
- **internal** 디렉토리는 같은 모듈 내에서만 import 가능하며, 컴파일러가 접근 제한을 강제한다
- 프로젝트 구조는 `cmd/`(진입점), `internal/`(내부), `pkg/`(공개) 패턴을 관례적으로 사용한다
- `go build`로 **크로스 컴파일**이 가능하며, 단일 바이너리로 배포한다
- `go test -race`로 레이스 컨디션을 검출하고, `go vet`으로 정적 분석을 수행한다

## 참고 자료

- [Go Modules 공식 문서](https://go.dev/ref/mod)
- [Go Blog - Using Go Modules](https://go.dev/blog/using-go-modules)
- [Standard Go Project Layout](https://github.com/golang-standards/project-layout)
- [How to Write Go Code](https://go.dev/doc/code)
