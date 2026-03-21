# Monorepo

## 개요

Monorepo(모노레포) 도구에 대해 학습합니다. NX와 Turborepo를 중심으로 모노레포의 개념과 실전 활용법을 정리합니다.

<br />

## 목차

- [NX - NX 모노레포 도구에 대한 정리](./nx.md)
- [Turborepo - Turborepo에 대한 정리](./turborepo.md)
- [NX vs Turborepo - 두 도구의 비교 분석](./nx-vs-turborepo.md)

<br />

---

## Monorepo란?

### 정의

Monorepo(모노레포)는 **여러 프로젝트의 코드를 하나의 저장소(Repository)에서 관리하는 소프트웨어 개발 전략**이다. Google, Meta, Microsoft 등 대규모 기업에서 채택하고 있으며, JavaScript/TypeScript 생태계에서도 널리 사용되고 있다.

```
# 모노레포 구조 예시
my-monorepo/
├── apps/
│   ├── web/          # React 프론트엔드
│   ├── mobile/       # React Native 앱
│   └── api/          # NestJS 백엔드
├── packages/
│   ├── ui/           # 공유 UI 컴포넌트
│   ├── utils/        # 공유 유틸리티
│   └── config/       # 공유 설정(ESLint, TSConfig 등)
├── package.json
└── turbo.json (또는 nx.json)
```

### 모노레포를 사용하는 이유

- **코드 공유 용이** - 여러 프로젝트에서 공통 라이브러리를 쉽게 공유
- **의존성 관리 통합** - 하나의 `node_modules`로 의존성 버전 통일
- **일관된 도구 및 설정** - ESLint, Prettier, TSConfig 등을 한 곳에서 관리
- **원자적 변경(Atomic Changes)** - 여러 프로젝트에 걸친 변경을 하나의 커밋으로 처리
- **통합 CI/CD** - 전체 프로젝트의 빌드, 테스트, 배포를 한 파이프라인에서 관리

### 모노레포 vs 멀티레포 vs 모놀리식

| 구분 | 모노레포 (Monorepo) | 멀티레포 (Polyrepo) | 모놀리식 (Monolithic) |
|------|---------------------|---------------------|----------------------|
| 저장소 수 | 1개 | 프로젝트별 1개 | 1개 |
| 코드 구조 | 여러 프로젝트, 분리된 패키지 | 독립적 저장소 | 단일 코드베이스 |
| 코드 공유 | 쉬움 | 패키지 배포 필요 | 자연스럽지만 경계 모호 |
| 의존성 관리 | 통합 관리 | 각각 독립 관리 | 단일 관리 |
| CI/CD | 통합 (영향 받은 것만 빌드) | 각각 독립 파이프라인 | 전체 빌드 |
| 확장성 | 도구 지원 필요 | 좋음 | 제한적 |

### 모노레포 도구 종류

| 도구 | 개발사 | 특징 |
|------|--------|------|
| **NX** | Nrwl | 통합 개발 플랫폼, 코드 생성, 플러그인 생태계 |
| **Turborepo** | Vercel | 경량 빌드 시스템, 제로 설정, 빠른 도입 |
| **Lerna** | Nrwl (인수) | 패키지 관리 중심, NX와 통합 가능 |
| **Rush** | Microsoft | 대규모 프로젝트, 엄격한 정책 관리 |
| **pnpm Workspaces** | pnpm | 패키지 매니저 레벨의 워크스페이스 지원 |

> 이 학습 자료에서는 가장 널리 사용되는 **NX**와 **Turborepo**에 집중하여 다룹니다.
