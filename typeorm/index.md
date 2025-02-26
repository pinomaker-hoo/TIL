# TypeORM

## 개요

Typeorm에 대한 이해

## 목차

[- cascade](#typeorm의-cascade-옵션)
[- method](#typeorm-method)

## Typeorm의 cascade 옵션

cascade는 SQL의 제약 조건 중 하나로, 데이터를 지울 때, 참조 관계가 있을 경우에는 참조되는 데이터까지 자동으로 같이 삭제하는 옵션이다. Typeorm에서는 해당 옵션을 간단하게 지원한다.

```typescript
@Entity()
class User extends BaseEntity {
  @ManyToOne(() => Author, (author) => author.books, {
    onDelete: "CASCADE",
  })
  public group: Group;
}

@Entity()
class Group extends BaseEntity {
  @OneToMany(() => Book, (book) => book.author, {
    cascade: true,
  })
  public user: User[];
}
```

onDelete : "CASCADE" 옵션을 사용하면, group이 삭제될 경우에 user도 같이 삭제되며, cascade : true를 사용하면 group에 user가 추가된 상태로 저장되면 user도 DB에 같이 저장된다.

## TypeORM Method

TypeORM에서는 자체 제공해주는 메소드를 기반으로 여러 처리를 할 수 있다.

1.  save(entity: Entity | Entity[]): Promise<Entity[]>

    save는 ID가 있는 경우 UPDATE 쿼리를, 없는 경우 INSERT 쿼리를 실행한다. 실행한 후에는 변경된 데이터를 반환함.

    ```typescript
    const user = new User();
    user.id = 1; // 기존 ID가 있으면 UPDATE
    user.name = "John Doe";
    await userRepository.save(user);
    ```

    ```sql
    UPDATE user SET name = 'John Doe' WHERE id = 1;
    ```

2.  insert(entity: QueryDeepPartialEntity<Entity> | QueryDeepPartialEntity<Entity>[]): Promise<InsertResult>

    insert는 UPDATE를 하지 않고 오직 생성만 하는 메서드다. save의 경우 PK가 존재하는 지 확인하는 절차를 거치기에 단순 저장만 하는 용도라면 insert만 사용하는 것이 더 좋다.

    ```typescript
    await userRepository.insert({ name: "Alice", email: "alice@example.com" });
    ```

    ```sql
    INSERT INTO user (name, email) VALUES ('Alice', 'alice@example.com');
    ```

3.  update(criteria: any, partialEntity: QueryDeepPartialEntity<Entity>): Promise<UpdateResult>

    update는 조건을 만족하는 데이터를 UPDATE하며, criteria를 기반으로 where를 생성하고, partialEntity만 SET하며 UPDATE를 수행한다. 메서드의 리턴 값은 변경된 row의 개수다.

    ```typescript
    await userRepository.update({ id: 1 }, { name: "Bob" });
    ```

    ```sql
    UPDATE user SET name = 'Bob' WHERE id = 1;
    ```

4.  delete(criteria: any): Promise<DeleteResult>

    DELETE는 조건을 만족하는 데이터를 삭제하며, criteria를 기반으로 where를 생성하여 DELETE를 수행한다. UPDATE와 마찬가지로 제거된 row를 리턴하다.

    ```typescript
    await userRepository.delete({ id: 1 });
    ```

    ```sql
    DELETE FROM user WHERE id = 1;
    ```

5.  softDelete(criteria: any): Promise<UpdateResult>

    softDelete는 deletedAt 필드를 업데이트하여 논리적으로 삭제처리한다.

    ```typescript
    await userRepository.softDelete({ id: 1 });
    ```

    ```sql
    UPDATE user SET deleted_at = NOW() WHERE id = 1;
    ```

6.  restore(criteria: any): Promise<UpdateResult>

    restore은 조건을 만족하는 데이터의 deletedAt을 null로 변경한다.

    ```typescript
    await userRepository.restore({ id: 1 });
    ```

    ```sql
    UPDATE user SET deleted_at = NULL WHERE id = 1;
    ```

7.  remove(entity: Entity | Entity[]): Promise<Entity[]>

    remove는 엔티티를 데이터베이스에서 삭제하는 데 먼저 ID를 기반으로 데이터를 조회하고 그 ID를 기준으로 DELETE SQL를 실행한다.

    ```typescript
    const user = await userRepository.findOneBy({ id: 1 });

    if (user) {
      await userRepository.remove(user);
    }
    ```

    ```sql
    DELETE FROM user WHERE id = 1;
    ```

    이 때 배열로 데이터를 받게 되면 IN으로 처리한다.

    ```typescript
    const users = await userRepository.find({ where: { isActive: false } });
    await userRepository.remove(users);
    ```

    ```sql
    DELETE FROM user WHERE id IN (2, 3, 4, 5);
    ```
