# 페이징 쿼리

원하는 전체 데이터에 대해 부분적으로 나워서 데아터를 조회 및 처리함.
DB 및 어플리케이션 서버의 리소스 사용 효율을 증가시킴
어플리케이션 단의 처리 시간 단축

페이징 쿼리 작성

주로 LIMIT & OFFSET 구문을 사용하지만 해당 부분은 오히려 더 많은 부하를 발생시킬 수 있다.

순차적으로 레코드를 읽지 않고 지정된 OFFSET 이후 데아터만 바로 가져올 수는 없기에 이를 사용하면 쿼리 실행 횟수가 늘어날수록 더 읽는 데이터가 많아지고 응답 시간이 길어진다.

예를 덜어서 500건씩 n번을 조회하는 것과 한 번에 모두를 읽는 것을 비교하면 오히려 한 번에 모두 읽는 것이 더 많은 데이터를 읽고 처리하게 된다.

LIMIT & OFFSET을 사용 안하고는 범위 기반 방식

### 범위 기반 방식

날짜 기간이나 숫자 범위를 기준으ㅗㄹ 데이터를 조회하는 것으로 WHERE절에서 조회 범위를 직접 지정하기에 LIMIT을 사용하지 않는다.

주로 배치 작업 등에서 전체 데이터를 일정한 날짜/숫자 범위로 나눠서 조회할 떄 사용하며 이를 사용하게 되면 조회 조건도 단순하며, 여러번 쿼리를 나누어 실행해도 쿼리 형태는 동일하ㅏㄷ.

숫자인 ID를 기준으로 데이터 조회

```sql
SELECT * FROM users
where id > 0 AND id <= 5000
```

```sql
SELECT * FROM payments
WHERE finished_at >= '2022-03-01' AND finished_at < '2022-03-02'
```

### 데이터 개수 기반 방식

지정된 데이터 건수만큼 결과 데이터를 반환함.

배치보단 주로 서비스 단에서 많이 사용되는 방식으로 쿼리에서 ORDER BY \* LIMIT 절이 사용됨.

1회차와 N회차의 쿼리 형태가 달라진다.

```sql
-- 1회차
select * from payments
where user_id = ?
order by id
LIMIT 30

-- n회차
select * from payments
where user_id = ? AND id > {이전 데이터의 마지막 ID 값}
order by id
LIMIT 30
```

아래 예시는 범위 조건이다.

```sql
-- 1회차
select * from payments
where finished_at >= (시작 날짜) AND finished_at <= {종료 날짜}
order by finished_at, id
LIMIT 30
```

id만 order에 명시하면 조건을 만족하는 데이터를 id로 정렬한 다음 지정된 건수만큼 반환하게 되는 데, finished_at를 선두에 명시하면 인덱스를 사용하여 정렬 작업 없이 원하는 건수만큼 순차적으로 읽어 처리 효율 향상됨

```sql
-- 2회차
select * from payments
where finished_at = ('2024-01-01 00:00:02' AND id > 8) OR (finished_at > '2024-01-01 00:00:02' AND finished_at < '2024-01-02 00:00:00')
order by finished_at, id
limit 5
```

실제로 필요한 데이터만 읽어서 반환한다.
