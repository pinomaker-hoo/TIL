# Count Query

우리는 데이터 개수를 얻기 위해 보통 COUNT(*)를 사용한다. 사람들은 대다수가 SELECT *과 SELECT COUNT(\*)를 비교하면 SELECT \*가 더 무거울 거라고 생각하지만 실제로는 별 차이가 없다고 한다.

보통 SELECT _은 LIMIT 조건을 동반하고 COUNT(_)는 LIMIT이 없는 것이 일반적이다. 참고로 ORM에서 제공하는 COUNT 메서드는 주로 COUNT(DISTICT(id)) 처리를 하기에 부하가 심하다.

```sql
# Typeorm이 생성하는 COUNT 쿼리

SELECT COUNT(DISTINCT(id)) as counter
FROM tab
WHERE fd1 = ?;
```

COUNT 쿼리는 Covering Index를 기준으로 처리해야 성능 개선이 가능하다고 한다.

## COUNT(\*) VS COUNT(DISTINCT)

COUNT 쿼리는 레코드의 건수만 확인하지만 COUNT(DISTINCT)는 임시 테이블을 생성하여 중복된 데이터를 제거한 후에 건수를 확인하기에 더 성능상 좋지 않다. 이 때 임시 테이블에 중복 데이터가 존재하면 UPDATE를 아니라면 INSERT를 사용하여 임시 레코드를 생성해 처리한다.

이 때 보통 id가 PK라면 고유값이기에 의미 없는 논리식이다.

## COUNT(\*) 튜닝

- 최고의 튜닝은 쿼리 자체를 제거하는 것이다.

  예를 들어 전체 결과를 확인한느 쿼리를 제거하고 번호 없이 "이전" "이후" 개념으로 페이지를 이동하는 방법이 있다. 또한 WHERE 조건이 없는 COUNT(\*)나 WHERE 조건에 일치하는 레코드 건수가 많은 COUNT를 제거해야한다.

- 대략적인 건수를 활용

  부분 레코드 건수를 조회한다거나 임의의 페이지 번호를 표기하거나 통계 정보를 활용하여 정확하진 않지만 유사한 데이터를 제공하여 개선할 수 있다.

- 통계 정보 이용

  쿼리에 대한 조건이 없는 경우는 테이블 통계를 활용하여 제공할 수 있다. 해당 부분은 성능이 빠르지만 페이지 이동하면서 보정이 필요하다

- 인덱스 활용

  정확한 COUNT(_)가 필요하거나 COUNT(_) 대상 건수가 소량이고 WHERE 조건이 인덱스로 처리할 수 있으면 인덱스를 사용하는 것이 좋다

## COUNT(DISTINCT) 튜닝

TypeORM은 COUNT를 DISTINCT를 활용하기에 예제로 살펴보자.

```javascript
const comments = await getRepository(CommentEntity)
    .createQueryBuilder("comment")
    .where("comment.hidden = FALSE")
    .andWhere("comment.shopBlockId in (:...neighborBlockIds)", {neighborBlockids})
    .innerJoinAndSelect(
        "comment.shop",
        "shop",
        "shop",
        "shop.categoryId IN (...)",
        {categoryIds}
    )
    .andWhere("shop.status = 0")
    .select(["comment.id", "comment.score", ...])
    .orderBy("comment.score", "DESC")
    .take(20)
    .getMany()
```

해당 코드를 작성했을 때 TypeORM은 아래와 같이 쿼리를 생성해준다.

```sql
SELECT DISTINCT
    distinctAlias.comment_id AS ids_comment_id,
    distinctAlias.comment_score
FROM (
    SELECT
        comment.id AS comment_id,
        comment.user_id as comment_user_id,
    FROM shop_comments comment
    INNER JOIN shop ON shop.id = comment.shop_id
    AND shop.category_id IN (...)
    WHERE comment.hidden = FALSE
        AND comment.shop_block_id IN (...)
        AND ...
) distinctAlias
ORDER BY
    distinctAlias.comment_score DESC,
    comment_id ASC
LIMIT 20
```

해당 결과를 보면 단순하게 SELECT를 할 것 같지만 DISTINCT를 사용하여 쿼리를 실행하게 된다.
