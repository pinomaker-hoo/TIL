# Day.js vs Luxon

다음은 Day.js와 Luxon을 비교하면서, 어떤 상황에서 어떤 라이브러리를 선택할지 정리한 노트입니다.

<br />

## 1. 한 줄 요약

- **Day.js**

  - Moment.js와 거의 동일한 API를 가진 **가벼운 대체제**.
  - 플러그인 구조로 기능을 확장.
  - 기본적으로는 타임존/로케일보다는 "Moment 스타일 문법"에 익숙한 사람에게 유리.

- **Luxon**
  - Moment 팀이 주도한 **차세대 날짜/시간 라이브러리**.
  - 불변 객체, 타임존/로케일 내장, 명확한 타입 정보.
  - 다중 타임존, 서머타임, 국제 서비스 등에서 설계가 더 깔끔함.

<br />

## 2. 공통점

- 둘 다 **Moment.js를 대체**하기 위한 라이브러리.
- 날짜/시간 파싱, 포맷팅, 연산(plus/minus), 비교 등을 제공.
- npm 기반 JS/TS 프로젝트 어디서나 사용 가능.

<br />

## 3. 주요 차이점

### 3-1. API 스타일

- **Day.js**

  - `dayjs()` 함수로 래핑된 객체를 사용.
  - 체이닝 기반 문법 (Moment와 거의 동일).
  - 예시:

    ```ts
    import dayjs from "dayjs";

    const now = dayjs();
    const plus1Day = now.add(1, "day");
    const formatted = plus1Day.format("YYYY-MM-DD HH:mm");
    ```

- **Luxon**

  - `DateTime` 클래스를 사용.
  - 메서드 이름이 비교적 명확하고, zone/locale을 속성으로 포함.
  - 예시:

    ```ts
    import { DateTime } from "luxon";

    const now = DateTime.now();
    const plus1Day = now.plus({ days: 1 });
    const formatted = plus1Day.toFormat("yyyy-LL-dd HH:mm");
    ```

### 3-2. 불변성(immutability)

- **Day.js**
  - 기본적으로도 불변이지만, Moment와의 호환성 때문에 감각적으로 혼동될 수 있음.
- **Luxon**
  - `DateTime`은 명확하게 불변 객체.
  - `plus`, `minus`, `set` 등은 항상 새 인스턴스를 반환.

실무에서는 "인스턴스를 재사용하다가 의도치 않게 값이 바뀌는" 버그를 피할 수 있다는 점에서 Luxon 쪽이 좀 더 안전한 느낌.

### 3-3. 타임존

- **Day.js**

  - 기본 패키지에는 타임존 기능이 없음.
  - `dayjs/plugin/timezone`, `dayjs/plugin/utc` 등을 플러그인으로 추가해야 함.
  - IANA 타임존 데이터도 별도의 의존성(`moment-timezone`처럼) 또는 빌드 단계에서 주입 필요.

- **Luxon**
  - 타임존 개념이 **핵심 1급 시민**.
  - `setZone('Asia/Seoul')`, `toUTC()` 등을 바로 사용.
  - Node 환경에서는 기본적으로 IANA 타임존 사용 가능, 브라우저에서는 환경에 따라 Intl 지원 필요.

다중 국가/타임존을 제대로 다루는 서비스라면, Luxon 쪽이 설계가 더 단순하고 일관적입니다.

### 3-4. 로케일 & 포맷팅

- **Day.js**

  - 로케일/포맷팅도 플러그인 구조 (`locale`, `localizedFormat` 등).
  - Moment 스타일 포맷 문자열 `YYYY`, `MM`, `DD`, `HH` 등을 그대로 사용.

- **Luxon**
  - Intl API 기반 로케일 처리 (`toLocaleString`, `setLocale`).
  - 커스텀 포맷은 자체 토큰(`yyyy`, `LL`, `dd` 등) 사용.
  - 로케일별 긴/짧은 형식은 `DateTime.DATE_FULL`, `DateTime.DATETIME_MED` 등 상수로 제공.

### 3-5. 설계 철학/모델

- **Day.js**

  - 목표: "Moment처럼 쓰되 더 가볍게".
  - 기존 Moment 코드 마이그레이션에 유리.
  - 플러그인으로 필요한 것만 추가해서 번들 크기를 제어.

- **Luxon**
  - 목표: "Intl + 명시적 타임존/로케일 기반의 새로운 모델".
  - Date/Time/Duration/Interval이 각각 명확한 타입으로 분리.
  - 다중 타임존, 인력/급여/예약 시스템 등 **시간 관련 도메인 로직**에 잘 맞음.

### 3-6. 타입스크립트 지원

- 둘 다 타입 정의를 제공하지만, Luxon의 경우 `DateTime`, `Duration`, `Interval` 등 **도메인 모델이 명확한 타입**으로 분리되어 있어 TS에서 다루기 편한 편.
- Day.js는 기본 인스턴스 타입이 단일 클래스 느낌이라, "지금 이 값이 무엇을 의미하는지"는 네이밍/컨벤션에 더 많이 의존.

<br />

## 4. 언제 Day.js를, 언제 Luxon을 쓸까?

### Day.js를 고려할 경우

- 기존 **Moment.js 스타일**에 익숙하고, 마이그레이션 비용을 최소화하고 싶을 때.
- 타임존/로케일 요구사항이 비교적 단순하고, 주로 "사용자 로컬 시간" 정도만 다루는 SPA/프런트엔드.
- 번들 크기를 최대한 줄여야 하고, 필요한 기능만 플러그인으로 골라 쓰고 싶은 경우.

### Luxon을 고려할 경우

- **여러 국가/타임존**을 진지하게 다루는 서비스 (예약, 스케줄링, 출퇴근, 결제 마감 시각 등).
- 서버/백엔드에서 시간 계산 로직이 중요한 도메인 (예: 결제 정산, 근무 시간 계산, 리포트 등).
- 불변 객체, 명확한 타입 구조, Duration/Interval 등 **시간 도메인 모델**을 적극 활용하고 싶을 때.

<br />

## 5. 개인적인 선택 기준 (메모)

- "단순한 프론트 UI, 로컬 시간 표시가 대부분" → **Day.js도 충분**.
- "다중 타임존, DST, 시간 차 계산이 중요한 백엔드/도메인" → **Luxon 선호**.
- 기존 프로젝트가 Moment 기반이면 Day.js로 옮기는 게 덜 아프지만,
  새 프로젝트이거나 시간 도메인이 복잡하다면 Luxon으로 설계하는 편이 장기적으로 깔끔.

이 문서는 단순 비교 정리이므로, 자세한 코드는 `luxon/index.md`와 별도 Day.js 노트에 더 추가해서 실습 위주로 정리하면 좋습니다.
