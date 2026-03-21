# Go 구조체와 인터페이스

> Go는 클래스가 없는 대신 구조체(Struct)와 인터페이스(Interface)를 통해 데이터와 행위를 정의한다. Go의 타입 시스템과 객체지향 패턴을 정리한다.

## 목차

1. [구조체 (Struct)](#1-구조체-struct)
2. [메서드 (Method)](#2-메서드-method)
3. [인터페이스 (Interface)](#3-인터페이스-interface)
4. [임베딩 (Embedding)](#4-임베딩-embedding)
5. [빈 인터페이스와 타입 단언](#5-빈-인터페이스와-타입-단언)
6. [핵심 요약](#6-핵심-요약)

---

## 1. 구조체 (Struct)

구조체는 **관련 데이터를 하나로 묶는 타입**이다. 다른 언어의 클래스와 유사한 역할을 한다.

### 구조체 정의와 생성

```go
// 구조체 정의
type User struct {
    ID        int
    Name      string
    Email     string
    Age       int
    IsActive  bool
}

// 생성 방법 1: 필드 이름 지정
u1 := User{
    ID:    1,
    Name:  "Alice",
    Email: "alice@example.com",
    Age:   25,
}

// 생성 방법 2: 순서대로 (권장하지 않음)
u2 := User{2, "Bob", "bob@example.com", 30, true}

// 생성 방법 3: 제로 값으로 생성 후 설정
var u3 User
u3.Name = "Charlie"
u3.Email = "charlie@example.com"

// 포인터로 생성
u4 := &User{
    Name:  "Diana",
    Email: "diana@example.com",
}

// new 사용 (모든 필드 제로 값)
u5 := new(User)  // *User 타입
u5.Name = "Eve"
```

### 구조체 태그

JSON, DB 매핑 등에 사용되는 메타데이터이다.

```go
type User struct {
    ID        int    `json:"id" db:"user_id"`
    Name      string `json:"name" db:"user_name"`
    Email     string `json:"email" db:"email"`
    Password  string `json:"-"`                     // JSON에서 제외
    CreatedAt string `json:"created_at,omitempty"`   // 비어있으면 생략
}

import "encoding/json"

u := User{ID: 1, Name: "Alice", Email: "alice@example.com"}
data, _ := json.Marshal(u)
fmt.Println(string(data))
// {"id":1,"name":"Alice","email":"alice@example.com"}
```

### 생성자 패턴

Go에는 생성자가 없으므로, 관례적으로 `New` 접두사를 붙인 팩토리 함수를 사용한다.

```go
func NewUser(name, email string) *User {
    return &User{
        Name:     name,
        Email:    email,
        IsActive: true,
    }
}

u := NewUser("Alice", "alice@example.com")
```

---

## 2. 메서드 (Method)

메서드는 **특정 타입에 연결된 함수**이다. 리시버(Receiver)를 통해 타입과 연결된다.

### 값 리시버와 포인터 리시버

```go
type Rectangle struct {
    Width  float64
    Height float64
}

// 값 리시버 - 구조체를 복사하여 사용 (원본 변경 불가)
func (r Rectangle) Area() float64 {
    return r.Width * r.Height
}

// 포인터 리시버 - 원본 구조체를 직접 수정 가능
func (r *Rectangle) Scale(factor float64) {
    r.Width *= factor
    r.Height *= factor
}

rect := Rectangle{Width: 10, Height: 5}
fmt.Println(rect.Area())   // 50

rect.Scale(2)
fmt.Println(rect.Area())   // 200
```

### 리시버 선택 기준

| 상황 | 리시버 타입 |
|------|------------|
| 필드를 수정해야 할 때 | 포인터 리시버 (`*T`) |
| 구조체가 클 때 (복사 비용 절감) | 포인터 리시버 (`*T`) |
| 읽기 전용 메서드 | 값 리시버 (`T`) 또는 포인터 리시버 |
| 일관성 유지 | 하나의 타입에서 통일 (보통 포인터 리시버) |

```go
// ✅ 포인터 리시버 사용 (필드 수정)
func (u *User) UpdateEmail(email string) {
    u.Email = email
}

// ✅ 값 리시버 사용 (읽기만)
func (u User) FullName() string {
    return u.Name
}
```

### 기본 타입에도 메서드 정의 가능

```go
// 사용자 정의 타입 필요
type StringSlice []string

func (ss StringSlice) Contains(target string) bool {
    for _, s := range ss {
        if s == target {
            return true
        }
    }
    return false
}

fruits := StringSlice{"apple", "banana", "cherry"}
fmt.Println(fruits.Contains("banana"))  // true
```

---

## 3. 인터페이스 (Interface)

Go의 인터페이스는 **암시적으로 구현(Implicit Implementation)**된다. 별도의 `implements` 키워드가 없으며, 메서드를 모두 구현하면 자동으로 인터페이스를 만족한다.

### 인터페이스 정의와 구현

```go
// 인터페이스 정의
type Shape interface {
    Area() float64
    Perimeter() float64
}

// Circle이 Shape를 구현 (명시적 선언 불필요!)
type Circle struct {
    Radius float64
}

func (c Circle) Area() float64 {
    return math.Pi * c.Radius * c.Radius
}

func (c Circle) Perimeter() float64 {
    return 2 * math.Pi * c.Radius
}

// Rectangle도 Shape를 구현
type Rectangle struct {
    Width, Height float64
}

func (r Rectangle) Area() float64 {
    return r.Width * r.Height
}

func (r Rectangle) Perimeter() float64 {
    return 2 * (r.Width + r.Height)
}

// 인터페이스로 다형성 구현
func PrintShapeInfo(s Shape) {
    fmt.Printf("면적: %.2f, 둘레: %.2f\n", s.Area(), s.Perimeter())
}

PrintShapeInfo(Circle{Radius: 5})
PrintShapeInfo(Rectangle{Width: 10, Height: 5})
```

### 자주 사용하는 표준 인터페이스

```go
// fmt.Stringer - 문자열 표현 (Java의 toString()과 유사)
type Stringer interface {
    String() string
}

func (u User) String() string {
    return fmt.Sprintf("User{Name: %s, Email: %s}", u.Name, u.Email)
}

// io.Reader - 데이터 읽기
type Reader interface {
    Read(p []byte) (n int, err error)
}

// io.Writer - 데이터 쓰기
type Writer interface {
    Write(p []byte) (n int, err error)
}

// error - 에러 인터페이스
type error interface {
    Error() string
}
```

### 인터페이스 조합

작은 인터페이스를 조합하여 큰 인터페이스를 만들 수 있다.

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}

type Writer interface {
    Write(p []byte) (n int, err error)
}

// Reader와 Writer를 조합
type ReadWriter interface {
    Reader
    Writer
}
```

> Go 커뮤니티에서는 **작은 인터페이스를 선호**한다. 메서드가 1~2개인 인터페이스가 이상적이다.

---

## 4. 임베딩 (Embedding)

Go는 상속 대신 **컴포지션(Composition)**을 사용한다. 구조체 임베딩으로 코드를 재사용한다.

### 구조체 임베딩

```go
type Address struct {
    City    string
    Country string
}

type Person struct {
    Name string
    Age  int
}

// Employee에 Person과 Address를 임베딩
type Employee struct {
    Person           // 임베딩 (필드 이름 없이 타입만)
    Address          // 임베딩
    Company  string
    Position string
}

emp := Employee{
    Person:   Person{Name: "Alice", Age: 30},
    Address:  Address{City: "Seoul", Country: "Korea"},
    Company:  "Google",
    Position: "Engineer",
}

// 임베딩된 필드에 직접 접근 가능 (프로모션)
fmt.Println(emp.Name)    // "Alice" (emp.Person.Name과 동일)
fmt.Println(emp.City)    // "Seoul" (emp.Address.City와 동일)
fmt.Println(emp.Company) // "Google"
```

### 임베딩과 메서드

```go
type Animal struct {
    Name string
}

func (a Animal) Speak() string {
    return a.Name + " makes a sound"
}

type Dog struct {
    Animal       // Animal 임베딩
    Breed string
}

// Dog에서 Animal의 메서드를 사용 가능
dog := Dog{
    Animal: Animal{Name: "Buddy"},
    Breed:  "Labrador",
}
fmt.Println(dog.Speak())  // "Buddy makes a sound"

// 메서드 오버라이드
func (d Dog) Speak() string {
    return d.Name + " barks!"
}
fmt.Println(dog.Speak())  // "Buddy barks!"
```

---

## 5. 빈 인터페이스와 타입 단언

### 빈 인터페이스 (any)

`interface{}` (또는 Go 1.18+의 `any`)는 **모든 타입을 받을 수 있다**.

```go
func printAnything(v any) {
    fmt.Println(v)
}

printAnything(42)
printAnything("hello")
printAnything(true)
printAnything([]int{1, 2, 3})
```

### 타입 단언 (Type Assertion)

```go
var i interface{} = "hello"

// 타입 단언
s := i.(string)
fmt.Println(s)  // "hello"

// 안전한 타입 단언 (comma ok 패턴)
s, ok := i.(string)
if ok {
    fmt.Println("문자열:", s)
}

n, ok := i.(int)
if !ok {
    fmt.Println("int가 아닙니다")  // 이 줄이 실행됨
}
```

### 타입 스위치

```go
func describe(i interface{}) string {
    switch v := i.(type) {
    case int:
        return fmt.Sprintf("정수: %d", v)
    case string:
        return fmt.Sprintf("문자열: %s", v)
    case bool:
        return fmt.Sprintf("불리언: %t", v)
    case []int:
        return fmt.Sprintf("정수 슬라이스: 길이 %d", len(v))
    default:
        return fmt.Sprintf("알 수 없음: %T", v)
    }
}
```

---

## 6. 핵심 요약

- **구조체**는 관련 데이터를 묶는 Go의 핵심 타입이며, **태그**로 JSON/DB 매핑 메타데이터를 추가한다
- **메서드**는 리시버를 통해 타입에 연결하며, **포인터 리시버**로 원본을 수정할 수 있다
- **인터페이스**는 암시적으로 구현되며, 메서드를 모두 구현하면 자동으로 인터페이스를 만족한다
- Go는 상속 대신 **임베딩(컴포지션)**을 사용하여 코드를 재사용한다
- **빈 인터페이스**(`any`)는 모든 타입을 받을 수 있으며, **타입 단언**으로 원래 타입을 복원한다
- Go 커뮤니티에서는 **작은 인터페이스**(메서드 1~2개)를 선호한다

## 참고 자료

- [Go 공식 문서 - Structs](https://go.dev/tour/moretypes/2)
- [Go 공식 문서 - Interfaces](https://go.dev/tour/methods/9)
- [Effective Go - Interfaces](https://go.dev/doc/effective_go#interfaces)
