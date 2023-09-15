# Git

## 개요

Git 사용법에 대한 정리

<br />

## 목차

- [1. Git Reset](#1-git-reset)
<br />

  <br />

## 1. Git Reset

이미 Remote Repository에 푸시한 내용들을 다시 Rollback을 하고 싶다면 Git reset을 이용할 수 있다.

```
git reset --hard [commit id]

git push origin +[branch name]
```

git reset을 사용하여 Local Repository에서 과거의 커밋으로 돌아가고, push를 할 때 +를 사용해서 Remote Repository에도 강제로 적용시킨다.

[예시 코드]

```
git reset --hard 2b4d5e2c

git push origin +master
```

<br />
