# Tree

## 개요

Tree는 하나의 Root Node에서 시작해 자식 Node들이 가지처럼 뻗어나가는 계층형(비선형) 자료구조다. 사이클이 없는 연결 그래프이며, N개의 Node는 정확히 N-1개의 간선(Edge)으로 연결된다.

파일 시스템의 디렉토리 구조, HTML DOM, 조직도, DB의 B+Tree 인덱스, React의 컴포넌트 트리까지 계층 관계를 표현해야 하는 곳에는 어디든 Tree가 쓰인다.

<br /> <br />

## Tree 용어 정리

```
=====================================================
[시각화] Tree의 구조와 용어
=====================================================

                 [ A ]        <-- Root (depth 0)
                /     \
            [ B ]     [ C ]   <-- A의 Child, 서로 Sibling (depth 1)
            /   \        \
        [ D ]  [ E ]    [ F ] <-- Leaf (자식이 없는 노드, depth 2)
```

- Node : 트리를 구성하는 개별 데이터
- Root : 트리의 시작점이 되는 Node
- Parent / Child : 간선으로 연결된 상하 관계에서 Root에 가까운 쪽이 Parent
- Sibling : 같은 Parent를 가진 Node들
- Leaf : 자식이 없는 말단 Node
- Depth : Root에서 특정 Node까지의 거리
- Height : 트리의 최대 Depth
- Subtree : 트리 내부의 특정 Node를 Root로 삼는 작은 트리

<br />

## Binary Tree (이진 트리)

각 Node가 자식을 최대 2개(Left, Right)까지만 가질 수 있는 트리다. 형태에 따라 몇 가지로 분류된다.

1. Full Binary Tree (정 이진 트리) : 모든 Node의 자식이 0개 아니면 2개
2. Complete Binary Tree (완전 이진 트리) : 마지막 레벨을 제외한 모든 레벨이 꽉 차 있고, 마지막 레벨은 왼쪽부터 채워진 트리. 배열로 표현하기에 최적이라 Heap의 기반이 된다.
3. Balanced Binary Tree (균형 이진 트리) : 좌우 Subtree의 높이 차이가 1 이하로 유지되는 트리

높이가 k인 이진 트리가 가질 수 있는 최대 Node 수는 2^k - 1이다. 거꾸로 말하면 N개의 데이터를 균형 있게 담으면 높이가 log₂N이 되는데, 이것이 Tree 계열 자료구조가 O(log n)을 내는 근거다.

<br />

## Binary Search Tree (이진 탐색 트리)

BST는 "Left Subtree의 모든 값 < 부모 값 < Right Subtree의 모든 값" 규칙을 지키는 이진 트리다. 이 규칙 덕분에 탐색할 때마다 절반의 Subtree를 통째로 배제할 수 있어 평균 O(log n)에 탐색/삽입/삭제가 가능하다.

```
=====================================================
[시각화] BST에서 6을 찾는 과정
=====================================================

                 [ 8 ]        6 < 8 이므로 왼쪽으로
                /     \
            [ 4 ]     [ 12 ]  6 > 4 이므로 오른쪽으로
            /   \
        [ 2 ]  [ 6 ]          발견! (3번 비교로 끝)
                              선형 탐색이었다면 최대 5번 비교
```

```typescript
class TreeNode {
  value: number;
  left: TreeNode | null = null;
  right: TreeNode | null = null;

  constructor(value: number) {
    this.value = value;
  }
}

class BinarySearchTree {
  private root: TreeNode | null = null;

  insert(value: number): void {
    const node = new TreeNode(value);

    if (!this.root) {
      this.root = node;
      return;
    }

    let current = this.root;
    while (true) {
      if (value < current.value) {
        if (!current.left) {
          current.left = node;
          return;
        }
        current = current.left;
      } else {
        if (!current.right) {
          current.right = node;
          return;
        }
        current = current.right;
      }
    }
  }

  search(value: number): boolean {
    let current = this.root;
    while (current) {
      if (value === current.value) return true;
      current = value < current.value ? current.left : current.right;
    }
    return false;
  }
}
```

<br />

### BST의 함정 : 편향 트리

BST의 O(log n)은 트리가 균형 잡혀 있을 때의 이야기다. 정렬된 데이터(1, 2, 3, 4, 5...)를 순서대로 삽입하면 오른쪽으로만 뻗은 Linked List와 다름없는 편향 트리가 되어 모든 연산이 O(n)으로 퇴화한다.

```
=====================================================
[시각화] 편향 트리 (Skewed Tree)
=====================================================

  [ 1 ]
     \
     [ 2 ]         정렬된 순서로 삽입하면
        \          트리가 한쪽으로만 자라서
        [ 3 ]      사실상 Linked List가 된다.
           \       탐색 O(log n) --> O(n)으로 퇴화
           [ 4 ]
```

이 문제를 해결하기 위해 삽입/삭제 시 스스로 균형을 다시 잡는 Self-Balancing Tree가 등장했다.

1. AVL Tree : 좌우 높이 차이를 1 이하로 엄격하게 유지한다. 탐색이 빠른 대신 삽입/삭제 시 회전 비용이 크다.
2. Red-Black Tree : 색 규칙으로 "느슨한 균형"을 유지한다. 삽입/삭제가 잦은 경우에 유리하여 Java의 TreeMap, C++의 std::map, Linux 커널 스케줄러 등 대부분의 표준 라이브러리가 채택했다.
3. B-Tree / B+Tree : 한 Node에 여러 개의 Key를 담아 트리 높이를 극단적으로 낮춘 다진 트리다. Node 하나를 디스크 페이지 크기에 맞춰 디스크 I/O 횟수를 최소화하기 때문에 MySQL(InnoDB) 등 대부분의 DB 인덱스가 B+Tree다.

```
DB 인덱스가 Hash가 아닌 B+Tree인 이유 : Hash는 단건 조회만 O(1)이지만,
B+Tree는 정렬 상태를 유지하고 Leaf들이 Linked List로 연결되어 있어
WHERE age > 20 같은 범위 검색과 ORDER BY를 인덱스만으로 처리할 수 있다.
```

<br />

## 트리 순회 (Traversal)

트리의 모든 Node를 방문하는 방법은 4가지가 있다.

```
                 [ 1 ]
                /     \
            [ 2 ]     [ 3 ]
            /   \
        [ 4 ]  [ 5 ]
```

1. 전위 순회 (Preorder, 나 → 좌 → 우) : 1 2 4 5 3. 트리를 복사하거나 직렬화할 때 쓴다.
2. 중위 순회 (Inorder, 좌 → 나 → 우) : 4 2 5 1 3. BST를 중위 순회하면 오름차순 정렬된 결과가 나온다.
3. 후위 순회 (Postorder, 좌 → 우 → 나) : 4 5 2 3 1. 자식을 먼저 처리해야 하는 삭제/폴더 용량 계산에 쓴다.
4. 레벨 순회 (Level-order) : 1 2 3 4 5. Queue를 이용한 BFS로 층별로 방문한다.

```typescript
// 중위 순회 : BST라면 정렬된 순서로 값이 출력된다
const inorder = (node: TreeNode | null, result: number[] = []): number[] => {
  if (!node) return result;

  inorder(node.left, result);
  result.push(node.value);
  inorder(node.right, result);
  return result;
};

// 레벨 순회 : Queue를 사용하는 BFS
const levelOrder = (root: TreeNode | null): number[] => {
  if (!root) return [];

  const result: number[] = [];
  const queue: TreeNode[] = [root];

  while (queue.length > 0) {
    const node = queue.shift()!;
    result.push(node.value);

    if (node.left) queue.push(node.left);
    if (node.right) queue.push(node.right);
  }
  return result;
};
```

<br />

## 시간 복잡도 정리

| 연산 | 균형 BST | 편향 BST (최악) | Red-Black Tree |
| ---- | -------- | --------------- | -------------- |
| 탐색 | O(log n) | O(n)            | O(log n) 보장  |
| 삽입 | O(log n) | O(n)            | O(log n) 보장  |
| 삭제 | O(log n) | O(n)            | O(log n) 보장  |

<br />

## 정리

1. Tree는 사이클 없는 계층형 자료구조로, 균형이 잡혀 있으면 높이가 log₂N이라 O(log n) 연산이 가능하다.
2. BST는 "왼쪽 < 부모 < 오른쪽" 규칙으로 이진 탐색을 구조화한 것이지만, 정렬된 입력에는 O(n)으로 퇴화한다.
3. 퇴화를 막기 위한 Self-Balancing Tree 중 Red-Black Tree는 인메모리 표준(TreeMap 등), B+Tree는 디스크 기반 DB 인덱스의 표준이다.
4. 순회는 전위/중위/후위/레벨 4가지이며, BST의 중위 순회는 정렬된 결과를 낸다.
