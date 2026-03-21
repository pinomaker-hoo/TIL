# Turborepo

> Turborepo는 Vercel에서 개발한 고성능 JavaScript/TypeScript 모노레포 빌드 시스템으로, 증분 빌드와 스마트 캐싱을 통해 빌드 속도를 극적으로 향상시킨다.

## 목차

1. [Turborepo란 무엇인가?](#1-turborepo란-무엇인가)
2. [핵심 개념과 아키텍처](#2-핵심-개념과-아키텍처)
3. [설치 및 초기 설정](#3-설치-및-초기-설정)
4. [프로젝트 구조](#4-프로젝트-구조)
5. [주요 CLI 명령어](#5-주요-cli-명령어)
6. [Task Pipeline 설정](#6-task-pipeline-설정)
7. [캐싱 메커니즘](#7-캐싱-메커니즘)
8. [Remote Caching](#8-remote-caching)
9. [장점과 단점](#9-장점과-단점)
10. [실전 활용 사례](#10-실전-활용-사례)
11. [핵심 요약](#11-핵심-요약)

---

## 1. Turborepo란 무엇인가?

Turborepo는 **Vercel**에서 개발하고 유지보수하는 고성능 모노레포 빌드 시스템이다. 2021년 Jared Palmer이 처음 만들었고, 2022년 Vercel에 인수된 후 **Rust로 재작성**되어 성능이 크게 향상되었다.

Turborepo의 핵심 철학은 다음과 같다:

- **제로 설정(Zero Config)** - 최소한의 설정으로 바로 사용 가능
- **점진적 도입** - 기존 프로젝트에 쉽게 추가 가능
- **패키지 매니저 위에서 동작** - npm/yarn/pnpm 워크스페이스를 그대로 활용
- **같은 일을 두 번 하지 않는다** - 스마트 캐싱으로 불필요한 작업 제거

---

## 2. 핵심 개념과 아키텍처

### Workspace (워크스페이스)

Turborepo는 패키지 매니저의 워크스페이스 기능 위에서 동작한다. npm, yarn, pnpm의 워크스페이스를 그대로 사용하며, 별도의 워크스페이스 관리 레이어를 추가하지 않는다.

```
패키지 매니저 워크스페이스 (npm/yarn/pnpm)
          ↕
      Turborepo (빌드 오케스트레이션 + 캐싱)
          ↕
    각 패키지의 package.json scripts
```

### Task Graph (태스크 그래프)

Turborepo는 `turbo.json`의 파이프라인 설정을 기반으로 태스크 그래프를 생성한다. 태스크 간 의존성을 분석하고, 가능한 한 많은 태스크를 **병렬로 실행**한다.

```
# turbo run build 실행 시 (web → ui → utils 의존 관계)

┌──────────────┐
│ build:utils  │ ────┐
└──────────────┘     │
                     ▼
┌──────────────┐  ┌──────────────┐
│ build:config │  │  build:ui    │ ────┐
└──────────────┘  └──────────────┘     │
                                       ▼
                  ┌──────────────┐  ┌──────────────┐
                  │  build:api   │  │  build:web   │
                  └──────────────┘  └──────────────┘
```

### Content Hash (콘텐츠 해시)

Turborepo는 파일 내용 기반의 해시를 사용하여 태스크의 캐시 유효성을 판단한다.

```
해시 = hash(
  소스 파일 내용 +
  의존 패키지의 해시 +
  환경 변수 +
  turbo.json 설정 +
  lockfile 내용
)
```

### Cache (캐시)

태스크 실행 결과(출력 파일 + 로그)를 해시 키와 함께 저장한다. 동일한 해시가 나오면 캐시에서 결과를 복원한다.

---

## 3. 설치 및 초기 설정

### 새 Turborepo 프로젝트 생성

```bash
# 새 Turborepo 프로젝트 생성
npx create-turbo@latest my-turborepo

# 패키지 매니저 선택
# ? Which package manager do you want to use?
#   > npm
#     yarn
#     pnpm (권장)
```

### 기존 프로젝트에 Turborepo 추가

```bash
# 프로젝트에 turbo 설치
npm install turbo --save-dev

# 또는 글로벌 설치
npm install --global turbo
```

### turbo.json 설정

워크스페이스 루트에 위치하는 핵심 설정 파일이다.

```json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": ["**/.env.*local"],
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "lint": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"],
      "inputs": ["src/**/*.tsx", "src/**/*.ts", "test/**/*.ts"]
    }
  }
}
```

> **참고**: Turborepo v2부터 `pipeline` 키가 `tasks`로 변경되었다. 최신 버전에서는 `tasks`를 사용한다.

### 패키지 매니저 워크스페이스 설정

**pnpm (권장)**

```yaml
# pnpm-workspace.yaml
packages:
  - "apps/*"
  - "packages/*"
```

**npm/yarn**

```json
// package.json (루트)
{
  "name": "my-turborepo",
  "private": true,
  "workspaces": [
    "apps/*",
    "packages/*"
  ]
}
```

---

## 4. 프로젝트 구조

### 기본 디렉토리 구조

```
my-turborepo/
├── apps/
│   ├── web/                      # Next.js 프론트엔드
│   │   ├── src/
│   │   ├── package.json          # 앱별 의존성 및 스크립트
│   │   ├── next.config.js
│   │   └── tsconfig.json
│   └── api/                      # Express/Fastify 백엔드
│       ├── src/
│       ├── package.json
│       └── tsconfig.json
├── packages/
│   ├── ui/                       # 공유 UI 컴포넌트
│   │   ├── src/
│   │   │   ├── button.tsx
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── utils/                    # 공유 유틸리티
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── eslint-config/            # 공유 ESLint 설정
│   │   ├── index.js
│   │   └── package.json
│   └── typescript-config/        # 공유 TypeScript 설정
│       ├── base.json
│       ├── nextjs.json
│       ├── react-library.json
│       └── package.json
├── turbo.json                    # Turborepo 설정
├── package.json                  # 루트 패키지
├── pnpm-workspace.yaml           # pnpm 워크스페이스 설정
└── pnpm-lock.yaml
```

### apps vs packages 패턴

- **apps/** - 배포 가능한 애플리케이션 (웹앱, API 서버, 모바일 앱 등)
- **packages/** - 내부에서 공유하는 라이브러리, 설정, 도구

### Internal Packages (내부 패키지)

Turborepo에서 패키지 간 의존성은 `package.json`의 `dependencies`를 통해 관리한다.

```json
// packages/ui/package.json
{
  "name": "@my-turborepo/ui",
  "version": "0.0.0",
  "private": true,
  "exports": {
    ".": "./src/index.ts"
  },
  "scripts": {
    "build": "tsup src/index.ts --format cjs,esm --dts",
    "lint": "eslint src/"
  }
}
```

```json
// apps/web/package.json
{
  "name": "web",
  "dependencies": {
    "@my-turborepo/ui": "workspace:*",
    "@my-turborepo/utils": "workspace:*"
  }
}
```

```tsx
// apps/web/src/app/page.tsx
import { Button } from '@my-turborepo/ui';
import { formatDate } from '@my-turborepo/utils';

export default function Home() {
  return (
    <div>
      <h1>Welcome</h1>
      <p>{formatDate(new Date())}</p>
      <Button>Click me</Button>
    </div>
  );
}
```

---

## 5. 주요 CLI 명령어

### 기본 명령어

```bash
# 모든 패키지의 build 태스크 실행
turbo run build

# 모든 패키지의 dev 태스크 실행
turbo run dev

# 여러 태스크 동시 실행
turbo run build lint test
```

### --filter 필터링

특정 패키지만 대상으로 태스크를 실행한다.

```bash
# 특정 패키지만 빌드
turbo run build --filter=web

# 특정 패키지와 그 의존성 모두 빌드
turbo run build --filter=web...

# 디렉토리 기반 필터
turbo run build --filter=./apps/web

# 특정 패키지 제외
turbo run build --filter=!api

# 변경된 패키지만 (git diff 기반)
turbo run build --filter=...[HEAD~1]
```

### --dry-run 시뮬레이션

실제 실행 없이 어떤 태스크가 실행될지 확인한다.

```bash
$ turbo run build --dry-run

# 출력 예시:
# Tasks to Run
# • web#build
#   └── depends on: @my-turborepo/ui#build
# • @my-turborepo/ui#build
#   └── depends on: @my-turborepo/utils#build
# • @my-turborepo/utils#build
#   └── no dependencies
```

### --graph 태스크 그래프 시각화

```bash
# 브라우저에서 태스크 그래프 확인
turbo run build --graph

# SVG 파일로 출력
turbo run build --graph=graph.svg
```

### turbo prune

배포 시 특정 패키지와 그 의존성만 추출하여 경량화된 모노레포를 생성한다.

```bash
# web 앱과 의존성만 추출
turbo prune web

# 결과: out/ 디렉토리 생성
# out/
# ├── json/                    # 패키지 잠금 파일
# │   ├── apps/web/package.json
# │   └── packages/ui/package.json
# ├── full/                    # 전체 소스 코드
# │   ├── apps/web/
# │   └── packages/ui/
# └── pnpm-lock.yaml
```

Docker에서 특히 유용하다:

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app
COPY . .
RUN npx turbo prune web --docker

# pruned 결과로 빌드
FROM node:20-alpine AS installer
WORKDIR /app
COPY --from=builder /app/out/json/ .
RUN pnpm install

COPY --from=builder /app/out/full/ .
RUN pnpm turbo run build --filter=web
```

---

## 6. Task Pipeline 설정

### tasks 설정 상세

`turbo.json`의 `tasks`에서 태스크 간 관계와 동작을 정의한다.

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**", "!.next/cache/**"],
      "inputs": ["src/**", "package.json", "tsconfig.json"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"],
      "inputs": ["src/**", "test/**"]
    },
    "lint": {
      "dependsOn": [],
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "deploy": {
      "dependsOn": ["build", "test", "lint"],
      "outputs": []
    }
  }
}
```

### 주요 설정 옵션

| 옵션 | 설명 | 예시 |
|------|------|------|
| `dependsOn` | 선행 태스크 지정 | `["^build"]`, `["build"]` |
| `outputs` | 캐시에 저장할 출력 경로 | `["dist/**"]` |
| `inputs` | 캐시 키에 포함할 입력 파일 | `["src/**"]` |
| `cache` | 캐시 사용 여부 | `true` / `false` |
| `persistent` | 장기 실행 프로세스 여부 | `true` (dev 서버) |
| `env` | 캐시 키에 포함할 환경 변수 | `["API_URL"]` |

### dependsOn 문법

```json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"]
      // ^build = 의존 패키지의 build를 먼저 실행
      // (topological dependency)
    },
    "test": {
      "dependsOn": ["build"]
      // build = 같은 패키지의 build를 먼저 실행
      // (same-package dependency)
    },
    "deploy": {
      "dependsOn": ["build", "test", "^build"]
      // 여러 의존성 조합 가능
    }
  }
}
```

### 환경 변수 처리

```json
{
  "globalEnv": ["CI", "NODE_ENV"],
  "globalPassThroughEnv": ["AWS_SECRET_KEY"],
  "tasks": {
    "build": {
      "env": ["API_URL", "DATABASE_URL"],
      "passThroughEnv": ["SENTRY_DSN"]
    }
  }
}
```

- `env` - 캐시 해시에 포함되는 환경 변수 (값이 바뀌면 캐시 미스)
- `passThroughEnv` - 캐시 해시에 포함하지 않지만 태스크에 전달되는 환경 변수
- `globalEnv` - 모든 태스크의 캐시 해시에 포함
- `globalPassThroughEnv` - 모든 태스크에 전달되지만 캐시에 미포함

---

## 7. 캐싱 메커니즘

### 로컬 캐싱

Turborepo는 태스크 실행 결과를 로컬 `.turbo/cache` 디렉토리에 캐싱한다.

```bash
# 첫 번째 실행 - 실제 빌드 수행
$ turbo run build
 Tasks:    3 successful, 3 total
 Cached:   0 cached, 3 total
 Time:     12.4s

# 두 번째 실행 - 캐시에서 복원
$ turbo run build
 Tasks:    3 successful, 3 total
 Cached:   3 cached, 3 total        # 전부 캐시 히트!
 Time:     0.3s >>> FULL TURBO       # FULL TURBO!
```

### 캐시 해시 구성 요소

캐시의 유효성은 다음 요소들의 해시로 결정된다:

1. **inputs에 지정된 파일들의 내용** (기본값: `git ls-files`의 모든 파일)
2. **의존 패키지의 해시**
3. **env에 지정된 환경 변수 값**
4. **turbo.json의 태스크 설정**
5. **lockfile 내용** (패키지 버전 변경 감지)

### outputs 설정

캐시에 저장/복원할 출력 파일을 지정한다.

```json
{
  "tasks": {
    "build": {
      "outputs": [
        "dist/**",           // dist 디렉토리 전체
        ".next/**",          // Next.js 빌드 출력
        "!.next/cache/**"    // Next.js 캐시는 제외 (느낌표 = 제외)
      ]
    },
    "test": {
      "outputs": ["coverage/**"]
    },
    "lint": {
      "outputs": []          // 출력 파일 없음 (로그만 캐싱)
    }
  }
}
```

### inputs 설정

캐시 키 계산에 사용할 입력 파일을 제한한다.

```json
{
  "tasks": {
    "test": {
      "inputs": [
        "src/**/*.ts",
        "src/**/*.tsx",
        "test/**/*.ts",
        "jest.config.ts"
      ]
      // README.md 등이 변경되어도 캐시 미스가 발생하지 않음
    }
  }
}
```

---

## 8. Remote Caching

### Vercel Remote Cache

팀원 간 캐시를 공유하여 CI/CD 및 로컬 개발 속도를 높인다.

```bash
# Vercel 계정으로 로그인
npx turbo login

# 프로젝트를 Vercel에 연결
npx turbo link
```

```
팀원 A: turbo run build → 빌드 실행 (2분) → Vercel Remote Cache에 저장
팀원 B: turbo run build → Remote Cache에서 복원 (3초)
CI:     turbo run build → Remote Cache에서 복원 (3초)
```

### 동작 흐름

```
1. 태스크 실행 요청
2. 입력 해시 계산
3. 로컬 캐시 확인 → 히트? → 로컬에서 복원
4. Remote 캐시 확인 → 히트? → 다운로드 후 복원
5. 캐시 미스 → 태스크 실행 → 로컬 + Remote에 저장
```

### 셀프 호스팅 Remote Cache

Vercel 외에 자체 서버에서 Remote Cache를 운영할 수도 있다.

```json
// .turbo/config.json
{
  "teamId": "team_xxxxx",
  "apiUrl": "https://my-cache-server.example.com"
}
```

---

## 9. 장점과 단점

### 장점

- ✅ **간단한 설정** - `turbo.json` 하나로 대부분의 설정이 완료
- ✅ **빠른 도입** - 기존 프로젝트에 몇 분 만에 추가 가능
- ✅ **패키지 매니저 호환** - npm, yarn, pnpm 워크스페이스 그대로 활용
- ✅ **빠른 성능** - Rust로 작성되어 태스크 스케줄링이 매우 빠름
- ✅ **강력한 캐싱** - 콘텐츠 해시 기반의 정밀한 캐시 관리
- ✅ **Vercel 통합** - Vercel에 배포하는 프로젝트에서 원격 캐싱이 자연스럽게 연동
- ✅ **turbo prune** - Docker 배포 시 경량화된 워크스페이스 추출
- ✅ **점진적 마이그레이션** - 기존 모노레포에 점진적으로 도입 가능

### 단점

- ❌ **코드 생성 없음** - NX의 Generator 같은 스캐폴딩 도구가 내장되어 있지 않음
- ❌ **Affected 명령어 없음** - `--filter=...[HEAD~1]`로 유사하게 구현 가능하지만, NX만큼 정교하지 않음
- ❌ **플러그인 생태계 부재** - 프레임워크별 플러그인이 없어 직접 설정 필요
- ❌ **모듈 경계 규칙 없음** - 프로젝트 간 의존성 규칙을 강제하는 기능이 없음
- ❌ **프로젝트 그래프 시각화 제한적** - NX의 `nx graph`만큼 풍부하지 않음

---

## 10. 실전 활용 사례

### Next.js + 공유 UI 라이브러리 모노레포

```bash
# 프로젝트 생성
npx create-turbo@latest my-project
```

#### 공유 UI 패키지

```json
// packages/ui/package.json
{
  "name": "@my-project/ui",
  "version": "0.0.0",
  "private": true,
  "exports": {
    ".": "./src/index.ts",
    "./button": "./src/button.tsx",
    "./card": "./src/card.tsx"
  },
  "devDependencies": {
    "@my-project/typescript-config": "workspace:*",
    "typescript": "^5.0.0"
  }
}
```

```tsx
// packages/ui/src/button.tsx
import { ButtonHTMLAttributes, ReactNode } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  children: ReactNode;
  variant?: 'primary' | 'secondary';
}

export function Button({ children, variant = 'primary', ...props }: ButtonProps) {
  return (
    <button className={`btn btn-${variant}`} {...props}>
      {children}
    </button>
  );
}
```

```tsx
// packages/ui/src/index.ts
export { Button } from './button';
export { Card } from './card';
```

#### 공유 TypeScript 설정

```json
// packages/typescript-config/base.json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true
  },
  "exclude": ["node_modules"]
}
```

#### Next.js 앱에서 사용

```tsx
// apps/web/src/app/page.tsx
import { Button, Card } from '@my-project/ui';

export default function Home() {
  return (
    <main>
      <Card>
        <h1>My Turborepo App</h1>
        <Button variant="primary">Get Started</Button>
      </Card>
    </main>
  );
}
```

### GitHub Actions CI 설정

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v2
        with:
          version: 8

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - run: pnpm install

      # Turborepo 캐시 활용
      - run: pnpm turbo run lint test build
        env:
          TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
          TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```

---

## 11. 핵심 요약

- Turborepo는 **경량 빌드 오케스트레이터**로, 패키지 매니저 워크스페이스 위에서 동작한다
- `turbo.json`의 **tasks** 설정으로 태스크 간 의존성과 캐시 동작을 정의한다
- **콘텐츠 해시 기반 캐싱**으로 동일한 입력에 대해 빌드를 건너뛴다 ("FULL TURBO")
- **Remote Caching**으로 팀원 간, CI 서버 간 캐시를 공유하여 빌드 시간을 절감한다
- **turbo prune**으로 Docker 배포 시 필요한 패키지만 추출할 수 있다
- 설정이 간단하고 도입이 쉬워 **기존 프로젝트에 점진적으로 도입**하기 적합하다
- 코드 생성, 플러그인 등은 제공하지 않으므로 필요 시 별도 도구를 조합해야 한다

## 참고 자료

- [Turborepo 공식 문서](https://turbo.build/repo/docs)
- [Turborepo GitHub 저장소](https://github.com/vercel/turborepo)
- [Vercel Remote Cache 문서](https://vercel.com/docs/monorepos/remote-caching)
- [create-turbo 템플릿](https://github.com/vercel/turbo/tree/main/examples)
