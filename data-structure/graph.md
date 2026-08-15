# Graph

## 개요

Graph는 정점(Vertex, Node)과 그것들을 잇는 간선(Edge)으로 구성된 자료구조다. Tree가 "부모-자식"이라는 계층 관계만 표현할 수 있는 것과 달리, Graph는 사이클을 포함한 임의의 연결 관계를 표현할 수 있다. 사실 Tree는 "사이클이 없는 연결 그래프"라는 Graph의 특수한 형태다.

SNS 팔로우 관계, 지도의 도로망, 패키지 의존성(node_modules), MSA 서비스 호출 관계, 추천 시스템까지 "관계"를 다루는 문제는 전부 Graph로 모델링된다.

<br /> <br />

## Graph 용어와 종류

- 정점(Vertex) : 데이터를 담는 개체
- 간선(Edge) : 두 정점의 연결 관계
- 차수(Degree) : 한 정점에 연결된 간선의 수
- 경로(Path) : 한 정점에서 다른 정점까지 간선을 따라가는 길
- 사이클(Cycle) : 출발한 정점으로 다시 돌아오는 경로

종류는 간선의 성질에 따라 나뉜다.

1. 무방향 그래프 (Undirected) : 간선에 방향이 없다. A-B가 연결되면 양쪽 모두 이동 가능하다. (페이스북 친구 관계)
2. 방향 그래프 (Directed) : 간선에 방향이 있다. A→B와 B→A는 다른 간선이다. (인스타그램 팔로우, 패키지 의존성)
3. 가중치 그래프 (Weighted) : 간선에 비용이 붙는다. (지도의 도로 거리, 네트워크 지연 시간)
4. DAG (Directed Acyclic Graph) : 방향이 있고 사이클이 없는 그래프. 작업 의존성 표현의 표준으로 빌드 시스템, Airflow 파이프라인, Git 커밋 히스토리가 DAG다.

```
=====================================================
[시각화] 방향 그래프 예시 (패키지 의존성)
=====================================================

  [ app ] ---> [ express ] ---> [ body-parser ]
     |                                 ^
     |                                 |
     +--------> [ multer ] ------------+

* "app은 express와 multer에 의존하고, 둘 다 body-parser에 의존한다"
* 순환 의존(사이클)이 생기면 빌드/설치가 꼬이는데, 이를 감지하는 것도 그래프 알고리즘이다.
```

<br />

## Graph를 코드로 표현하기

### 1. 인접 행렬 (Adjacency Matrix)

V x V 크기의 2차원 배열로, `matrix[i][j] = 1`이면 i에서 j로 가는 간선이 있다는 뜻이다.

```
     A  B  C  D
  A [ 0, 1, 1, 0 ]     A --> B, A --> C
  B [ 0, 0, 0, 1 ]     B --> D
  C [ 0, 0, 0, 1 ]     C --> D
  D [ 0, 0, 0, 0 ]
```

두 정점의 연결 여부를 O(1)에 확인할 수 있지만, 간선이 없어도 V² 만큼의 메모리를 쓴다. 정점 수가 적고 간선이 빽빽한(dense) 그래프에 적합하다.

### 2. 인접 리스트 (Adjacency List)

각 정점마다 "연결된 정점 목록"을 저장한다. 실무와 코딩 테스트에서 대부분 이 방식을 쓴다.

```typescript
const graph = new Map<string, string[]>([
  ["A", ["B", "C"]],
  ["B", ["D"]],
  ["C", ["D"]],
  ["D", []],
]);
```

메모리를 V + E 만큼만 쓰기 때문에 간선이 드문(sparse) 그래프에 효율적이다. SNS처럼 사용자 수는 수억인데 팔로우는 인당 수백 개인 경우가 여기에 해당한다.

| 항목             | 인접 행렬 | 인접 리스트 |
| ---------------- | --------- | ----------- |
| 메모리           | O(V²)     | O(V + E)    |
| 간선 존재 확인   | O(1)      | O(degree)   |
| 인접 정점 순회   | O(V)      | O(degree)   |

<br />

## Graph 탐색 : DFS와 BFS

Graph의 모든 알고리즘의 출발점은 탐색이다. Tree와 달리 사이클이 있을 수 있으므로 방문한 정점을 기록(visited)하지 않으면 무한 루프에 빠진다.

### DFS (깊이 우선 탐색)

한 방향으로 끝까지 파고들었다가 막히면 되돌아온다. 재귀(Call Stack) 또는 명시적 Stack으로 구현한다.

```typescript
const dfs = (
  graph: Map<string, string[]>,
  start: string,
  visited = new Set<string>()
): string[] => {
  visited.add(start);
  const result = [start];

  for (const next of graph.get(start) ?? []) {
    if (!visited.has(next)) {
      result.push(...dfs(graph, next, visited));
    }
  }
  return result;
};
```

경로 존재 여부, 사이클 감지, 위상 정렬, 백트래킹(모든 경우의 수 탐색)에 쓰인다.

```
정점이 수십만 개인 그래프를 재귀 DFS로 돌면 Call Stack이 터질 수 있다
(Maximum call stack size exceeded). 깊이가 깊어질 수 있는 데이터라면
명시적 Stack을 사용한 반복문 구현으로 바꿔야 한다.
```

### BFS (너비 우선 탐색)

시작점에서 가까운 정점부터 층별로 방문한다. Queue로 구현한다.

```typescript
const bfs = (graph: Map<string, string[]>, start: string): string[] => {
  const visited = new Set<string>([start]);
  const queue: string[] = [start];
  const result: string[] = [];

  while (queue.length > 0) {
    const current = queue.shift()!;
    result.push(current);

    for (const next of graph.get(current) ?? []) {
      if (!visited.has(next)) {
        visited.add(next);
        queue.push(next);
      }
    }
  }
  return result;
};
```

층별로 퍼져나가는 특성 때문에 가중치 없는 그래프의 최단 경로는 BFS가 답이다. "A와 B는 몇 다리 건너면 아는 사이인가" 같은 문제가 대표적이다.

```
=====================================================
[시각화] DFS vs BFS 방문 순서
=====================================================

        [ 1 ]                DFS : 1 -> 2 -> 4 -> 5 -> 3
       /     \                     (한 갈래를 끝까지)
    [ 2 ]   [ 3 ]
    /   \                    BFS : 1 -> 2 -> 3 -> 4 -> 5
 [ 4 ] [ 5 ]                       (가까운 층부터)
```

<br />

## 대표 그래프 알고리즘

1. 최단 경로 : 가중치가 없으면 BFS, 가중치가 있으면 다익스트라(Min Heap 사용), 음수 가중치가 있으면 벨만-포드를 쓴다. 지도 앱의 길찾기가 이 계열이다.
2. 위상 정렬 (Topological Sort) : DAG에서 의존 순서를 지키는 실행 순서를 뽑아낸다. npm install의 패키지 설치 순서, 빌드 순서 결정, 수강 신청 선수과목 문제가 여기 해당한다.
3. 사이클 감지 : 방향 그래프에서 DFS 중 "현재 경로 위의 정점"을 다시 만나면 사이클이다. 순환 의존성 검사(madge 같은 도구)가 이 원리다.
4. 최소 신장 트리 (MST) : 모든 정점을 최소 비용으로 연결하는 간선 집합을 찾는다(크루스칼, 프림). 네트워크 케이블 최소 비용 설계 같은 문제다.

<br />

## 정리

1. Graph는 정점과 간선으로 임의의 관계를 표현하는 자료구조이며, Tree는 사이클 없는 Graph의 특수형이다.
2. 표현 방식은 인접 행렬(O(V²), dense에 유리)과 인접 리스트(O(V+E), sparse에 유리)가 있고 실무는 대부분 인접 리스트다.
3. 탐색은 DFS(Stack/재귀, 끝까지 파고들기)와 BFS(Queue, 층별 확산)가 기본이며, 사이클 때문에 visited 관리가 필수다.
4. 가중치 없는 최단 경로는 BFS, 있으면 다익스트라, 의존 순서는 위상 정렬로 해결한다.
