# SQL의 index

인덱스는 쓰기 작업과 저장 공간을 활용하여 데이터베이스 테이블의 검색 속도를 향상 시키기 위한 자료구조다.

데이터베이스에서 테이블의 모든 데이터를 검색하면 시간이 오래 걸리기에 데이터와 데이터의 위치를 포함한 자료구조를 생성하여 빠르게 조회하도록 돕는다.

인덱스는 SELECT 쿼리에서는 성능이 더 좋아지지만 INSERT, UPDATE, DELETE 쿼리에서는 때에 따라 다르게 된다.

### SELECT, INSERT, UPDATE, DELETE?

UPDATE, DELETE는 WHERE에 잘 설정된 인덱스를 조건으로 사용하면 성능 저하되지 않는다. 하지만 이것도 업데이트 자체의 속도에 영향을 주는 것이 아닌 업데이트를 할 데이터를 찾는 데 속도가 빨라지는 거라고 한다.

INSERT의 경우는 새로운 데이터가 추가되면서 기존에 인덱스 페이지에 저장되어있던 탐색 위치가 수정되어야하기에 효율이 좋지 않다고 한다.

### WHERE

인덱스는 where에 효과가 있다고 이해하면 된다. 만약에 Book이라는 테이블에 존재하는 제목, 출판일, 저자 중에서 제목에 인덱스를 설정하였다면 아래의 쿼리 중 3번만 성능이 좋아진다.

```sql
SELECT * FROM Book WHERE author = '저자' -- 1

SELECT * FROM Book WHERE pub_date = '2024-05-01' -- 2

SELECT * FROM Book WHERE title = '제목' -- 3
```

### 설계시 유의할 점

인덱스는 많이 설정하다고 유리하지 않으니 WHERE에 자주 사용되며 특히나 조회 시에 자주 사용되는 컬럼을 지정하는 것이 좋다.

고유한 값을 위주로 잡는 것이 좋으며, 수정이 자주 일어나지 않으며, 정수형 자료가 더 좋다고 한다.

PK나 JOIN의 연결고리가 되는 컬럼이 좋다고 한다. 단일 인덱스 여러 개보단 다중 컬럼 인덱스를 고려하자
