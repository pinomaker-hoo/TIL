# 블록체인 기초 (Blockchain Fundamentals)

## 1. 블록체인이란?

블록체인은 **분산 원장 기술(DLT: Distributed Ledger Technology)**의 한 형태로, 데이터를 블록 단위로 저장하고 이를 체인처럼 연결한 구조입니다.

### 핵심 특징

- **탈중앙화 (Decentralization)**: 중앙 서버 없이 네트워크 참여자들이 데이터를 공유
- **불변성 (Immutability)**: 한 번 기록된 데이터는 변경이 거의 불가능
- **투명성 (Transparency)**: 모든 거래 기록이 네트워크 참여자에게 공개
- **보안성 (Security)**: 암호화 기술로 데이터 무결성 보장

## 2. 블록 구조

```
┌─────────────────────────────────────┐
│             Block Header            │
├─────────────────────────────────────┤
│  - Previous Block Hash              │
│  - Timestamp                        │
│  - Nonce                            │
│  - Merkle Root                      │
├─────────────────────────────────────┤
│             Block Body              │
├─────────────────────────────────────┤
│  - Transaction 1                    │
│  - Transaction 2                    │
│  - Transaction 3                    │
│  - ...                              │
└─────────────────────────────────────┘
```

### 블록 헤더 구성 요소

| 요소 | 설명 |
|------|------|
| Previous Hash | 이전 블록의 해시값 (체인 연결) |
| Timestamp | 블록 생성 시간 |
| Nonce | 작업 증명에 사용되는 임의의 숫자 |
| Merkle Root | 트랜잭션들의 해시 트리 루트 |

## 3. 합의 알고리즘 (Consensus Algorithm)

블록체인 네트워크에서 모든 노드가 동일한 상태를 유지하기 위한 메커니즘입니다.

### 3.1 작업 증명 (PoW: Proof of Work)

```
특징:
- 채굴자가 복잡한 수학 문제를 풀어 블록 생성 권한 획득
- 높은 보안성, 하지만 에너지 소비 큼
- 대표: Bitcoin, Ethereum (과거)

과정:
1. 트랜잭션 수집
2. 블록 헤더 구성
3. Nonce 값 변경하며 해시 계산
4. 목표 난이도보다 작은 해시 발견 시 블록 생성
```

### 3.2 지분 증명 (PoS: Proof of Stake)

```
특징:
- 보유한 암호화폐 양에 비례하여 블록 생성 권한 부여
- 에너지 효율적
- 대표: Ethereum 2.0, Cardano, Solana

장점:
- 낮은 에너지 소비
- 빠른 트랜잭션 처리
```

### 3.3 기타 합의 알고리즘

- **DPoS (Delegated Proof of Stake)**: 대표자 선출 방식
- **PBFT (Practical Byzantine Fault Tolerance)**: 비잔틴 장애 허용
- **PoA (Proof of Authority)**: 승인된 노드만 블록 생성

## 4. 암호화 기술

### 4.1 해시 함수

```javascript
// SHA-256 해시 예시
Input: "Hello, Blockchain!"
Output: "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069"

특징:
- 단방향성: 해시값에서 원본 데이터 복원 불가
- 결정성: 같은 입력 → 항상 같은 출력
- 충돌 저항성: 같은 해시값을 가진 다른 입력 찾기 어려움
```

### 4.2 공개키 암호화

```
┌──────────────┐     ┌──────────────┐
│   개인키      │     │   공개키      │
│ (Private Key)│     │ (Public Key) │
└──────────────┘     └──────────────┘
       │                    │
       ▼                    ▼
   서명 생성             서명 검증
   복호화                암호화
```

### 4.3 디지털 서명

```
거래 서명 과정:
1. 트랜잭션 데이터 해시 생성
2. 개인키로 해시값 암호화 (서명)
3. 트랜잭션 + 서명 전송
4. 수신자가 공개키로 서명 검증
```

## 5. 스마트 컨트랙트 (Smart Contract)

블록체인 위에서 실행되는 자동화된 계약 코드입니다.

### Solidity 예시 (Ethereum)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleStorage {
    uint256 private storedData;

    // 데이터 저장
    function set(uint256 x) public {
        storedData = x;
    }

    // 데이터 조회
    function get() public view returns (uint256) {
        return storedData;
    }
}
```

### 스마트 컨트랙트 특징

- **자동 실행**: 조건 충족 시 자동으로 실행
- **불변성**: 배포 후 코드 수정 불가
- **투명성**: 코드가 공개되어 누구나 검증 가능

## 6. 블록체인 유형

### 6.1 퍼블릭 블록체인 (Public)

```
- 누구나 참여 가능
- 완전한 탈중앙화
- 예: Bitcoin, Ethereum
```

### 6.2 프라이빗 블록체인 (Private)

```
- 허가된 참여자만 접근
- 빠른 처리 속도
- 예: Hyperledger Fabric
```

### 6.3 컨소시엄 블록체인 (Consortium)

```
- 여러 기관이 공동 운영
- 부분적 탈중앙화
- 예: R3 Corda
```

## 7. 블록체인 트릴레마

```
        보안성 (Security)
            /\
           /  \
          /    \
         /      \
        /________\
  탈중앙화          확장성
(Decentralization) (Scalability)

세 가지를 동시에 완벽히 달성하기 어려움
```

### 해결 방안

- **Layer 2 솔루션**: Lightning Network, Rollups
- **샤딩 (Sharding)**: 네트워크 분할 처리
- **사이드체인**: 메인 체인과 연결된 별도 체인

## 8. 주요 블록체인 플랫폼

| 플랫폼 | 합의 알고리즘 | 특징 |
|--------|---------------|------|
| Bitcoin | PoW | 최초의 암호화폐, 가치 저장 |
| Ethereum | PoS | 스마트 컨트랙트 플랫폼 |
| Solana | PoH + PoS | 고속 처리, 낮은 수수료 |
| Polygon | PoS | Ethereum L2 솔루션 |
| Hyperledger | PBFT | 기업용 프라이빗 블록체인 |

## 9. 블록체인 활용 사례

### 금융 (DeFi)
- 탈중앙화 거래소 (DEX)
- 대출/차입 프로토콜
- 스테이블코인

### NFT (Non-Fungible Token)
- 디지털 아트
- 게임 아이템
- 실물 자산 토큰화

### 공급망 관리
- 제품 추적
- 원산지 증명
- 품질 관리

### 기타
- 투표 시스템
- 의료 기록 관리
- 신원 인증

## 10. 참고 자료

- [Bitcoin 백서](https://bitcoin.org/bitcoin.pdf)
- [Ethereum 백서](https://ethereum.org/whitepaper/)
- [Mastering Bitcoin (O'Reilly)](https://github.com/bitcoinbook/bitcoinbook)
- [Solidity 공식 문서](https://docs.soliditylang.org/)
