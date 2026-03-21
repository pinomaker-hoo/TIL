# Go 동시성 프로그래밍

> Go의 가장 강력한 특징 중 하나인 동시성(Concurrency)을 정리한다. Goroutine과 Channel을 중심으로 안전하고 효율적인 동시성 프로그래밍 패턴을 다룬다.

## 목차

1. [동시성 vs 병렬성](#1-동시성-vs-병렬성)
2. [Goroutine](#2-goroutine)
3. [Channel](#3-channel)
4. [select 문](#4-select-문)
5. [sync 패키지](#5-sync-패키지)
6. [동시성 패턴](#6-동시성-패턴)
7. [context 패키지](#7-context-패키지)
8. [핵심 요약](#8-핵심-요약)

---

## 1. 동시성 vs 병렬성

- **동시성 (Concurrency)** - 여러 작업을 동시에 **관리**하는 구조. 실제로 동시에 실행되지 않을 수 있음
- **병렬성 (Parallelism)** - 여러 작업을 동시에 **실행**. 멀티코어 활용

```
동시성 (Concurrency):        병렬성 (Parallelism):
  코어 1                       코어 1    코어 2
  ┌─A─┐┌─B─┐┌─A─┐┌─B─┐       ┌─A─────┐  ┌─B─────┐
  └───┘└───┘└───┘└───┘       └──────┘  └──────┘
  시간축 →                     시간축 →
```

> Go의 철학: **"메모리를 공유하여 통신하지 말고, 통신하여 메모리를 공유하라"** (Don't communicate by sharing memory; share memory by communicating)

---

## 2. Goroutine

Goroutine은 Go 런타임이 관리하는 **경량 스레드**이다. OS 스레드보다 훨씬 가볍다 (초기 스택 ~2KB).

### 기본 사용

```go
func sayHello(name string) {
    fmt.Printf("Hello, %s!\n", name)
}

func main() {
    // go 키워드로 goroutine 시작
    go sayHello("Alice")
    go sayHello("Bob")
    go sayHello("Charlie")

    // main이 끝나면 모든 goroutine도 종료됨!
    time.Sleep(time.Second) // 기다리기 (실제로는 이렇게 하면 안 됨)
}
```

### Goroutine vs OS 스레드

| 항목 | Goroutine | OS 스레드 |
|------|-----------|----------|
| 초기 스택 크기 | ~2KB (동적 증가) | ~1MB (고정) |
| 생성 비용 | 매우 낮음 | 높음 |
| 동시 실행 수 | 수십만 개 가능 | 수천 개 수준 |
| 스케줄링 | Go 런타임 (M:N 모델) | OS 커널 |
| 컨텍스트 스위칭 | 빠름 | 느림 |

### 익명 함수로 goroutine 시작

```go
go func() {
    fmt.Println("익명 함수 goroutine")
}()

// 변수 캡처 주의!
for i := 0; i < 5; i++ {
    // ❌ 문제: 클로저가 같은 변수 i를 참조
    go func() {
        fmt.Println(i) // 대부분 5가 출력됨
    }()
}

for i := 0; i < 5; i++ {
    // ✅ 해결: 매개변수로 전달
    go func(n int) {
        fmt.Println(n) // 0, 1, 2, 3, 4 출력
    }(i)
}
```

---

## 3. Channel

Channel은 goroutine 간에 **데이터를 안전하게 전달**하는 통신 수단이다.

### 기본 사용

```go
// 채널 생성
ch := make(chan string)

// goroutine에서 채널에 데이터 전송
go func() {
    ch <- "Hello from goroutine"  // 전송 (blocking)
}()

// 메인에서 채널에서 데이터 수신
msg := <-ch  // 수신 (blocking)
fmt.Println(msg)
```

### 버퍼 채널 (Buffered Channel)

```go
// 버퍼 없는 채널 - 수신자가 준비될 때까지 전송 블로킹
ch1 := make(chan int)

// 버퍼 있는 채널 - 버퍼가 가득 찰 때까지 전송 논블로킹
ch2 := make(chan int, 3)
ch2 <- 1  // 블로킹 안 됨
ch2 <- 2  // 블로킹 안 됨
ch2 <- 3  // 블로킹 안 됨
// ch2 <- 4  // 블로킹됨! (버퍼 가득 참)

fmt.Println(<-ch2)  // 1
fmt.Println(<-ch2)  // 2
```

### 채널 방향 (Directional Channel)

함수 시그니처에서 채널의 방향을 제한할 수 있다.

```go
// 전송 전용 채널 (send-only)
func producer(ch chan<- int) {
    for i := 0; i < 5; i++ {
        ch <- i
    }
    close(ch)
}

// 수신 전용 채널 (receive-only)
func consumer(ch <-chan int) {
    for v := range ch {
        fmt.Println("수신:", v)
    }
}

func main() {
    ch := make(chan int)
    go producer(ch)
    consumer(ch)
}
```

### 채널 닫기와 range

```go
ch := make(chan int)

go func() {
    for i := 0; i < 5; i++ {
        ch <- i
    }
    close(ch)  // 더 이상 보낼 데이터가 없으면 닫기
}()

// range로 채널이 닫힐 때까지 순회
for v := range ch {
    fmt.Println(v)  // 0, 1, 2, 3, 4
}

// 채널이 닫혔는지 확인
v, ok := <-ch
if !ok {
    fmt.Println("채널이 닫혔습니다")
}
```

---

## 4. select 문

`select`는 **여러 채널 연산을 동시에 대기**한다. switch와 유사하지만 채널 전용이다.

```go
ch1 := make(chan string)
ch2 := make(chan string)

go func() {
    time.Sleep(1 * time.Second)
    ch1 <- "channel 1"
}()

go func() {
    time.Sleep(2 * time.Second)
    ch2 <- "channel 2"
}()

// 먼저 준비된 채널의 데이터를 수신
select {
case msg := <-ch1:
    fmt.Println("수신:", msg)
case msg := <-ch2:
    fmt.Println("수신:", msg)
}
```

### 타임아웃 패턴

```go
ch := make(chan string)

go func() {
    time.Sleep(3 * time.Second)
    ch <- "result"
}()

select {
case result := <-ch:
    fmt.Println("결과:", result)
case <-time.After(2 * time.Second):
    fmt.Println("타임아웃!")
}
```

### 논블로킹 채널 연산

```go
ch := make(chan int, 1)

// 논블로킹 전송
select {
case ch <- 42:
    fmt.Println("전송 성공")
default:
    fmt.Println("채널이 가득 참")
}

// 논블로킹 수신
select {
case v := <-ch:
    fmt.Println("수신:", v)
default:
    fmt.Println("데이터 없음")
}
```

---

## 5. sync 패키지

채널 외에 `sync` 패키지로도 동시성을 제어할 수 있다.

### WaitGroup

여러 goroutine이 모두 완료될 때까지 기다린다.

```go
import "sync"

func main() {
    var wg sync.WaitGroup

    urls := []string{
        "https://example.com",
        "https://google.com",
        "https://github.com",
    }

    for _, url := range urls {
        wg.Add(1)  // 카운터 증가

        go func(u string) {
            defer wg.Done()  // 완료 시 카운터 감소
            resp, err := http.Get(u)
            if err != nil {
                fmt.Printf("에러: %s\n", err)
                return
            }
            fmt.Printf("%s: %d\n", u, resp.StatusCode)
        }(url)
    }

    wg.Wait()  // 모든 goroutine 완료 대기
    fmt.Println("모든 요청 완료")
}
```

### Mutex

공유 데이터에 대한 **상호 배제(Mutual Exclusion)**를 보장한다.

```go
import "sync"

type SafeCounter struct {
    mu    sync.Mutex
    count map[string]int
}

func (c *SafeCounter) Increment(key string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count[key]++
}

func (c *SafeCounter) Get(key string) int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.count[key]
}

// RWMutex - 읽기는 동시에, 쓰기는 배타적
type Cache struct {
    mu   sync.RWMutex
    data map[string]string
}

func (c *Cache) Get(key string) (string, bool) {
    c.mu.RLock()         // 읽기 잠금 (여러 goroutine 동시 가능)
    defer c.mu.RUnlock()
    v, ok := c.data[key]
    return v, ok
}

func (c *Cache) Set(key, value string) {
    c.mu.Lock()          // 쓰기 잠금 (배타적)
    defer c.mu.Unlock()
    c.data[key] = value
}
```

### Once

함수를 **딱 한 번만 실행**한다. 싱글톤 패턴에 유용하다.

```go
var (
    instance *Database
    once     sync.Once
)

func GetDatabase() *Database {
    once.Do(func() {
        instance = &Database{
            // 초기화 로직 (한 번만 실행)
        }
        fmt.Println("데이터베이스 연결 완료")
    })
    return instance
}
```

---

## 6. 동시성 패턴

### Fan-Out / Fan-In

여러 goroutine에 작업을 분배(Fan-Out)하고, 결과를 하나로 모은다(Fan-In).

```go
// Fan-Out: 여러 워커에 작업 분배
func fanOut(jobs <-chan int, numWorkers int) []<-chan int {
    workers := make([]<-chan int, numWorkers)
    for i := 0; i < numWorkers; i++ {
        workers[i] = worker(jobs)
    }
    return workers
}

func worker(jobs <-chan int) <-chan int {
    results := make(chan int)
    go func() {
        defer close(results)
        for job := range jobs {
            results <- job * job  // 작업 처리
        }
    }()
    return results
}

// Fan-In: 여러 채널의 결과를 하나로 합침
func fanIn(channels ...<-chan int) <-chan int {
    var wg sync.WaitGroup
    merged := make(chan int)

    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan int) {
            defer wg.Done()
            for v := range c {
                merged <- v
            }
        }(ch)
    }

    go func() {
        wg.Wait()
        close(merged)
    }()

    return merged
}
```

### Worker Pool

고정된 수의 워커로 작업을 처리한다.

```go
func workerPool(numWorkers int, jobs <-chan int, results chan<- int) {
    var wg sync.WaitGroup

    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func(workerID int) {
            defer wg.Done()
            for job := range jobs {
                fmt.Printf("워커 %d: 작업 %d 처리 중\n", workerID, job)
                time.Sleep(time.Second) // 작업 시뮬레이션
                results <- job * 2
            }
        }(i)
    }

    go func() {
        wg.Wait()
        close(results)
    }()
}

func main() {
    jobs := make(chan int, 100)
    results := make(chan int, 100)

    // 워커 3개 시작
    workerPool(3, jobs, results)

    // 작업 전송
    for i := 1; i <= 10; i++ {
        jobs <- i
    }
    close(jobs)

    // 결과 수집
    for result := range results {
        fmt.Println("결과:", result)
    }
}
```

### Pipeline

여러 단계의 처리를 채널로 연결한다.

```go
// 1단계: 숫자 생성
func generate(nums ...int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for _, n := range nums {
            out <- n
        }
    }()
    return out
}

// 2단계: 제곱
func square(in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            out <- n * n
        }
    }()
    return out
}

// 3단계: 필터 (짝수만)
func filterEven(in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for n := range in {
            if n%2 == 0 {
                out <- n
            }
        }
    }()
    return out
}

func main() {
    // 파이프라인 연결: 생성 → 제곱 → 짝수 필터
    result := filterEven(square(generate(1, 2, 3, 4, 5)))

    for v := range result {
        fmt.Println(v)  // 4, 16 (2²=4, 4²=16만 짝수)
    }
}
```

---

## 7. context 패키지

`context`는 goroutine의 **취소, 타임아웃, 값 전달**을 관리한다. API 서버에서 필수적이다.

### 취소 (Cancellation)

```go
import "context"

func longRunningTask(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            fmt.Println("작업 취소됨:", ctx.Err())
            return ctx.Err()
        default:
            // 작업 수행
            fmt.Println("작업 중...")
            time.Sleep(500 * time.Millisecond)
        }
    }
}

func main() {
    ctx, cancel := context.WithCancel(context.Background())

    go longRunningTask(ctx)

    time.Sleep(2 * time.Second)
    cancel()  // 취소 신호 전송
    time.Sleep(time.Second)
}
```

### 타임아웃

```go
func fetchData(ctx context.Context, url string) ([]byte, error) {
    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, err
    }
    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    return io.ReadAll(resp.Body)
}

func main() {
    // 3초 타임아웃
    ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
    defer cancel()

    data, err := fetchData(ctx, "https://api.example.com/data")
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            fmt.Println("요청 타임아웃!")
        }
        return
    }
    fmt.Println(string(data))
}
```

### 데드라인과 값 전달

```go
// 특정 시간까지 제한
deadline := time.Now().Add(5 * time.Second)
ctx, cancel := context.WithDeadline(context.Background(), deadline)
defer cancel()

// context에 값 저장 (요청 ID 등)
ctx = context.WithValue(ctx, "requestID", "abc-123")

// 값 조회
reqID := ctx.Value("requestID").(string)
```

---

## 8. 핵심 요약

- **Goroutine**은 `go` 키워드로 시작하는 경량 스레드이며, 수십만 개를 동시에 실행할 수 있다
- **Channel**은 goroutine 간 안전한 데이터 전달 수단이다 (공유 메모리 대신 통신 사용)
- **버퍼 채널**은 비동기 전송이 가능하고, **방향 채널**로 전송/수신을 제한할 수 있다
- **select**로 여러 채널 연산을 동시에 대기하며, 타임아웃/논블로킹 패턴을 구현한다
- **sync.WaitGroup**은 여러 goroutine 완료 대기, **sync.Mutex**는 공유 데이터 보호에 사용한다
- **Worker Pool**, **Fan-Out/Fan-In**, **Pipeline**은 자주 사용하는 동시성 패턴이다
- **context** 패키지로 goroutine의 취소, 타임아웃, 값 전달을 관리한다

## 참고 자료

- [Go 공식 문서 - Concurrency](https://go.dev/tour/concurrency/1)
- [Go Blog - Share Memory By Communicating](https://go.dev/blog/codelab-share)
- [Go Blog - Go Concurrency Patterns](https://go.dev/blog/pipelines)
- [Go Blog - Context](https://go.dev/blog/context)
