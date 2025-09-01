# 쿠키(Cookie)

쿠키는 웹 서버가 사용자의 웹 브라우저에 전송하는 작은 데이터 조각으로, 브라우저는 이를 저장했다가 동일한 서버에 재요청 시 함께 전송합니다. 쿠키는 상태가 없는(stateless) HTTP 프로토콜에서 상태 정보를 유지하기 위한 방법으로 사용됩니다.

## 쿠키의 기본 개념

쿠키는 이름-값 쌍으로 구성되며, 만료일, 경로, 도메인, 보안 설정 등의 추가 속성을 가질 수 있습니다. 쿠키는 주로 다음과 같은 목적으로 사용됩니다:

1. **세션 관리**: 로그인 정보, 장바구니, 게임 점수 등 서버가 기억해야 할 정보 저장
2. **개인화**: 사용자 선호도, 테마 등 사용자 설정 저장
3. **트래킹**: 사용자 행동 분석 및 기록

## 쿠키 생성 및 설정

### 서버 측에서 쿠키 설정 (Node.js 예제)

```javascript
// Express.js를 사용한 예제
app.get('/set-cookie', (req, res) => {
  // 기본 쿠키 설정
  res.cookie('username', '홍길동');
  
  // 옵션이 포함된 쿠키 설정
  res.cookie('preferences', 'dark-mode', {
    maxAge: 86400000, // 1일 (밀리초 단위)
    httpOnly: true,   // JavaScript에서 접근 불가
    secure: true,     // HTTPS에서만 전송
    sameSite: 'strict' // CSRF 방지
  });
  
  res.send('쿠키가 설정되었습니다.');
});
```

### 클라이언트 측에서 쿠키 설정 (JavaScript)

```javascript
// 기본 쿠키 설정
document.cookie = "username=홍길동";

// 만료일이 포함된 쿠키 설정
document.cookie = "username=홍길동; expires=Thu, 18 Dec 2025 12:00:00 UTC";

// 경로가 지정된 쿠키
document.cookie = "username=홍길동; path=/";
```

## 쿠키 속성

### 주요 속성

1. **Domain**: 쿠키가 전송될 도메인 지정
   ```
   Set-Cookie: name=value; Domain=example.com
   ```

2. **Path**: 쿠키가 전송될 URL 경로 지정
   ```
   Set-Cookie: name=value; Path=/docs
   ```

3. **Expires/Max-Age**: 쿠키 만료 시간 설정
   ```
   Set-Cookie: name=value; Expires=Wed, 21 Oct 2025 07:28:00 GMT
   Set-Cookie: name=value; Max-Age=86400 // 초 단위, 1일
   ```

4. **Secure**: HTTPS 연결에서만 쿠키 전송
   ```
   Set-Cookie: name=value; Secure
   ```

5. **HttpOnly**: JavaScript에서 쿠키 접근 방지
   ```
   Set-Cookie: name=value; HttpOnly
   ```

6. **SameSite**: CSRF 공격 방지를 위한 설정
   ```
   Set-Cookie: name=value; SameSite=Strict
   Set-Cookie: name=value; SameSite=Lax
   Set-Cookie: name=value; SameSite=None; Secure
   ```

## 쿠키 읽기

### 서버 측에서 쿠키 읽기 (Node.js 예제)

```javascript
// Express.js와 cookie-parser 미들웨어 사용
const express = require('express');
const cookieParser = require('cookie-parser');
const app = express();

app.use(cookieParser());

app.get('/get-cookie', (req, res) => {
  const username = req.cookies.username;
  res.send(`안녕하세요, ${username || '손님'}님!`);
});
```

### 클라이언트 측에서 쿠키 읽기 (JavaScript)

```javascript
// 모든 쿠키 문자열 가져오기
const allCookies = document.cookie;

// 특정 쿠키 값 추출하는 함수
function getCookie(name) {
  const cookieArr = document.cookie.split(';');
  
  for(let i = 0; i < cookieArr.length; i++) {
    const cookiePair = cookieArr[i].split('=');
    const cookieName = cookiePair[0].trim();
    
    if(cookieName === name) {
      return decodeURIComponent(cookiePair[1]);
    }
  }
  
  return null;
}

// 사용 예
const username = getCookie('username');
console.log(`안녕하세요, ${username || '손님'}님!`);
```

## 쿠키 삭제

### 서버 측에서 쿠키 삭제 (Node.js 예제)

```javascript
app.get('/clear-cookie', (req, res) => {
  res.clearCookie('username');
  res.send('쿠키가 삭제되었습니다.');
});
```

### 클라이언트 측에서 쿠키 삭제 (JavaScript)

```javascript
// 만료일을 과거로 설정하여 쿠키 삭제
document.cookie = "username=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;";
```

## 쿠키의 한계와 주의사항

1. **크기 제한**: 쿠키 하나당 약 4KB로 제한됨
2. **개수 제한**: 도메인당 약 50개의 쿠키로 제한됨
3. **보안 위험**: 적절한 보안 설정 없이 민감한 정보를 저장하면 XSS, CSRF 등의 공격에 취약
4. **성능 영향**: 모든 HTTP 요청에 쿠키가 포함되어 대역폭 낭비 가능성
5. **사용자 추적 우려**: 개인정보 보호 관련 법규 준수 필요 (GDPR, CCPA 등)

## 쿠키 vs 로컬 스토리지 vs 세션 스토리지

| 특성 | 쿠키 | 로컬 스토리지 | 세션 스토리지 |
|------|------|--------------|--------------|
| 용량 | ~4KB | ~5MB | ~5MB |
| 만료 | 설정 가능 | 영구 | 탭 종료 시 |
| HTTP 요청 | 자동 전송 | 전송 안 됨 | 전송 안 됨 |
| API | 복잡함 | 간단함 | 간단함 |
| 접근성 | 서버/클라이언트 | 클라이언트만 | 클라이언트만 |
| 보안 옵션 | 다양함 | 제한적 | 제한적 |

## 쿠키와 JWT 함께 사용하기

JWT를 쿠키에 저장하는 방식은 보안과 편의성의 균형을 제공합니다:

```javascript
// JWT를 HttpOnly 쿠키에 저장하는 예제
app.post('/login', (req, res) => {
  // 사용자 인증 로직...
  const token = generateJWT(user);
  
  // JWT를 쿠키에 저장
  res.cookie('access_token', token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    maxAge: 3600000, // 1시간
    sameSite: 'strict'
  });
  
  res.redirect('/dashboard');
});

// 인증 미들웨어
const authenticate = (req, res, next) => {
  const token = req.cookies.access_token;
  
  if (!token) {
    return res.status(401).send('인증이 필요합니다');
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).send('유효하지 않은 토큰입니다');
  }
};
```

## 결론

쿠키는 웹 개발에서 상태 관리를 위한 기본적인 도구이지만, 적절한 보안 설정과 함께 사용해야 합니다. 현대 웹 애플리케이션에서는 쿠키, 로컬 스토리지, JWT 등을 상황에 맞게 조합하여 사용하는 것이 일반적입니다. 특히 인증 시스템 구현 시에는 HttpOnly, Secure, SameSite 등의 보안 속성을 적극 활용하여 XSS, CSRF 등의 공격으로부터 사용자를 보호해야 합니다.
