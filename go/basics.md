# Go 기초 문법

> Go의 변수, 타입, 함수, 제어문, 배열, 슬라이스, 맵 등 핵심 문법을 정리한다.

## 목차

1. [Hello World](#1-hello-world)
2. [변수와 상수](#2-변수와-상수)
3. [기본 타입](#3-기본-타입)
4. [함수](#4-함수)
5. [제어문](#5-제어문)
6. [배열과 슬라이스](#6-배열과-슬라이스)
7. [맵 (Map)](#7-맵-map)
8. [포인터](#8-포인터)
9. [핵심 요약](#9-핵심-요약)

---

## 1. Hello World

```go
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
```

```bash
# 실행
go run main.go

# 빌드 후 실행
go build -o myapp main.go
./myapp
```

- `package main` - 실행 가능한 프로그램의 진입점 패키지
- `import "fmt"` - 표준 라이브러리의 fmt 패키지 임포트
- `func main()` - 프로그램의 시작점

---

## 2. 변수와 상수

### 변수 선언

```go
// var 키워드로 선언
var name string = "Go"
var age int = 15

// 타입 추론 (초기값에서 타입 결정)
var language = "Golang"

// 짧은 선언 (:=) - 함수 내부에서만 사용 가능
message := "Hello"
count := 42
pi := 3.14

// 여러 변수 동시 선언
var (
    host   string = "localhost"
    port   int    = 8080
    debug  bool   = false
)

// 제로 값 (Zero Value) - 초기값 없이 선언하면 기본값이 할당됨
var i int       // 0
var f float64   // 0.0
var s string    // "" (빈 문자열)
var b bool      // false
```

### 상수 선언

```go
const Pi = 3.14159
const AppName = "MyApp"

// 여러 상수 동시 선언
const (
    StatusOK    = 200
    StatusNotFound = 404
    StatusError = 500
)

// iota - 자동 증가 상수
const (
    Sunday = iota   // 0
    Monday          // 1
    Tuesday         // 2
    Wednesday       // 3
    Thursday        // 4
    Friday          // 5
    Saturday        // 6
)
```

---

## 3. 기본 타입

### 숫자 타입

```go
// 정수
var i int     = 42        // 플랫폼에 따라 32비트 또는 64비트
var i8 int8   = 127       // -128 ~ 127
var i16 int16 = 32767     // -32768 ~ 32767
var i32 int32 = 2147483647
var i64 int64 = 9223372036854775807

// 부호 없는 정수
var u uint    = 42
var u8 uint8  = 255       // 0 ~ 255 (byte의 별칭)
var u32 uint32 = 4294967295

// 실수
var f32 float32 = 3.14
var f64 float64 = 3.141592653589793

// 복소수
var c64 complex64 = 1 + 2i
var c128 complex128 = 1 + 2i
```

### 문자열

```go
// 문자열 (UTF-8 인코딩)
name := "Go 언어"

// 원시 문자열 (이스케이프 없음)
path := `C:\Users\pinomaker\Documents`
multiLine := `
여러 줄
문자열
`

// 문자열 연산
greeting := "Hello" + " " + "World"
length := len(greeting)               // 바이트 수: 11

// rune (유니코드 코드포인트)
r := '가'                             // rune 타입 (int32의 별칭)

// 문자열 순회
for i, ch := range "Go 언어" {
    fmt.Printf("인덱스: %d, 문자: %c\n", i, ch)
}
```

### 타입 변환

Go는 **암시적 타입 변환이 없다**. 반드시 명시적으로 변환해야 한다.

```go
i := 42
f := float64(i)     // int → float64
u := uint(i)        // int → uint

// 문자열 변환
import "strconv"

s := strconv.Itoa(42)           // int → string: "42"
n, err := strconv.Atoi("42")    // string → int: 42

f2, err := strconv.ParseFloat("3.14", 64)  // string → float64
s2 := strconv.FormatFloat(3.14, 'f', 2, 64) // float64 → string
```

---

## 4. 함수

### 기본 함수

```go
// 기본 함수
func add(a int, b int) int {
    return a + b
}

// 같은 타입 매개변수 축약
func add(a, b int) int {
    return a + b
}

// 다중 반환값 (Go의 특징!)
func divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, fmt.Errorf("0으로 나눌 수 없습니다")
    }
    return a / b, nil
}

result, err := divide(10, 3)
if err != nil {
    fmt.Println("에러:", err)
}
```

### 이름 붙인 반환값 (Named Return)

```go
func swap(a, b int) (x, y int) {
    x = b
    y = a
    return // 이름 붙인 반환값을 자동으로 반환
}
```

### 가변 인자 함수

```go
func sum(nums ...int) int {
    total := 0
    for _, n := range nums {
        total += n
    }
    return total
}

result := sum(1, 2, 3, 4, 5)  // 15

// 슬라이스를 가변 인자로 전달
numbers := []int{1, 2, 3}
result = sum(numbers...)
```

### 함수 타입과 클로저

```go
// 함수를 변수에 할당
add := func(a, b int) int {
    return a + b
}
fmt.Println(add(3, 4))  // 7

// 클로저 (Closure)
func counter() func() int {
    count := 0
    return func() int {
        count++
        return count
    }
}

next := counter()
fmt.Println(next())  // 1
fmt.Println(next())  // 2
fmt.Println(next())  // 3
```

### defer

`defer`는 함수가 종료될 때 실행할 코드를 예약한다. 리소스 해제에 주로 사용된다.

```go
func readFile(path string) error {
    file, err := os.Open(path)
    if err != nil {
        return err
    }
    defer file.Close()  // 함수 종료 시 파일 닫기

    // 파일 읽기 작업...
    return nil
}

// 여러 defer는 LIFO(후입선출) 순서로 실행
func example() {
    defer fmt.Println("1st")
    defer fmt.Println("2nd")
    defer fmt.Println("3rd")
    // 출력: 3rd → 2nd → 1st
}
```

---

## 5. 제어문

### if 문

```go
// 기본 if
if x > 0 {
    fmt.Println("양수")
} else if x < 0 {
    fmt.Println("음수")
} else {
    fmt.Println("영")
}

// 초기화 구문이 있는 if (Go의 특징!)
if err := doSomething(); err != nil {
    fmt.Println("에러:", err)
    // err 변수는 이 블록 내에서만 유효
}
```

### for 문 (Go의 유일한 반복문)

Go에는 `while`, `do-while`이 없다. `for`가 모든 반복을 담당한다.

```go
// 기본 for
for i := 0; i < 10; i++ {
    fmt.Println(i)
}

// while 스타일
count := 0
for count < 10 {
    count++
}

// 무한 루프
for {
    // break로 탈출
    break
}

// range로 순회
fruits := []string{"apple", "banana", "cherry"}
for index, value := range fruits {
    fmt.Printf("%d: %s\n", index, value)
}

// 인덱스만 필요한 경우
for i := range fruits {
    fmt.Println(i)
}

// 값만 필요한 경우
for _, fruit := range fruits {
    fmt.Println(fruit)
}
```

### switch 문

```go
// 기본 switch (자동 break, fallthrough 없음)
switch day {
case "Monday":
    fmt.Println("월요일")
case "Tuesday", "Wednesday":  // 여러 값 매칭
    fmt.Println("화요일 또는 수요일")
default:
    fmt.Println("기타")
}

// 조건 없는 switch (if-else 대체)
switch {
case score >= 90:
    fmt.Println("A")
case score >= 80:
    fmt.Println("B")
case score >= 70:
    fmt.Println("C")
default:
    fmt.Println("F")
}

// 타입 switch
func describe(i interface{}) {
    switch v := i.(type) {
    case int:
        fmt.Printf("정수: %d\n", v)
    case string:
        fmt.Printf("문자열: %s\n", v)
    case bool:
        fmt.Printf("불리언: %t\n", v)
    default:
        fmt.Printf("알 수 없는 타입: %T\n", v)
    }
}
```

---

## 6. 배열과 슬라이스

### 배열 (Array) - 고정 크기

```go
// 배열 선언 (크기가 타입의 일부)
var arr [5]int                    // [0, 0, 0, 0, 0]
arr2 := [3]string{"a", "b", "c"}
arr3 := [...]int{1, 2, 3, 4, 5}  // 크기 자동 결정

fmt.Println(len(arr))  // 5
arr[0] = 10
```

### 슬라이스 (Slice) - 가변 크기

슬라이스는 Go에서 **가장 많이 사용하는 자료구조**이다. 배열의 동적 버전이다.

```go
// 슬라이스 생성
s1 := []int{1, 2, 3, 4, 5}
s2 := make([]int, 5)       // 길이 5, 용량 5
s3 := make([]int, 3, 10)   // 길이 3, 용량 10

// 슬라이싱
sub := s1[1:3]   // [2, 3] (인덱스 1부터 2까지)
sub2 := s1[:3]   // [1, 2, 3]
sub3 := s1[2:]   // [3, 4, 5]

// append - 요소 추가
s := []int{1, 2, 3}
s = append(s, 4)           // [1, 2, 3, 4]
s = append(s, 5, 6, 7)     // [1, 2, 3, 4, 5, 6, 7]

// 다른 슬라이스 합치기
other := []int{8, 9}
s = append(s, other...)

// 길이와 용량
fmt.Println(len(s))  // 길이 (현재 요소 수)
fmt.Println(cap(s))  // 용량 (할당된 메모리 크기)

// copy
src := []int{1, 2, 3}
dst := make([]int, len(src))
copy(dst, src)
```

### 슬라이스 내부 구조

```
슬라이스 = (포인터, 길이, 용량)

┌──────────┬─────┬─────┐
│ pointer  │ len │ cap │
│ ───────▶ │  3  │  5  │
└──────────┴─────┴─────┘
     │
     ▼
┌───┬───┬───┬───┬───┐
│ 1 │ 2 │ 3 │   │   │  ← 기저 배열 (underlying array)
└───┴───┴───┴───┴───┘
```

---

## 7. 맵 (Map)

```go
// 맵 생성
m1 := map[string]int{
    "apple":  100,
    "banana": 200,
    "cherry": 300,
}

m2 := make(map[string]int)

// 값 설정
m2["key"] = 42

// 값 조회
value := m1["apple"]       // 100

// 존재 여부 확인 (comma ok 패턴)
value, ok := m1["grape"]
if !ok {
    fmt.Println("grape 키가 없습니다")
}

// 삭제
delete(m1, "banana")

// 순회 (순서 보장 안 됨)
for key, value := range m1 {
    fmt.Printf("%s: %d\n", key, value)
}

// 길이
fmt.Println(len(m1))
```

---

## 8. 포인터

Go는 포인터를 지원하지만 **포인터 연산은 지원하지 않는다** (C/C++와 다름).

```go
// 포인터 기본
x := 42
p := &x          // x의 주소를 p에 저장
fmt.Println(*p)  // 42 (역참조)
*p = 100
fmt.Println(x)   // 100 (원본 값이 변경됨)

// 포인터와 함수
func increment(n *int) {
    *n++
}

value := 10
increment(&value)
fmt.Println(value)  // 11

// new로 포인터 생성
p2 := new(int)      // *int 타입, 초기값 0
*p2 = 42
```

### 값 전달 vs 포인터 전달

```go
// 값 전달 - 원본에 영향 없음
func doubleValue(n int) {
    n *= 2  // 복사본만 변경
}

// 포인터 전달 - 원본 변경
func doublePointer(n *int) {
    *n *= 2  // 원본 변경
}

x := 10
doubleValue(x)
fmt.Println(x)   // 10 (변경 안 됨)

doublePointer(&x)
fmt.Println(x)   // 20 (변경됨)
```

---

## 9. 핵심 요약

- Go는 `var`와 `:=`(짧은 선언)으로 변수를 선언하며, 초기화하지 않으면 **제로 값**이 할당된다
- **암시적 타입 변환이 없으므로** 반드시 명시적으로 변환해야 한다
- 함수는 **다중 반환값**을 지원하며, 에러 처리에 활용된다
- `for`가 Go의 **유일한 반복문**이며, `range`로 컬렉션을 순회한다
- **슬라이스**가 Go에서 가장 많이 사용하는 자료구조이며, `append`로 동적 확장한다
- **맵**은 `comma ok` 패턴으로 키 존재 여부를 확인한다
- **포인터**는 지원하지만 포인터 연산은 불가하여 안전하다
- `defer`로 함수 종료 시 실행할 코드를 예약한다 (리소스 해제)

## 참고 자료

- [Go 공식 문서](https://go.dev/doc/)
- [A Tour of Go](https://go.dev/tour/)
- [Go by Example](https://gobyexample.com/)
- [Effective Go](https://go.dev/doc/effective_go)
