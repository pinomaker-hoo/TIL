# NX 모노레포 도구

> NX는 모노레포 관리를 위한 강력한 빌드 시스템이자 개발 도구로, 스마트 빌드 캐싱, 코드 생성, 의존성 그래프 시각화 등 다양한 기능을 제공한다.

## 목차

1. [NX란 무엇인가?](#1-nx란-무엇인가)
2. [핵심 개념과 아키텍처](#2-핵심-개념과-아키텍처)
3. [설치 및 초기 설정](#3-설치-및-초기-설정)
4. [프로젝트 구조](#4-프로젝트-구조)
5. [주요 CLI 명령어](#5-주요-cli-명령어)
6. [Task Pipeline과 의존성 설정](#6-task-pipeline과-의존성-설정)
7. [캐싱 메커니즘](#7-캐싱-메커니즘)
8. [코드 생성 (Generators)](#8-코드-생성-generators)
9. [NX Cloud](#9-nx-cloud)
10. [장점과 단점](#10-장점과-단점)
11. [실전 활용 사례](#11-실전-활용-사례)
12. [핵심 요약](#12-핵심-요약)

---

## 1. NX란 무엇인가?

NX는 **Nrwl** 사에서 개발한 오픈 소스 빌드 시스템이자 모노레포 관리 도구이다. "Smart, Fast, Extensible Build System"이라는 슬로건 아래, 대규모 코드베이스에서도 빠르고 효율적인 개발 경험을 제공하는 것을 목표로 한다.

NX는 단순한 빌드 도구를 넘어서 **통합 개발 플랫폼**의 역할을 한다:

- 빌드, 테스트, 린트 등 태스크 실행 및 오케스트레이션
- 프로젝트 간 의존성 분석 및 시각화
- 코드 생성(Scaffolding) 및 마이그레이션 자동화
- 로컬/원격 캐싱을 통한 빌드 속도 최적화

---

## 2. 핵심 개념과 아키텍처

### Project Graph (프로젝트 그래프)

NX의 핵심은 **프로젝트 그래프**이다. 워크스페이스 내 모든 프로젝트와 그들 사이의 의존성을 자동으로 분석하여 방향 비순환 그래프(DAG)를 생성한다.

```
┌─────────┐     ┌─────────┐
│  web-app │────▶│ shared- │
│ (React)  │     │   ui    │
└─────────┘     └────┬────┘
                     │
┌─────────┐     ┌────▼────┐
│   api    │────▶│  utils  │
│(NestJS)  │     │         │
└─────────┘     └─────────┘
```

프로젝트 그래프를 통해 NX는 어떤 프로젝트가 변경되었을 때, 영향 받는 프로젝트를 정확히 파악할 수 있다.

### Task Graph (태스크 그래프)

프로젝트 그래프를 기반으로 **태스크 그래프**를 생성한다. 태스크 간의 실행 순서와 병렬 실행 가능 여부를 결정한다.

```
build:web-app ──▶ build:shared-ui ──▶ build:utils
                                         ▲
build:api ───────────────────────────────┘
```

### Affected (영향 분석)

코드 변경 시, 프로젝트 그래프를 활용하여 **실제로 영향 받는 프로젝트만** 빌드/테스트한다. 전체 워크스페이스를 다시 빌드하지 않으므로 CI 시간이 대폭 단축된다.

### Plugins (플러그인)

NX는 플러그인 아키텍처를 채택하고 있다. 주요 플러그인:

| 플러그인 | 설명 |
|----------|------|
| `@nx/react` | React 앱 및 라이브러리 |
| `@nx/next` | Next.js 앱 |
| `@nx/nest` | NestJS 백엔드 |
| `@nx/node` | Node.js 앱 |
| `@nx/angular` | Angular 앱 및 라이브러리 |
| `@nx/vite` | Vite 기반 빌드 |
| `@nx/jest` | Jest 테스트 |
| `@nx/eslint` | ESLint 린트 |
| `@nx/storybook` | Storybook 통합 |

### Executors (실행기)

Executor는 특정 태스크를 실행하는 함수이다. 예를 들어 `@nx/webpack:webpack`은 Webpack을 사용하여 빌드를 수행하는 Executor이다.

### Generators (생성기)

Generator는 코드를 자동으로 생성하거나 수정하는 도구이다. 새로운 앱, 라이브러리, 컴포넌트 등을 일관된 구조로 생성한다.

---

## 3. 설치 및 초기 설정

### 새 워크스페이스 생성

```bash
# 새 NX 워크스페이스 생성
npx create-nx-workspace@latest my-org

# 옵션 선택
# ? What to create in the new workspace
#   > integrated (monorepo)   # NX가 모든 프로젝트를 관리
#   > package-based            # 기존 패키지 매니저 워크스페이스 활용
#   > standalone               # 단일 프로젝트
```

### 기존 프로젝트에 NX 추가

```bash
# 기존 프로젝트에 NX 추가
npx nx@latest init
```

### nx.json 설정

워크스페이스 루트에 위치하는 핵심 설정 파일이다.

```json
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/*.spec.ts",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/.eslintrc.json"
    ],
    "sharedGlobals": []
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"],
      "cache": true
    },
    "test": {
      "inputs": ["default", "^production"],
      "cache": true
    },
    "lint": {
      "inputs": ["default", "{workspaceRoot}/.eslintrc.json"],
      "cache": true
    }
  }
}
```

### project.json 설정

각 프로젝트의 설정 파일이다.

```json
{
  "name": "my-app",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "apps/my-app/src",
  "projectType": "application",
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/my-app",
        "main": "apps/my-app/src/main.ts"
      }
    },
    "serve": {
      "executor": "@nx/webpack:dev-server",
      "options": {
        "buildTarget": "my-app:build"
      }
    },
    "test": {
      "executor": "@nx/jest:jest",
      "options": {
        "jestConfig": "apps/my-app/jest.config.ts"
      }
    }
  }
}
```

---

## 4. 프로젝트 구조

### Integrated Monorepo 구조

```
my-org/
├── apps/
│   ├── web/                    # React 프론트엔드 앱
│   │   ├── src/
│   │   │   ├── app/
│   │   │   └── main.tsx
│   │   ├── project.json        # 프로젝트 설정
│   │   ├── tsconfig.json
│   │   └── tsconfig.app.json
│   └── api/                    # NestJS 백엔드 앱
│       ├── src/
│       │   └── main.ts
│       └── project.json
├── libs/
│   ├── shared/
│   │   ├── ui/                 # 공유 UI 컴포넌트 라이브러리
│   │   │   ├── src/
│   │   │   │   ├── lib/
│   │   │   │   └── index.ts
│   │   │   └── project.json
│   │   └── utils/              # 공유 유틸리티 라이브러리
│   │       ├── src/
│   │       │   └── index.ts
│   │       └── project.json
│   └── types/                  # 공유 타입 정의
│       ├── src/
│       └── project.json
├── tools/                      # 커스텀 스크립트, 제너레이터
├── nx.json                     # NX 워크스페이스 설정
├── tsconfig.base.json          # 공통 TypeScript 설정
└── package.json
```

### apps vs libs 패턴

- **apps/** - 배포 가능한 애플리케이션. 가능한 한 가볍게 유지하며, 비즈니스 로직은 libs에 위치
- **libs/** - 재사용 가능한 라이브러리. 앱 간 공유되는 코드, UI 컴포넌트, 유틸리티 등을 포함

```typescript
// apps/web/src/app/app.tsx
// libs에서 공유 컴포넌트를 import
import { Button, Card } from '@my-org/shared/ui';
import { formatDate } from '@my-org/shared/utils';

export function App() {
  return (
    <Card>
      <h1>Welcome</h1>
      <p>{formatDate(new Date())}</p>
      <Button>Click me</Button>
    </Card>
  );
}
```

```json
// tsconfig.base.json - 경로 별칭 설정
{
  "compilerOptions": {
    "paths": {
      "@my-org/shared/ui": ["libs/shared/ui/src/index.ts"],
      "@my-org/shared/utils": ["libs/shared/utils/src/index.ts"],
      "@my-org/types": ["libs/types/src/index.ts"]
    }
  }
}
```

---

## 5. 주요 CLI 명령어

### 기본 명령어

```bash
# 앱 개발 서버 실행
nx serve web

# 프로젝트 빌드
nx build web

# 테스트 실행
nx test shared-ui

# 린트 실행
nx lint api
```

### 다중 프로젝트 실행

```bash
# 모든 프로젝트 빌드
nx run-many --target=build

# 특정 프로젝트들만 빌드
nx run-many --target=build --projects=web,api

# 병렬 실행 수 지정
nx run-many --target=test --parallel=5
```

### Affected 명령어

```bash
# 변경에 영향 받는 프로젝트만 빌드
nx affected --target=build

# 변경에 영향 받는 프로젝트만 테스트
nx affected --target=test

# 기준 브랜치 지정
nx affected --target=build --base=main --head=HEAD
```

### 프로젝트 그래프 시각화

```bash
# 브라우저에서 프로젝트 그래프 확인
nx graph

# 영향 받는 프로젝트 그래프 확인
nx affected:graph
```

### 마이그레이션

```bash
# NX 버전 업데이트 및 자동 마이그레이션
nx migrate latest

# 마이그레이션 실행
nx migrate --run-migrations
```

---

## 6. Task Pipeline과 의존성 설정

### dependsOn 설정

`dependsOn`은 태스크 간의 실행 순서를 정의한다.

```json
// nx.json
{
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "deploy": {
      "dependsOn": ["build", "test"]
    }
  }
}
```

- `"^build"` - 의존하는 프로젝트의 `build`를 먼저 실행 (상위 의존성)
- `"build"` - 같은 프로젝트의 `build`를 먼저 실행 (같은 프로젝트 내 의존성)

### 실행 흐름 예시

```
# nx build web 실행 시
# web이 shared-ui에 의존하고, shared-ui가 utils에 의존하는 경우

1. build:utils      (의존성 없음, 먼저 실행)
2. build:shared-ui  (utils 빌드 완료 후 실행)
3. build:web        (shared-ui 빌드 완료 후 실행)
```

### inputs와 outputs 설정

캐시 유효성을 결정하는 입력과, 캐시에 저장할 출력을 정의한다.

```json
{
  "targetDefaults": {
    "build": {
      "inputs": ["production", "^production"],
      "outputs": ["{projectRoot}/dist"]
    },
    "test": {
      "inputs": ["default", "^production"],
      "outputs": ["{projectRoot}/coverage"]
    }
  }
}
```

---

## 7. 캐싱 메커니즘

### 로컬 캐싱

NX는 태스크 실행 결과를 로컬에 캐싱한다. 동일한 입력으로 태스크를 다시 실행하면, 실제 실행 없이 캐시에서 결과를 가져온다.

```bash
# 첫 번째 실행 - 실제 빌드 수행
$ nx build shared-ui
> nx run shared-ui:build
✔ Build completed in 3.2s

# 두 번째 실행 - 캐시에서 가져옴 (코드 변경 없을 시)
$ nx build shared-ui
> nx run shared-ui:build  [local cache]
✔ Build completed in 0.1s   # 캐시 히트!
```

### 캐시 동작 원리

NX는 다음 요소들의 해시를 계산하여 캐시 키를 생성한다:

1. **소스 파일** - 프로젝트의 입력 파일들
2. **의존 프로젝트의 출력** - 의존하는 라이브러리의 빌드 결과
3. **런타임 값** - Node 버전, 환경 변수 등
4. **CLI 플래그** - 명령어에 전달된 옵션

```
해시 = hash(소스파일 + 의존성 출력 + 런타임 + CLI 플래그)

캐시 히트: 해시가 기존 캐시와 일치 → 저장된 결과 반환
캐시 미스: 해시가 일치하지 않음 → 태스크 실제 실행 후 결과 캐싱
```

### 캐시 설정

```json
// nx.json
{
  "targetDefaults": {
    "build": {
      "cache": true,
      "inputs": ["production", "^production"],
      "outputs": ["{projectRoot}/dist"]
    },
    "dev": {
      "cache": false   // 개발 서버는 캐시하지 않음
    }
  }
}
```

### 캐시 관리 명령어

```bash
# 로컬 캐시 초기화
nx reset
```

---

## 8. 코드 생성 (Generators)

NX의 가장 강력한 기능 중 하나는 **코드 생성기(Generator)**이다. 프로젝트, 라이브러리, 컴포넌트 등을 일관된 구조로 자동 생성한다.

### 내장 Generator 사용

```bash
# React 앱 생성
nx generate @nx/react:app my-new-app

# React 라이브러리 생성
nx generate @nx/react:lib shared-ui

# NestJS 앱 생성
nx generate @nx/nest:app api

# React 컴포넌트 생성
nx generate @nx/react:component Button --project=shared-ui

# NestJS 모듈 생성
nx generate @nx/nest:module users --project=api
```

### Generator 실행 예시

```bash
$ nx generate @nx/react:lib shared-ui

CREATE libs/shared/ui/project.json
CREATE libs/shared/ui/src/index.ts
CREATE libs/shared/ui/src/lib/shared-ui.tsx
CREATE libs/shared/ui/src/lib/shared-ui.spec.tsx
CREATE libs/shared/ui/src/lib/shared-ui.module.css
CREATE libs/shared/ui/tsconfig.json
CREATE libs/shared/ui/tsconfig.lib.json
CREATE libs/shared/ui/tsconfig.spec.json
CREATE libs/shared/ui/.eslintrc.json
UPDATE tsconfig.base.json
```

### 커스텀 Generator 생성

프로젝트에 맞는 커스텀 Generator를 만들 수 있다.

```bash
# Generator 프로젝트 생성
nx generate @nx/plugin:generator my-generator --project=tools
```

```typescript
// tools/src/generators/my-generator/generator.ts
import { Tree, formatFiles, generateFiles, joinPathFragments } from '@nx/devkit';

interface MyGeneratorSchema {
  name: string;
  directory?: string;
}

export default async function myGenerator(tree: Tree, options: MyGeneratorSchema) {
  const projectRoot = `libs/${options.directory ?? options.name}`;

  // 템플릿 파일 생성
  generateFiles(tree, joinPathFragments(__dirname, 'files'), projectRoot, {
    ...options,
    tmpl: '',
  });

  await formatFiles(tree);
}
```

```bash
# 커스텀 Generator 실행
nx generate @my-org/tools:my-generator --name=feature-lib
```

---

## 9. NX Cloud

NX Cloud는 **원격 캐싱**과 **분산 태스크 실행**을 제공하는 서비스이다.

### 원격 캐싱 (Remote Caching)

팀원 간 빌드 캐시를 공유하여 CI/CD 시간을 대폭 단축한다.

```bash
# NX Cloud 연결
npx nx connect-to-nx-cloud

# 또는 직접 설치
npm install @nx/cloud
```

```json
// nx.json
{
  "nxCloudAccessToken": "your-access-token"
}
```

```
팀원 A: nx build web → 빌드 실행 (3분) → 결과를 NX Cloud에 캐싱
팀원 B: nx build web → NX Cloud에서 캐시 가져옴 (5초)
CI 서버: nx build web → NX Cloud에서 캐시 가져옴 (5초)
```

### 분산 태스크 실행 (DTE)

CI에서 태스크를 여러 머신에 자동 분산하여 실행한다.

```yaml
# .github/workflows/ci.yml
name: CI
on: push

jobs:
  main:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - run: npm ci
      - uses: nrwl/nx-set-shas@v4

      # 영향 받는 프로젝트만 빌드/테스트
      - run: npx nx affected -t lint test build
```

---

## 10. 장점과 단점

### 장점

- ✅ **풍부한 플러그인 생태계** - React, Angular, NestJS, Next.js 등 주요 프레임워크 공식 지원
- ✅ **강력한 코드 생성** - Generator를 통한 일관된 코드 스캐폴딩
- ✅ **프로젝트 그래프 시각화** - `nx graph`로 의존성을 시각적으로 확인
- ✅ **Affected 명령어** - 변경에 영향 받는 프로젝트만 빌드/테스트하여 CI 시간 절약
- ✅ **강력한 캐싱** - 로컬 + 원격(NX Cloud) 캐싱으로 빌드 속도 극대화
- ✅ **모듈 경계 규칙** - `@nx/enforce-module-boundaries`로 의존성 규칙 강제
- ✅ **자동 마이그레이션** - `nx migrate`로 버전 업데이트 자동화

### 단점

- ❌ **높은 학습 곡선** - 개념(Executor, Generator, Plugin)이 많아 초기 학습 비용이 높음
- ❌ **설정 복잡성** - project.json, nx.json 등 설정 파일이 많음
- ❌ **lock-in 우려** - NX 생태계에 깊이 의존하게 될 수 있음
- ❌ **오버헤드** - 작은 프로젝트에서는 도구의 복잡성이 오히려 부담
- ❌ **NX Cloud 의존** - 원격 캐싱/DTE 등 고급 기능은 유료 서비스에 의존

---

## 11. 실전 활용 사례

### 풀스택 모노레포 예시

React 프론트엔드 + NestJS 백엔드 + 공유 라이브러리 구성:

```bash
# 워크스페이스 생성
npx create-nx-workspace@latest my-fullstack --preset=ts

# React 앱 추가
nx generate @nx/react:app web

# NestJS 백엔드 추가
nx generate @nx/nest:app api

# 공유 타입 라이브러리 추가
nx generate @nx/js:lib shared-types

# 공유 유틸리티 추가
nx generate @nx/js:lib shared-utils
```

```typescript
// libs/shared-types/src/lib/user.ts
// 프론트엔드와 백엔드에서 공유하는 타입 정의
export interface User {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
}

export interface CreateUserDto {
  email: string;
  name: string;
  password: string;
}
```

```typescript
// apps/api/src/users/users.controller.ts
import { User, CreateUserDto } from '@my-fullstack/shared-types';

@Controller('users')
export class UsersController {
  @Post()
  create(@Body() dto: CreateUserDto): Promise<User> {
    return this.usersService.create(dto);
  }
}
```

```typescript
// apps/web/src/app/hooks/useUsers.ts
import { User } from '@my-fullstack/shared-types';

export function useUsers() {
  const [users, setUsers] = useState<User[]>([]);
  // ...
}
```

> 프론트엔드와 백엔드가 동일한 타입 정의를 공유하므로, API 스펙 변경 시 양쪽에서 즉시 타입 에러가 발생하여 안전하게 변경할 수 있다.

---

## 12. 핵심 요약

- NX는 **통합 개발 플랫폼**으로, 빌드 시스템 + 코드 생성 + 의존성 분석을 모두 제공한다
- **Project Graph**를 통해 프로젝트 간 의존성을 자동 분석하고, **Affected** 명령어로 필요한 것만 빌드한다
- **캐싱**(로컬 + NX Cloud 원격)으로 빌드 시간을 극적으로 줄인다
- **Generator**를 통해 일관된 코드 구조를 자동 생성한다
- **플러그인 생태계**가 풍부하여 React, Angular, NestJS 등 다양한 프레임워크를 공식 지원한다
- 학습 곡선이 높지만, 대규모 프로젝트에서 그만큼 강력한 효과를 발휘한다

## 참고 자료

- [NX 공식 문서](https://nx.dev/getting-started/intro)
- [NX GitHub 저장소](https://github.com/nrwl/nx)
- [NX Cloud](https://nx.app/)
- [NX 플러그인 레지스트리](https://nx.dev/plugin-registry)
