# Redux

## 개요

Redux에 대한 이해(With React)

참고 자료 : https://ko.redux.js.org/introduction/getting-started/

## 목차

## Redux란

Redux는 Action Event를 사용하여 application의 상태를 관리하고 업데이트 하기 위한 패턴 및 라이브러리로 중앙 집중식 상태 저장소 역할을 하며, Redux를 사용하면 전역 상태를 관리하는 데 용이하기에 자주 사용된다.

Redux는 JS 라이브러리이기에, React나 Vue와 같은 프레임워크나 라이브러리에 종속되지 않기에 범용성이 높다는 장점이 있다.

### 상태

React에서 버튼을 눌렀을 때 counter를 증가하는 로직이다.

```javascript
function Counter() {
  const [counter, setCounter] = useState(0);

  const increment = () => {
    setCounter((prevCounter) => prevCounter + 1);
  };

  return (
    <div>
      Value: {counter} <button onClick={increment}>Increment</button>
    </div>
  );
}
```

<br />

View에 해당하는 Button을 클릭하는 것을 Trigger로 하여 이벤트를 발생시키고, 그 이벤트가 counter라는 상태를 변경하고 UI는 해당 상태를 기반으로 렌더링되는 것이 일반적인데 이것을 단방향 데이터 흐름이라고 한다.

<br />

<img src="https://github.com/pinomaker-hoo/TIL/assets/56928532/f935570d-fc1f-4aa2-8ec3-66319bb47dba" width="600px">

<br />

하지만 동일한 상태를 공유하며 사용해야하는 요소가 여럿 있는 경우에는 이러한 단순성이 깨질 수 있기에 Redux는 해당 구성 요소에서 상태를 트리 외부의 중앙에 배치하여 트리의 위치에 상관 없이 상태에 접근 가능하게 Redux는 돕는다.

즉 상태 관리와 관련된 개념을 분리하고 뷰와 상태간의 독립성을 유지하는 규칙을 이용하여 더 많은 구조와 유지 관리 가능성을 제공하는 것이 Redux의 기본 생각이다.

### Action

Action은 Reducer에서 상태를 변경하기 위해 수신하는 객체로 주로는 type과 payload로 이루어져있고 type은 이벤트 종류를 payload는 전달할 데이터를 담을 수 있어 어플리케이션에서 발생한 이벤트를 설명하는 이벤트라고 생각할 수 있다.

액션은 주로 액션 생성자를 기반으로 액션 객체를 생성하여 리듀서에 전달하게 된다.

```javascript
// ** Action
const addTodoAction = {
  type: "todos/todoAdded",
  payload: "Buy milk",
};

// ** Action 생성자
const addTodo = (text) => {
  return {
    type: "todos/todoAdded",
    payload: text,
  };
};
```

### Reducer

리듀서는 현재 state와 action 객체를 수신하여 필요한 경우 상태를 업데이트 하는 방법을 결정하고 새로운 상태를 반환하는 함수다. 즉 수신된 이벤트 유형을 기반으로 이벤트를 처리하는 리스너이며 Redux의 핵심 개념이다.

리듀서에는 특정 규칙이 존재한다.

- state, action을 기반을 새 상태 값만 계산해야한다.
- 기존 state를 사용하는 것이 아닌 값을 복사하고 변경하는 불변 업데이트를 수행해야한다.
- 비동기 논리를 수행하거나 다른 부작용을 유발해서는 안된다.

<br />

```javascript
const initialState = { counter: 0 };

function counterReducer(state = initialState, action) {
  if (action.type === "counter/increment") {
    return {
      ...state,
      value: state.value + 1,
    };
  }

  return state;
}
```

<br />

### store

store는 리덕스의 상태를 저장하는 중앙 저장소이며, 리듀서를 전달 받아 생성되고 getState와 같은 현재 상태를 반환하는 메서드들이 있다.

<br />

```javascript
import { configureStore } from "@reduxjs/toolkit";

const store = configureStore({ reducer: counterReducer });

console.log(store.getState());
// {value: 0}
```

<br />

### dispatch

Redux 저장소에 상태를 업데이트 하는 유일한 방법은 store.dispatch()에 액션 객체를 전달하는 것이다. dispatch가 발생하면 저장소는 리듀서 함수를 실행하여 새 상태를 내부에 저장하고 업데이트된 값을 getState()를 이용하여 호출 가능하다.

<br />

```javascript
store.dispatch({ type: "counter/increment" });

console.log(store.getState());
// {value: 1}
```

<br />

### Redux의 데이터 흐름

기존의 단방향 데이터 흐름은 상태는 특정 시점의 앱 상태를 설명하고, UI는 이 상태를 기반으로 렌더링된다. 어떤 이벤트가 발생하게 되면 이에 따라서 상태가 없데이트 되고 UI가 다시 랜더링 되는 구조인데 Redux는 좀 더 이 구조를 자세히 나눌 수 있다.

1. 초기 설정

   - Redux Store는 리듀서를 통해 생성됨.
   - store는 root reducer를 한 번 호출하고 반환된 값을 초기 값으로 사용
   - UI의 렌더링 후에는 UI의 구성요소가 Redux 저장소 상태에 대해 접근하고 상태가 변경되었는 지 상태를 구독한다.

2. 업데이트
   - UI에서 이벤트가 발생하면, diaptch를 이용하여 Redux에 액션 객체를 전달한다.
   - 저장소는 리듀서에 액션 객체를 전달하여 실행해 새로운 상태를 반환받고 그 값을 저장한다.

<br />

<img src="https://github.com/pinomaker-hoo/TIL/assets/56928532/54e4d0d8-8ece-405b-8918-b35d0ebe8e36" width="600px">

<br />
