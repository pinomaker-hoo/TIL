# TypeORM

## 개요

Typeorm에 대한 이해

## 목차

[- cascade](#typeorm의-cascade-옵션)

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
