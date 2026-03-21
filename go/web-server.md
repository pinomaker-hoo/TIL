# Go 웹 서버 구축

> Go의 표준 라이브러리 `net/http`와 인기 있는 웹 프레임워크(Gin, Echo, Fiber)를 사용하여 웹 서버를 구축하는 방법을 정리한다.

## 목차

1. [net/http 표준 라이브러리](#1-nethttp-표준-라이브러리)
2. [라우팅과 미들웨어 직접 구현](#2-라우팅과-미들웨어-직접-구현)
3. [Gin 프레임워크](#3-gin-프레임워크)
4. [Echo 프레임워크](#4-echo-프레임워크)
5. [Fiber 프레임워크](#5-fiber-프레임워크)
6. [프레임워크 비교](#6-프레임워크-비교)
7. [데이터베이스 연동](#7-데이터베이스-연동)
8. [실전 프로젝트 구조](#8-실전-프로젝트-구조)
9. [핵심 요약](#9-핵심-요약)

---

## 1. net/http 표준 라이브러리

Go는 외부 프레임워크 없이도 **표준 라이브러리만으로** 프로덕션급 HTTP 서버를 구축할 수 있다.

### Hello World 서버

```go
package main

import (
    "fmt"
    "net/http"
)

func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintf(w, "Hello, World!")
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        fmt.Fprintf(w, "OK")
    })

    fmt.Println("서버 시작: http://localhost:8080")
    http.ListenAndServe(":8080", nil)
}
```

### JSON API 서버

```go
package main

import (
    "encoding/json"
    "net/http"
)

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

type Response struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   string      `json:"error,omitempty"`
}

func getUsers(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodGet {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    users := []User{
        {ID: 1, Name: "Alice", Email: "alice@example.com"},
        {ID: 2, Name: "Bob", Email: "bob@example.com"},
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(Response{Success: true, Data: users})
}

func createUser(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }

    var user User
    if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusBadRequest)
        json.NewEncoder(w).Encode(Response{Error: "잘못된 요청 형식"})
        return
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(Response{Success: true, Data: user})
}

func main() {
    http.HandleFunc("/users", func(w http.ResponseWriter, r *http.Request) {
        switch r.Method {
        case http.MethodGet:
            getUsers(w, r)
        case http.MethodPost:
            createUser(w, r)
        default:
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        }
    })

    http.ListenAndServe(":8080", nil)
}
```

### http.Server 커스터마이징

프로덕션에서는 타임아웃과 Graceful Shutdown을 설정한다.

```go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        w.Write([]byte("Hello"))
    })

    server := &http.Server{
        Addr:         ":8080",
        Handler:      mux,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  120 * time.Second,
    }

    // Graceful Shutdown
    go func() {
        log.Printf("서버 시작: %s", server.Addr)
        if err := server.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatalf("서버 에러: %v", err)
        }
    }()

    // 종료 시그널 대기 (Ctrl+C, kill 등)
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    log.Println("서버 종료 중...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := server.Shutdown(ctx); err != nil {
        log.Fatalf("서버 강제 종료: %v", err)
    }

    log.Println("서버 종료 완료")
}
```

---

## 2. 라우팅과 미들웨어 직접 구현

### 미들웨어 패턴

```go
// 미들웨어 타입
type Middleware func(http.Handler) http.Handler

// 로깅 미들웨어
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        log.Printf("[%s] %s %s", r.Method, r.URL.Path, r.RemoteAddr)

        next.ServeHTTP(w, r)

        log.Printf("[%s] %s - %v", r.Method, r.URL.Path, time.Since(start))
    })
}

// CORS 미들웨어
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

        if r.Method == http.MethodOptions {
            w.WriteHeader(http.StatusOK)
            return
        }

        next.ServeHTTP(w, r)
    })
}

// 인증 미들웨어
func authMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        token := r.Header.Get("Authorization")
        if token == "" {
            http.Error(w, "Unauthorized", http.StatusUnauthorized)
            return
        }
        // 토큰 검증 로직...
        next.ServeHTTP(w, r)
    })
}

// 미들웨어 체이닝
func chain(handler http.Handler, middlewares ...Middleware) http.Handler {
    for i := len(middlewares) - 1; i >= 0; i-- {
        handler = middlewares[i](handler)
    }
    return handler
}

func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/api/users", getUsers)

    // 미들웨어 적용
    handler := chain(mux, loggingMiddleware, corsMiddleware)

    http.ListenAndServe(":8080", handler)
}
```

---

## 3. Gin 프레임워크

**Gin**은 Go에서 가장 인기 있는 웹 프레임워크이다. 빠른 라우팅, 미들웨어, 검증 등을 제공한다.

### 설치 및 기본 사용

```bash
go get github.com/gin-gonic/gin
```

```go
package main

import (
    "net/http"

    "github.com/gin-gonic/gin"
)

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name" binding:"required"`
    Email string `json:"email" binding:"required,email"`
}

var users = []User{
    {ID: 1, Name: "Alice", Email: "alice@example.com"},
    {ID: 2, Name: "Bob", Email: "bob@example.com"},
}

func main() {
    r := gin.Default() // Logger + Recovery 미들웨어 포함

    // GET /users
    r.GET("/users", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "success": true,
            "data":    users,
        })
    })

    // GET /users/:id
    r.GET("/users/:id", func(c *gin.Context) {
        id := c.Param("id")
        c.JSON(http.StatusOK, gin.H{"id": id})
    })

    // POST /users
    r.POST("/users", func(c *gin.Context) {
        var user User
        if err := c.ShouldBindJSON(&user); err != nil {
            c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
            return
        }
        user.ID = len(users) + 1
        users = append(users, user)
        c.JSON(http.StatusCreated, gin.H{"success": true, "data": user})
    })

    // 쿼리 파라미터
    // GET /search?q=keyword&page=1
    r.GET("/search", func(c *gin.Context) {
        query := c.Query("q")
        page := c.DefaultQuery("page", "1")
        c.JSON(http.StatusOK, gin.H{"query": query, "page": page})
    })

    r.Run(":8080")
}
```

### Gin 라우터 그룹과 미들웨어

```go
func authMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.JSON(http.StatusUnauthorized, gin.H{"error": "토큰이 필요합니다"})
            c.Abort()
            return
        }
        // 토큰 검증...
        c.Set("userID", 123) // 컨텍스트에 값 저장
        c.Next()
    }
}

func main() {
    r := gin.Default()

    // 공개 API
    public := r.Group("/api")
    {
        public.POST("/login", loginHandler)
        public.POST("/register", registerHandler)
    }

    // 인증 필요 API
    protected := r.Group("/api")
    protected.Use(authMiddleware())
    {
        protected.GET("/profile", func(c *gin.Context) {
            userID := c.GetInt("userID")
            c.JSON(http.StatusOK, gin.H{"userID": userID})
        })
        protected.PUT("/profile", updateProfileHandler)
        protected.GET("/users", listUsersHandler)
    }

    r.Run(":8080")
}
```

---

## 4. Echo 프레임워크

**Echo**는 미니멀하면서도 확장성 있는 웹 프레임워크이다.

### 설치 및 기본 사용

```bash
go get github.com/labstack/echo/v4
```

```go
package main

import (
    "net/http"

    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"
)

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name" validate:"required"`
    Email string `json:"email" validate:"required,email"`
}

func main() {
    e := echo.New()

    // 미들웨어
    e.Use(middleware.Logger())
    e.Use(middleware.Recover())
    e.Use(middleware.CORS())

    // 라우트
    e.GET("/users", func(c echo.Context) error {
        users := []User{
            {ID: 1, Name: "Alice", Email: "alice@example.com"},
        }
        return c.JSON(http.StatusOK, users)
    })

    e.GET("/users/:id", func(c echo.Context) error {
        id := c.Param("id")
        return c.JSON(http.StatusOK, map[string]string{"id": id})
    })

    e.POST("/users", func(c echo.Context) error {
        var user User
        if err := c.Bind(&user); err != nil {
            return echo.NewHTTPError(http.StatusBadRequest, err.Error())
        }
        return c.JSON(http.StatusCreated, user)
    })

    // 라우터 그룹
    api := e.Group("/api")
    api.Use(middleware.KeyAuth(func(key string, c echo.Context) (bool, error) {
        return key == "my-secret-key", nil
    }))
    api.GET("/protected", protectedHandler)

    e.Logger.Fatal(e.Start(":8080"))
}
```

---

## 5. Fiber 프레임워크

**Fiber**는 Express.js에서 영감을 받은 프레임워크로, Go의 `fasthttp` 위에 구축되어 매우 빠르다.

### 설치 및 기본 사용

```bash
go get github.com/gofiber/fiber/v2
```

```go
package main

import (
    "github.com/gofiber/fiber/v2"
    "github.com/gofiber/fiber/v2/middleware/cors"
    "github.com/gofiber/fiber/v2/middleware/logger"
)

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

func main() {
    app := fiber.New(fiber.Config{
        AppName: "My API v1.0",
    })

    // 미들웨어
    app.Use(logger.New())
    app.Use(cors.New())

    // 라우트 (Express.js와 유사한 API)
    app.Get("/users", func(c *fiber.Ctx) error {
        users := []User{
            {ID: 1, Name: "Alice", Email: "alice@example.com"},
        }
        return c.JSON(users)
    })

    app.Get("/users/:id", func(c *fiber.Ctx) error {
        id := c.Params("id")
        return c.JSON(fiber.Map{"id": id})
    })

    app.Post("/users", func(c *fiber.Ctx) error {
        var user User
        if err := c.BodyParser(&user); err != nil {
            return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
                "error": err.Error(),
            })
        }
        return c.Status(fiber.StatusCreated).JSON(user)
    })

    // 라우터 그룹
    api := app.Group("/api")
    api.Use(authMiddleware)
    api.Get("/profile", profileHandler)

    app.Listen(":8080")
}
```

---

## 6. 프레임워크 비교

| 항목 | net/http | Gin | Echo | Fiber |
|------|----------|-----|------|-------|
| **의존성** | 없음 (표준 라이브러리) | 외부 패키지 | 외부 패키지 | 외부 패키지 |
| **성능** | 좋음 | 매우 좋음 | 매우 좋음 | 가장 빠름 |
| **학습 곡선** | 낮음 | 낮음 | 낮음 | 낮음 (Express 경험 시) |
| **미들웨어** | 직접 구현 | 풍부한 내장 | 풍부한 내장 | 풍부한 내장 |
| **라우팅** | 기본 | 고급 (파라미터, 그룹) | 고급 | 고급 |
| **검증** | 직접 구현 | binding 태그 | validator 통합 | BodyParser |
| **HTTP 엔진** | net/http | net/http | net/http | fasthttp |
| **GitHub Stars** | - | ~79k+ | ~30k+ | ~34k+ |
| **적합한 상황** | 간단한 서비스 | 범용 API | 범용 API | 고성능 API |

> **추천**: 처음 시작한다면 **Gin**이 생태계와 문서가 가장 풍부하다. Express.js에 익숙하다면 **Fiber**가 친숙하다. 외부 의존성을 최소화하고 싶다면 **net/http**로 충분하다.

---

## 7. 데이터베이스 연동

### GORM (ORM)

```bash
go get gorm.io/gorm
go get gorm.io/driver/postgres
```

```go
package main

import (
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
)

type User struct {
    gorm.Model              // ID, CreatedAt, UpdatedAt, DeletedAt 자동 포함
    Name  string `gorm:"size:100;not null"`
    Email string `gorm:"uniqueIndex;not null"`
    Age   int
}

func main() {
    dsn := "host=localhost user=postgres password=secret dbname=myapp port=5432 sslmode=disable"
    db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        panic("DB 연결 실패: " + err.Error())
    }

    // 마이그레이션
    db.AutoMigrate(&User{})

    // CRUD
    // Create
    user := User{Name: "Alice", Email: "alice@example.com", Age: 25}
    db.Create(&user)

    // Read
    var found User
    db.First(&found, 1)                           // ID로 조회
    db.Where("email = ?", "alice@example.com").First(&found) // 조건 조회

    // Read All
    var users []User
    db.Find(&users)
    db.Where("age > ?", 20).Find(&users)

    // Update
    db.Model(&found).Update("Name", "Alice Kim")
    db.Model(&found).Updates(User{Name: "Alice Kim", Age: 26})

    // Delete (Soft Delete - DeletedAt에 시간 기록)
    db.Delete(&found)
}
```

### Gin + GORM 조합

```go
package main

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "gorm.io/driver/postgres"
    "gorm.io/gorm"
)

type User struct {
    gorm.Model
    Name  string `json:"name" gorm:"size:100;not null" binding:"required"`
    Email string `json:"email" gorm:"uniqueIndex;not null" binding:"required,email"`
}

var db *gorm.DB

func initDB() {
    var err error
    dsn := "host=localhost user=postgres password=secret dbname=myapp port=5432 sslmode=disable"
    db, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil {
        panic("DB 연결 실패")
    }
    db.AutoMigrate(&User{})
}

func getUsers(c *gin.Context) {
    var users []User
    db.Find(&users)
    c.JSON(http.StatusOK, users)
}

func createUser(c *gin.Context) {
    var user User
    if err := c.ShouldBindJSON(&user); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    if err := db.Create(&user).Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "생성 실패"})
        return
    }
    c.JSON(http.StatusCreated, user)
}

func getUserByID(c *gin.Context) {
    var user User
    if err := db.First(&user, c.Param("id")).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "유저를 찾을 수 없습니다"})
        return
    }
    c.JSON(http.StatusOK, user)
}

func updateUser(c *gin.Context) {
    var user User
    if err := db.First(&user, c.Param("id")).Error; err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "유저를 찾을 수 없습니다"})
        return
    }
    if err := c.ShouldBindJSON(&user); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    db.Save(&user)
    c.JSON(http.StatusOK, user)
}

func deleteUser(c *gin.Context) {
    if err := db.Delete(&User{}, c.Param("id")).Error; err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "삭제 실패"})
        return
    }
    c.JSON(http.StatusOK, gin.H{"message": "삭제 완료"})
}

func main() {
    initDB()

    r := gin.Default()

    v1 := r.Group("/api/v1")
    {
        v1.GET("/users", getUsers)
        v1.POST("/users", createUser)
        v1.GET("/users/:id", getUserByID)
        v1.PUT("/users/:id", updateUser)
        v1.DELETE("/users/:id", deleteUser)
    }

    r.Run(":8080")
}
```

---

## 8. 실전 프로젝트 구조

### 레이어드 아키텍처 예시

```
myapi/
├── cmd/
│   └── api/
│       └── main.go              # 진입점
├── internal/
│   ├── config/
│   │   └── config.go            # 환경 설정
│   ├── handler/
│   │   └── user_handler.go      # HTTP 핸들러 (Controller)
│   ├── service/
│   │   └── user_service.go      # 비즈니스 로직
│   ├── repository/
│   │   └── user_repository.go   # DB 접근 계층
│   ├── model/
│   │   └── user.go              # 데이터 모델
│   ├── dto/
│   │   └── user_dto.go          # 요청/응답 DTO
│   ├── middleware/
│   │   ├── auth.go
│   │   └── logging.go
│   └── router/
│       └── router.go            # 라우트 설정
├── pkg/
│   └── response/
│       └── response.go          # 공통 응답 헬퍼
├── migrations/
├── go.mod
├── go.sum
├── Makefile
└── Dockerfile
```

### 핵심 코드 예시

```go
// internal/model/user.go
package model

import "gorm.io/gorm"

type User struct {
    gorm.Model
    Name  string `gorm:"size:100;not null"`
    Email string `gorm:"uniqueIndex;not null"`
}
```

```go
// internal/repository/user_repository.go
package repository

import (
    "myapi/internal/model"
    "gorm.io/gorm"
)

type UserRepository struct {
    db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
    return &UserRepository{db: db}
}

func (r *UserRepository) FindAll() ([]model.User, error) {
    var users []model.User
    err := r.db.Find(&users).Error
    return users, err
}

func (r *UserRepository) FindByID(id uint) (*model.User, error) {
    var user model.User
    err := r.db.First(&user, id).Error
    return &user, err
}

func (r *UserRepository) Create(user *model.User) error {
    return r.db.Create(user).Error
}
```

```go
// internal/service/user_service.go
package service

import (
    "myapi/internal/model"
    "myapi/internal/repository"
)

type UserService struct {
    repo *repository.UserRepository
}

func NewUserService(repo *repository.UserRepository) *UserService {
    return &UserService{repo: repo}
}

func (s *UserService) GetAllUsers() ([]model.User, error) {
    return s.repo.FindAll()
}

func (s *UserService) CreateUser(name, email string) (*model.User, error) {
    user := &model.User{Name: name, Email: email}
    err := s.repo.Create(user)
    return user, err
}
```

```go
// internal/handler/user_handler.go
package handler

import (
    "net/http"
    "myapi/internal/service"

    "github.com/gin-gonic/gin"
)

type UserHandler struct {
    svc *service.UserService
}

func NewUserHandler(svc *service.UserService) *UserHandler {
    return &UserHandler{svc: svc}
}

func (h *UserHandler) GetUsers(c *gin.Context) {
    users, err := h.svc.GetAllUsers()
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
        return
    }
    c.JSON(http.StatusOK, users)
}
```

---

## 9. 핵심 요약

- Go는 **표준 라이브러리 `net/http`만으로** 프로덕션급 HTTP 서버를 구축할 수 있다
- **Gin**(가장 인기), **Echo**(미니멀), **Fiber**(가장 빠름) 등의 프레임워크를 활용하면 더 편리하다
- 프로덕션에서는 반드시 **타임아웃 설정**과 **Graceful Shutdown**을 구현해야 한다
- **GORM**으로 데이터베이스를 연동하고, **레이어드 아키텍처**(Handler → Service → Repository)로 구성한다
- Go 서버는 **단일 바이너리**로 컴파일되므로 배포가 매우 간단하다

## 참고 자료

- [Go net/http 공식 문서](https://pkg.go.dev/net/http)
- [Gin 공식 문서](https://gin-gonic.com/docs/)
- [Echo 공식 문서](https://echo.labstack.com/)
- [Fiber 공식 문서](https://docs.gofiber.io/)
- [GORM 공식 문서](https://gorm.io/docs/)
