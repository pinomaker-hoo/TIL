# MySQL Function

MySQL에서의 함수 종류는 아래 3가지가 있다.

- Built-in Function
- User Defined Function(UDF)
- Stored Function

## DETERMINISTIC(확정적) vs NOT DETERMINISTIC(비확정적)

MySQL Function 이 둘 중 1개의 속성을 가지게 된다. 속성을 가지지 않거나, 동시에 가질 수는 없다.

### DETERMINISTIC(확정적)

동일 상태와 동일 입력으로 호출할 때 동일한 결과를 반환해야한다. 사용자 테이블의 레코드가 달라지는 것도 상태가 바뀌는 것으로 간주한다.

### NOT DETERMINISTIC(비확정적)

시기에 따라 결과가 달라진다.
