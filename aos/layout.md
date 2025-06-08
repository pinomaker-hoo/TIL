# Android Layout

Android에는 Linear Layout, Relative Layout, ConstraintLayout 3가지가 있다.

## Linear Layout

자식 뷰들을 수직 혹은 수평으로 배치하는 레이아웃으로, android:orientation 옵션으로 vertical, horizontal 속성을 사용하며, 각 뷰는 정해진 순서대로 쌓이며 layout_weight를 이용해 공간 분할 가능하다.

장점으로는 간단한 UI 배치에 적합하며 구조가 직관적이지만 중첩이 많아질 경우 성능을 저하하고 복잡한 레이아웃 표현이 어렵다.

## Relative Layout

자식 뷰를 서로의 위치나 부모 기준으로 배치하는 것으로 뷰끼리 위치 관계를 지정한다.

장점으로는 중첩 없이 복잡한 레이아웃을 표현 가능하지만 뷰 간의 의존성이 존재하기에 디버깅/유지보수가 어려울 수 있으며 성능이 중간이다.

## Constraint Layout

뷰들을 양방향 제약 조건으로 배치하며 최신 표준이다. 각 뷰에 대해서 상하좌우 제약 조건을 설정하며, Guideline, Barrier 등 고급 기능을 제공한다.

장점으로는 중첩 없이 복잡한 UI를 표현하기에 퍼포먼스가 좋고, 디자인 에디터에서 시각적으로 구성이 쉽다. 그리고 Motion Layout 연계가 가능하여 애니메이션을 손쉽게 구현 가능하지만 초반 진입 장벽이 존재한다.
