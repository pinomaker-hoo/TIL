# Luxon

JavaScript/TypeScript에서 날짜와 시간을 다루기 위한 라이브러리입니다. Moment.js의 후속 느낌으로, **불변 객체, 타임존/로케일 지원, 명확한 API**가 특징입니다.

 <br />
 
 ## 1. 설치 & 기본 설정
 
 ```bash
 npm install luxon
 ```
 
 ```ts
 import { DateTime, Duration, Interval } from 'luxon';
 ```
 
 브라우저 번들 환경에서는 보통 번들러가 해석하고, Node 환경에서는 위처럼 import 해서 사용합니다.
 
 <br />
 
 ## 2. DateTime 기본 개념
 
 - **불변 객체**
   - `DateTime` 인스턴스는 변경 불가.
   - `plus`, `minus`, `set` 등을 호출하면 **새 인스턴스**를 반환.
 - 내부적으로는 `zone`(타임존) + `locale`(언어/포맷) 정보를 함께 가짐.
 
 ```ts
 const now = DateTime.now();
 const seoulNow = now.setZone('Asia/Seoul');
 
 const specific = DateTime.local(2024, 11, 16, 9, 30); // 2024-11-16 09:30 (로컬 타임존)
 ```
 
 유용한 생성 메서드:
 
 - `DateTime.now()` : 현재 시간
 - `DateTime.local(년, 월, 일, 시, 분, 초)`
 - `DateTime.utc(년, 월, 일, 시, 분, 초)`
 
 <br />
 
 ## 3. 파싱(문자열 → DateTime)
 
 ### 3-1. ISO 문자열
 
 ```ts
 const dt = DateTime.fromISO('2024-11-16T09:30:00');
 const dtWithZone = DateTime.fromISO('2024-11-16T09:30:00+09:00');
 ```
 
 ### 3-2. 커스텀 포맷 파싱
 
 ```ts
 const dt = DateTime.fromFormat('2024-11-16 09:30', 'yyyy-LL-dd HH:mm');
 
 if (!dt.isValid) {
   console.log(dt.invalidReason, dt.invalidExplanation);
 }
 ```
 
 자주 쓰는 토큰 예시:
 
 - `yyyy` : 4자리 연도, `LL` : 2자리 월, `dd` : 2자리 일
 - `HH` : 24시간제 시, `mm` : 분, `ss` : 초
 
 <br />
 
 ## 4. 포맷팅(DateTime → 문자열)
 
 ### 4-1. ISO 포맷
 
 ```ts
 DateTime.now().toISO();
 // 예: 2024-11-16T09:30:00.000+09:00
 ```
 
 ### 4-2. 로케일 기반 포맷
 
 ```ts
 const dt = DateTime.now().setZone('Asia/Seoul');
 
 dt.toLocaleString(DateTime.DATETIME_MED); // 2024. 11. 16. 오전 9:30
 dt.toLocaleString(DateTime.DATE_SHORT);   // 24. 11. 16.
 ```
 
 ### 4-3. 커스텀 포맷팅
 
 ```ts
 dt.toFormat('yyyy-LL-dd HH:mm'); // 2024-11-16 09:30
 ```
 
 <br />
 
 ## 5. 타임존과 로케일
 
 - 기본적으로 실행 환경의 로컬 타임존을 사용.
 - `setZone`으로 명시적으로 변경 가능.
 
 ```ts
 const utc = DateTime.utc();
 const seoul = utc.setZone('Asia/Seoul');
 
 seoul.zoneName; // 'Asia/Seoul'
 ```
 
 로케일 설정:
 
 ```ts
 const korean = DateTime.now().setLocale('ko');
 korean.toLocaleString(DateTime.DATE_FULL); // 2024년 11월 16일 토요일
 ```
 
 <br />
 
 ## 6. Duration (기간)
 
 `Duration`은 "몇 시간/몇 분" 같은 **시간량**을 표현합니다.
 
 ```ts
 const duration = Duration.fromObject({ hours: 1, minutes: 30 });
 
 duration.as('minutes'); // 90
 duration.toISO();        // 'PT1H30M'
 ```
 
 `DateTime`과 함께 사용:
 
 ```ts
 const start = DateTime.local(2024, 11, 16, 9, 0);
 const plus90 = start.plus({ minutes: 90 }); // 10:30
 ```
 
 <br />
 
 ## 7. Interval (두 시점 사이 구간)
 
 `Interval`은 두 DateTime 사이의 구간을 표현합니다.
 
 ```ts
 const start = DateTime.local(2024, 11, 16, 9, 0);
 const end = DateTime.local(2024, 11, 16, 18, 0);
 
 const work = Interval.fromDateTimes(start, end);
 
 work.length('hours'); // 9
 work.contains(DateTime.local(2024, 11, 16, 12, 0)); // true
 ```
 
 인터벌 연산:
 
 - `work.splitBy(Duration.fromObject({ hours: 1 }))` : 1시간 단위로 쪼개기
 - `work.overlaps(otherInterval)` : 다른 인터벌과 겹치는지 확인
 
 <br />
 
 ## 8. 자주 쓰는 패턴 메모
 
 - **UTC ↔ 로컬 변환**
   - API 응답(UTC) → 클라이언트 타임존: `DateTime.fromISO(utcStr).setZone('local')`
 - **오늘의 시작/끝 구하기**
 
   ```ts
   const now = DateTime.now();
   const startOfDay = now.startOf('day');
   const endOfDay = now.endOf('day');
   ```
 
 - **두 시간 차이 구하기(분 단위)**
 
   ```ts
   const a = DateTime.fromISO('2024-11-16T09:00:00');
   const b = DateTime.fromISO('2024-11-16T10:30:00');
 
   const diff = b.diff(a, 'minutes').minutes; // 90
   ```
 
 <br />
 
 ## 9. 정리
 
 - Luxon은 **불변 DateTime 객체 + 타임존/로케일 의식적 처리**가 핵심.
 - ISO 문자열 입출력, `setZone`, `toFormat`, `diff`, `Duration`, `Interval` 정도만 익혀도 대부분의 실무 요구를 처리할 수 있음.
 - Moment.js 대비 API가 더 명확하고, Day.js 대비 타임존/로케일 쪽 기능이 더 풍부한 편.
 
 필요하면 이 파일에 **실제 프로젝트에서 자주 쓰는 유틸 함수(예: `toKST`, `formatDateRange`)**를 따로 섹션으로 추가해서 스니펫 모음으로 써도 좋습니다.

 <br />

## 10. 다중 국가(타임존) 지원 전략

여러 국가 사용자가 있는 서비스에서는 보통 다음 원칙으로 설계합니다.

- **저장: 항상 UTC 기준**
- **표시: 각 사용자 타임존으로 변환**
- **비즈니스 로직: 기준 타임존(예: 매장/국가 타임존)을 명확히 정해 사용**

Luxon으로 구현할 때 패턴을 정리해두면 편합니다.

### 10-1. 서버 저장: UTC로 통일

DB에는 가급적 **UTC ISO 문자열** 또는 **epoch milliseconds**로 저장합니다.

```ts
// 서버에서 "지금"을 UTC ISO로 저장
const nowUtc = DateTime.utc();
const stored = nowUtc.toISO(); // 예: 2024-11-16T00:30:00.000Z

// 혹은 숫자 타임스탬프로 저장
const storedMs = nowUtc.toMillis();
```

이미 로컬 타임존 기반 ISO 문자열을 받았다면 반드시 UTC로 정규화해서 저장합니다.

```ts
// 클라이언트에서 Asia/Seoul 기준 시간 문자열이 왔다는 가정
const seoulDt = DateTime.fromISO("2024-11-16T09:00:00", { zone: "Asia/Seoul" });
const utcForStore = seoulDt.toUTC().toISO();
```

### 10-2. 사용자별 타임존으로 표시

사용자 프로필에 `timeZone`을 저장해 두고, 항상 그 타임존으로 변환해 보여줍니다.

```ts
// DB에 저장된 UTC ISO
const storedUtc = "2024-11-16T00:30:00.000Z";
const userTimeZone = "Europe/Berlin";

const dt = DateTime.fromISO(storedUtc, { zone: "utc" }).setZone(userTimeZone);

const label = dt.toFormat("yyyy-LL-dd HH:mm ZZZZ");
// 예: 2024-11-16 01:30 CET
```

다중 국가 서비스라면 `Asia/Seoul`, `America/New_York`, `Europe/London` 등 **IANA 타임존 ID**를 사용해야 서머타임/DST를 제대로 처리할 수 있습니다.

### 10-3. 기준 타임존이 있는 비즈니스 로직

예: "매장 지역 시간 기준으로 매일 09:00에 알림" 같은 로직은 **매장 타임존을 기준**으로 계산해야 합니다.

```ts
const storeZone = "Asia/Tokyo";

// 오늘 매장 09:00
const todayStore9 = DateTime.now()
  .setZone(storeZone)
  .set({ hour: 9, minute: 0, second: 0, millisecond: 0 });

// 이를 UTC로 변환해 스케줄러/백엔드에서 사용
const todayStore9Utc = todayStore9.toUTC();
```

이 패턴을 써두면, 서머타임 변경 시점에도 매장 현지 시간 기준 09:00가 자동으로 맞춰집니다.

### 10-4. 사용자 설정과 기본값

- 가능한 경우 **사용자 프로필에 timeZone 필드를 저장** (예: `Asia/Seoul`).
- 없을 때는 브라우저/클라이언트의 로컬 타임존을 기본값으로 사용.

```ts
// 클라이언트에서 브라우저 타임존 추론 후 서버에 저장
const browserZone = DateTime.local().zoneName; // 예: 'Asia/Seoul'
```

서버에서 "사용자 타임존이 없을 때"의 처리 정책을 문서화해 두는 것이 좋습니다.

### 10-5. 자주 발생하는 함정 정리

- **UTC로 저장하지 않고 지역 시간을 그대로 저장**
  - 국가/서머타임 변경 시점에 계산이 꼬이기 쉽습니다.
- **타임존 없이 날짜만 저장할 때**
  - 생일, 기념일처럼 "타임존과 무관한 날짜"는 `yyyy-MM-dd` **문자열 그대로**를 저장하고, 어떤 타임존에서도 같은 날짜로 표시하는 것이 일반적입니다.
- **DST(서머타임) 전날/당일 계산**
  - 반드시 IANA 타임존(`America/New_York` 등) + Luxon과 같은 라이브러리를 사용해 계산해야 안전합니다.
- **Date 객체와 섞어 쓰기**
  - `new Date()`와 `DateTime`을 혼용하면, 어디에서 타임존이 적용됐는지 헷갈리기 쉽습니다.
  - 가능한 한 "입력부터 출력까지 Luxon 일관 사용"을 목표로 합니다.

이 섹션의 내용은 나중에 실제 프로젝트에 적용할 때, "저장/표시/비즈니스 로직" 3단계 관점으로 다시 체크리스트처럼 활용하면 좋습니다.
