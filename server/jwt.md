# JWT (JSON Web Token)

JWT(JSON Web Token)는 당사자 간에 정보를 JSON 객체로 안전하게 전송하기 위한 컴팩트하고 독립적인 방식을 정의하는 개방형 표준(RFC 7519)입니다. 이 정보는 디지털 서명이 되어 있어 신뢰할 수 있습니다.

## JWT의 구조

JWT는 세 부분으로 구성되어 있으며, 각 부분은 점(.)으로 구분됩니다:

1. **헤더(Header)**: 토큰 유형과 사용된 서명 알고리즘을 지정합니다.
   ```json
   {
     "alg": "HS256",
     "typ": "JWT"
   }
   ```

2. **페이로드(Payload)**: 클레임(claim)이라 불리는 엔티티와 추가 데이터를 포함합니다.
   ```json
   {
     "sub": "1234567890",
     "name": "홍길동",
     "admin": true,
     "iat": 1516239022
   }
   ```

3. **서명(Signature)**: 인코딩된 헤더, 인코딩된 페이로드, 비밀키, 헤더에 지정된 알고리즘을 사용하여 생성됩니다.
   ```
   HMACSHA256(
     base64UrlEncode(header) + "." +
     base64UrlEncode(payload),
     secret)
   ```

## JWT의 작동 방식

1. 사용자가 로그인하면 서버는 JWT를 생성합니다.
2. 서버는 이 토큰을 클라이언트에게 반환합니다.
3. 클라이언트는 이후의 요청에서 이 토큰을 Authorization 헤더에 포함시켜 보냅니다.
4. 서버는 토큰을 검증하고 요청을 처리합니다.

## JWT의 장점

1. **무상태(Stateless)**: 서버는 세션 정보를 저장할 필요가 없습니다.
2. **확장성**: 서버 확장이 용이합니다.
3. **분산 시스템**: 여러 서비스에서 동일한 토큰을 사용할 수 있습니다.
4. **보안**: 서명을 통해 데이터 무결성을 보장합니다.

## JWT의 단점

1. **토큰 크기**: 세션 ID에 비해 크기가 큽니다.
2. **저장소**: 클라이언트 측에서 토큰을 안전하게 저장해야 합니다.
3. **무효화**: 발급된 토큰을 즉시 무효화하기 어렵습니다.

## Node.js에서 JWT 구현 예제

```javascript
const jwt = require('jsonwebtoken');
const secret = 'your-secret-key';

// 토큰 생성
function generateToken(user) {
  return jwt.sign(
    { 
      id: user.id, 
      username: user.username 
    }, 
    secret, 
    { 
      expiresIn: '1h' 
    }
  );
}

// 토큰 검증
function verifyToken(token) {
  try {
    return jwt.verify(token, secret);
  } catch (error) {
    throw new Error('유효하지 않은 토큰입니다.');
  }
}

// 미들웨어 예제
function authMiddleware(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: '인증 토큰이 필요합니다.' });
  }
  
  const token = authHeader.split(' ')[1];
  
  try {
    const decoded = verifyToken(token);
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(403).json({ message: '유효하지 않은 토큰입니다.' });
  }
}
```

## JWT 사용 시 보안 고려사항

1. **안전한 비밀키 관리**: 비밀키는 안전하게 보관하고 정기적으로 교체해야 합니다.
2. **HTTPS 사용**: JWT는 항상 HTTPS를 통해 전송해야 합니다.
3. **토큰 만료 시간**: 짧은 만료 시간을 설정하고 필요에 따라 갱신 토큰을 사용합니다.
4. **민감한 정보 제외**: 페이로드에 민감한 정보를 포함하지 않습니다.
5. **XSS 및 CSRF 방어**: 적절한 보안 조치를 취해야 합니다.

## 리프레시 토큰 전략

액세스 토큰의 만료 시간을 짧게 설정하고, 리프레시 토큰을 사용하여 새로운 액세스 토큰을 발급받는 전략입니다.

```javascript
// 리프레시 토큰 생성
function generateRefreshToken(user) {
  return jwt.sign(
    { id: user.id }, 
    refreshSecret, 
    { expiresIn: '7d' }
  );
}

// 토큰 갱신 로직
function refreshAccessToken(refreshToken) {
  try {
    const decoded = jwt.verify(refreshToken, refreshSecret);
    const user = { id: decoded.id, username: '사용자명' }; // 실제로는 DB에서 조회
    return generateToken(user);
  } catch (error) {
    throw new Error('리프레시 토큰이 유효하지 않습니다.');
  }
}
```

## JWT 저장 장소별 특징

JWT를 클라이언트에 저장하는 방법에는 여러 가지가 있으며, 각각 장단점이 있습니다:

### 1. 로컬 스토리지 (localStorage)

**장점:**
- 간편한 API로 쉽게 저장/조회 가능
- 브라우저를 닫아도 데이터가 유지됨
- 용량이 상대적으로 큼 (최소 5MB)

**단점:**
- XSS(Cross-Site Scripting) 공격에 취약함
- JavaScript로 접근 가능하므로 보안에 취약
- 자동으로 요청에 포함되지 않음 (수동으로 헤더에 추가 필요)

### 2. 세션 스토리지 (sessionStorage)

**장점:**
- 로컬 스토리지와 유사한 API
- 탭/창이 닫히면 데이터가 삭제되어 상대적으로 안전

**단점:**
- XSS 공격에 여전히 취약함
- 브라우저 탭을 닫으면 데이터가 사라짐
- 자동으로 요청에 포함되지 않음

### 3. 쿠키 (Cookie)

**장점:**
- HttpOnly 플래그로 JavaScript 접근 방지 가능
- Secure 플래그로 HTTPS 통신만 허용 가능
- 요청 시 자동으로 헤더에 포함됨
- SameSite 속성으로 CSRF 공격 방어 가능

**단점:**
- 용량 제한 (보통 4KB)
- 도메인 당 쿠키 수 제한
- 모든 요청에 포함되어 대역폭 낭비 가능성
- 쿠키 설정이 복잡함

### 4. 웹 스토리지 API (IndexedDB)

**장점:**
- 대용량 데이터 저장 가능
- 복잡한 데이터 구조 지원
- 비동기 API로 성능 좋음

**단점:**
- API가 복잡함
- XSS에 취약함
- 자동으로 요청에 포함되지 않음

### 권장 방식

보안을 최우선으로 한다면:
- 액세스 토큰: HttpOnly, Secure 플래그가 설정된 쿠키에 저장
- 리프레시 토큰: 서버 측 세션 또는 HttpOnly, Secure, SameSite=Strict 쿠키에 저장

SPA(Single Page Application)에서는:
- 액세스 토큰: 메모리(변수)에 저장하고 API 요청 시 헤더에 포함
- 리프레시 토큰: HttpOnly 쿠키에 저장

## 결론

JWT는 현대 웹 애플리케이션에서 인증과 정보 교환을 위한 효율적인 방법을 제공합니다. 그러나 적절한 보안 조치와 함께 사용해야 하며, 애플리케이션의 요구사항에 맞게 구현해야 합니다. 토큰의 저장 위치와 관리 방법은 보안과 사용자 경험 사이의 균형을 고려하여 신중하게 선택해야 합니다.
