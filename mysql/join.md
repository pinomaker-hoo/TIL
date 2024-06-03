# MySQL의 JOIN에 대해 정리 합니다.

## JOIN

JOIN은 데이터베이스에서 여러 테이블에서 가져온 데이터를 조합하여 하나의 테이블이나 결과 집합으로 표현하는 문법이다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/51b5a12a-065e-4d79-bcef-b36cc560cfa3)

### INNER JOIN

조인하는 테이블의 on절의 조건이 일치하는 경우만 출력하며, MySQL에선 JOIN, INNER JOIN, CROSS JOIN이 다 같은 의미다.

```sql
select board.id, comment.id
from board
inner join comment
on comment.id = 10
```

또한 from에 ,를 사용하여 함축할 수도 있다.

```sql
select board.id, comment.id
from board, comment
where board.id = comment.boardId and comment.id = 10
```
