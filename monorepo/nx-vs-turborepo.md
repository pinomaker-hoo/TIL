# NX vs Turborepo 비교

> NX와 Turborepo는 모두 JavaScript/TypeScript 모노레포를 위한 빌드 시스템이지만, 접근 방식과 기능 범위에서 뚜렷한 차이가 있다. 두 도구를 심층 비교한다.

## 목차

1. [개요 비교](#1-개요-비교)
2. [설계 철학 비교](#2-설계-철학-비교)
3. [기능 비교표](#3-기능-비교표)
4. [설정 및 구성 비교](#4-설정-및-구성-비교)
5. [캐싱 비교](#5-캐싱-비교)
6. [Task Pipeline 비교](#6-task-pipeline-비교)
7. [코드 생성 비교](#7-코드-생성-비교)
8. [CI/CD 통합 비교](#8-cicd-통합-비교)
9. [마이그레이션 난이도](#9-마이그레이션-난이도)
10. [어떤 도구를 선택할까?](#10-어떤-도구를-선택할까)
11. [핵심 요약](#11-핵심-요약)

---

## 1. 개요 비교

| 항목 | NX | Turborepo |
|------|-----|-----------|
| **개발사** | Nrwl | Vercel |
| **첫 출시** | 2018 | 2021 |
| **작성 언어** | TypeScript | Rust + Go |
| **라이선스** | MIT | MPL-2.0 |
| **포지셔닝** | 통합 개발 플랫폼 | 경량 빌드 시스템 |
| **워크스페이스 관리** | 자체 (Integrated) 또는 패키지 매니저 | 패키지 매니저에 위임 |
| **원격 캐싱** | NX Cloud | Vercel Remote Cache |
| **GitHub Stars** | ~23k+ | ~26k+ |

---

## 2. 설계 철학 비교

### NX: 통합 개발 플랫폼

NX는 모노레포 관리에 필요한 **모든 것을 내장**하는 "batteries-included" 접근 방식을 취한다.

```
NX = 빌드 시스템 + 코드 생성 + 의존성 분석 + 플러그인 + IDE 지원
```

- 프로젝트 생성부터 빌드, 테스트, 배포까지 전체 워크플로우를 관리
- 프레임워크별 플러그인으로 최적화된 개발 경험 제공
- 엄격한 모듈 경계 규칙 강제 가능
- 학습 곡선이 높지만 제공하는 기능이 풍부

### Turborepo: 경량 빌드 오케스트레이터

Turborepo는 **한 가지를 잘 하자**는 Unix 철학을 따른다.

```
Turborepo = 빌드 오케스트레이션 + 캐싱
(나머지는 기존 도구에 위임)
```

- 패키지 매니저의 워크스페이스 위에서 동작 (자체 워크스페이스 관리 없음)
- 빌드 순서 결정, 병렬화, 캐싱에만 집중
- 코드 생성, 플러그인 등은 다른 도구에 위임
- 설정이 간단하고 도입이 빠름

---

## 3. 기능 비교표

| 기능 | NX | Turborepo |
|------|:---:|:---------:|
| **태스크 오케스트레이션** | ✅ | ✅ |
| **로컬 캐싱** | ✅ | ✅ |
| **원격 캐싱** | ✅ (NX Cloud) | ✅ (Vercel) |
| **분산 태스크 실행 (DTE)** | ✅ (NX Cloud) | ❌ |
| **프로젝트 그래프 시각화** | ✅ (풍부) | ✅ (기본) |
| **Affected 명령어** | ✅ (내장) | ⚠️ (--filter로 유사 구현) |
| **코드 생성 (Generator)** | ✅ (강력) | ❌ |
| **플러그인 생태계** | ✅ (React, Angular, NestJS 등) | ❌ |
| **모듈 경계 규칙** | ✅ (enforce-module-boundaries) | ❌ |
| **자동 마이그레이션** | ✅ (nx migrate) | ❌ |
| **IDE 통합** | ✅ (NX Console - VSCode/IntelliJ) | ❌ |
| **Docker 지원 (prune)** | ⚠️ (제한적) | ✅ (turbo prune) |
| **패키지 매니저 호환** | npm, yarn, pnpm | npm, yarn, pnpm |
| **설정 파일** | nx.json + project.json | turbo.json |

---

## 4. 설정 및 구성 비교

### 워크스페이스 설정

**NX (Integrated 방식)**

```json
// nx.json
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "namedInputs": {
    "default": ["{projectRoot}/**/*"],
    "production": ["default", "!{projectRoot}/**/*.spec.ts"]
  },
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["production", "^production"],
      "cache": true
    }
  }
}
```

```json
// apps/web/project.json (프로젝트별 설정)
{
  "name": "web",
  "targets": {
    "build": {
      "executor": "@nx/webpack:webpack",
      "outputs": ["{options.outputPath}"],
      "options": {
        "outputPath": "dist/apps/web"
      }
    }
  }
}
```

**Turborepo**

```json
// turbo.json (이것 하나로 충분)
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"]
    }
  }
}
```

```json
// apps/web/package.json (기존 scripts 그대로 사용)
{
  "name": "web",
  "scripts": {
    "build": "next build",
    "dev": "next dev",
    "lint": "eslint ."
  }
}
```

### 핵심 차이점

| 항목 | NX | Turborepo |
|------|-----|-----------|
| 빌드 방법 정의 | `project.json`의 executor | `package.json`의 scripts |
| 설정 파일 수 | nx.json + 프로젝트별 project.json | turbo.json 하나 |
| 태스크 실행 방식 | NX Executor (추상화된 빌드 도구) | 각 패키지의 npm scripts 직접 실행 |
| 의존성 관리 | NX 자체 또는 패키지 매니저 | 패키지 매니저에 완전 위임 |

---

## 5. 캐싱 비교

### 로컬 캐싱

두 도구 모두 콘텐츠 해시 기반의 로컬 캐싱을 제공한다.

| 항목 | NX | Turborepo |
|------|-----|-----------|
| 캐시 위치 | `node_modules/.cache/nx` | `.turbo/cache` |
| 해시 기반 | 파일 내용 + 설정 + 런타임 | 파일 내용 + 설정 + 환경변수 |
| 입력 설정 | `namedInputs` + `inputs` | `inputs` (글로브 패턴) |
| 출력 설정 | `outputs` | `outputs` |
| 캐시 초기화 | `nx reset` | `turbo daemon clean` |

### 원격 캐싱

| 항목 | NX Cloud | Vercel Remote Cache |
|------|----------|---------------------|
| 제공사 | Nrwl (NX 팀) | Vercel |
| 무료 플랜 | 제한적 | Vercel 프로 이상 |
| 셀프 호스팅 | 제한적 | API 구현으로 가능 |
| 분산 실행 (DTE) | ✅ | ❌ |
| 설정 방법 | `nxCloudAccessToken` | `turbo login` + `turbo link` |

---

## 6. Task Pipeline 비교

### 의존성 문법 비교

두 도구 모두 `^` 접두사를 사용하여 topological dependency를 표현한다.

**NX**

```json
// nx.json
{
  "targetDefaults": {
    "build": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"]
    }
  }
}
```

**Turborepo**

```json
// turbo.json
{
  "tasks": {
    "build": {
      "dependsOn": ["^build"]
    },
    "test": {
      "dependsOn": ["build"]
    }
  }
}
```

### 환경 변수 처리

**NX** - 기본적으로 환경 변수를 캐시 키에 포함하지 않으며, `inputs`에서 런타임 값으로 지정 가능

```json
{
  "targetDefaults": {
    "build": {
      "inputs": [
        "production",
        { "env": "API_URL" }
      ]
    }
  }
}
```

**Turborepo** - `env`, `globalEnv`를 명시적으로 지정

```json
{
  "globalEnv": ["CI"],
  "tasks": {
    "build": {
      "env": ["API_URL", "DATABASE_URL"]
    }
  }
}
```

---

## 7. 코드 생성 비교

이 영역이 **두 도구의 가장 큰 차이점**이다.

### NX: 강력한 내장 Generator

```bash
# 프레임워크별 코드 자동 생성
nx generate @nx/react:app my-app
nx generate @nx/nest:app api
nx generate @nx/react:component Button --project=shared-ui
nx generate @nx/react:lib my-lib

# 커스텀 Generator 지원
nx generate @my-org/tools:my-generator --name=feature
```

NX의 Generator는:
- 프레임워크 베스트 프랙티스에 맞는 코드 구조 생성
- 설정 파일(tsconfig, jest.config 등) 자동 생성 및 업데이트
- 워크스페이스 전체에 걸친 변경 자동화 (마이그레이션)

### Turborepo: 코드 생성 없음

Turborepo는 코드 생성 기능이 내장되어 있지 않다. 대안:

```bash
# 1. 템플릿 복사 방식
cp -r packages/template packages/new-package

# 2. 외부 도구 활용
npx create-next-app apps/new-app
npx @nestjs/cli new apps/api

# 3. plop.js 등의 코드 생성 도구와 조합
npx plop component
```

---

## 8. CI/CD 통합 비교

### NX: GitHub Actions

```yaml
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
      - run: npm ci
      - uses: nrwl/nx-set-shas@v4

      # affected로 변경된 프로젝트만 빌드/테스트
      - run: npx nx affected -t lint test build
```

NX Cloud를 사용하면 **분산 태스크 실행(DTE)**으로 여러 CI 러너에 태스크를 자동 분배할 수 있다.

### Turborepo: GitHub Actions

```yaml
name: CI
on: push

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          cache: 'pnpm'
      - run: pnpm install

      # Remote Cache 활용
      - run: pnpm turbo run lint test build
        env:
          TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
          TURBO_TEAM: ${{ vars.TURBO_TEAM }}
```

### CI 비교 요약

| 항목 | NX | Turborepo |
|------|-----|-----------|
| Affected 빌드 | `nx affected -t build` | `turbo run build --filter=...[HEAD~1]` |
| 원격 캐시 | NX Cloud | Vercel Remote Cache |
| 분산 실행 | ✅ DTE | ❌ |
| 설정 복잡도 | 보통 | 간단 |

---

## 9. 마이그레이션 난이도

### 기존 프로젝트에 도입하기

**NX**

```bash
# 기존 프로젝트에 NX 추가
npx nx@latest init
```

- 학습해야 할 개념이 많음 (Executor, Generator, Plugin, Project Graph 등)
- Integrated 방식은 기존 프로젝트 구조 변경이 필요할 수 있음
- Package-based 방식은 비교적 도입이 쉬움
- 도입 난이도: **중~상**

**Turborepo**

```bash
# 기존 프로젝트에 Turborepo 추가
npm install turbo --save-dev
# turbo.json 생성하면 바로 사용 가능
```

- 기존 package.json scripts를 그대로 사용
- 워크스페이스 구조 변경 불필요
- turbo.json 설정 하나만 추가하면 됨
- 도입 난이도: **하**

### 학습 곡선

```
NX 학습 곡선:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
초급         중급              고급
워크스페이스   Executor/Generator  커스텀 플러그인
nx.json       플러그인 설정       DTE 설정
기본 CLI      affected           nx migrate

Turborepo 학습 곡선:
━━━━━━━━━━━━━━━━━━━━━━━━━
초급         중급
turbo.json   Remote Cache
기본 CLI     filter/prune
tasks 설정   환경변수 관리
```

---

## 10. 어떤 도구를 선택할까?

### NX를 선택해야 하는 경우

- ✅ **대규모 엔터프라이즈 프로젝트** - 10개 이상의 앱과 수십 개의 라이브러리
- ✅ **Angular 프로젝트** - NX는 Angular 팀 출신이 만들었고, Angular 지원이 가장 강력
- ✅ **코드 생성이 중요한 경우** - 일관된 구조의 코드를 자동 생성해야 할 때
- ✅ **엄격한 모듈 경계가 필요한 경우** - 팀 간 의존성 규칙을 강제해야 할 때
- ✅ **분산 CI가 필요한 경우** - NX Cloud의 DTE로 CI 시간을 극적으로 줄여야 할 때

### Turborepo를 선택해야 하는 경우

- ✅ **작은~중간 규모 프로젝트** - 2~5개의 앱과 몇 개의 공유 패키지
- ✅ **빠른 도입이 필요한 경우** - 기존 프로젝트에 최소한의 변경으로 모노레포 도구를 추가
- ✅ **Next.js/Vercel 생태계** - Vercel 배포를 사용하는 프로젝트에서 자연스러운 통합
- ✅ **간단한 설정을 선호하는 경우** - 복잡한 설정 없이 캐싱과 빌드 최적화만 원할 때
- ✅ **Docker 배포 최적화** - `turbo prune`으로 경량 이미지 빌드

### 선택 가이드 요약

| 상황 | 추천 도구 |
|------|-----------|
| 새 대규모 프로젝트 시작 | **NX** |
| 기존 프로젝트에 모노레포 도입 | **Turborepo** |
| Angular 기반 프로젝트 | **NX** |
| Next.js + Vercel 배포 | **Turborepo** |
| 코드 생성 / 스캐폴딩 필요 | **NX** |
| 최소한의 학습 곡선 | **Turborepo** |
| 팀 규모 10명 이상 | **NX** |
| 팀 규모 2~5명 | **Turborepo** |
| 분산 CI 필요 | **NX** (NX Cloud) |
| Docker 최적화 필요 | **Turborepo** (turbo prune) |

> **참고**: 두 도구 모두 훌륭하며, "정답"은 없다. 프로젝트의 규모, 팀의 요구사항, 선호하는 프레임워크를 종합적으로 고려하여 선택하면 된다. 또한 Turborepo로 시작하여 프로젝트가 커지면 NX로 마이그레이션하는 것도 가능하다.

---

## 11. 핵심 요약

- **NX**는 통합 개발 플랫폼으로, 코드 생성, 플러그인, 모듈 경계 규칙 등 **풍부한 기능**을 제공한다
- **Turborepo**는 경량 빌드 시스템으로, **간단한 설정과 빠른 도입**이 강점이다
- 두 도구 모두 **로컬/원격 캐싱**, **태스크 병렬 실행**, **의존성 기반 빌드 순서**를 지원한다
- 가장 큰 차이점은 **코드 생성(NX ✅ / Turborepo ❌)**과 **플러그인 생태계(NX ✅ / Turborepo ❌)**
- **대규모 엔터프라이즈**에는 NX, **소~중규모 프로젝트**에는 Turborepo가 적합한 경향이 있다
- 두 도구 모두 활발하게 개발되고 있으므로, 기능 격차는 시간이 지남에 따라 변할 수 있다

## 참고 자료

- [NX 공식 문서](https://nx.dev)
- [Turborepo 공식 문서](https://turbo.build/repo)
- [NX and Turborepo - NX 공식 비교](https://nx.dev/concepts/turbo-and-nx)
- [Monorepo.tools - 모노레포 도구 비교](https://monorepo.tools)
