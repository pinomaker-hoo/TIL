# NodeJS Event

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/5b62420a-0576-4cda-9cc4-e2b8684d0084)

위의 사진은 NodeJS의 전체적은 구조다. NodeJS에서 사용할 수 있는 API는 ECMAScript 표준 라이브러리와 언어에 포함되지 않는 고유한 NodeJS API다.

참고로 NodeJS API는 Javascript와 C++로 구현되어있다고 한다.

NodeJS는 내장된 V8 자바스크립트 엔진을 통해 JS를 실행한다.

## NodeJS 전역 변수

NodeJS에는 다양한 내장 변수가 존재한다.

- crypto : 웹과 호완되는 crypto API에 대한 권한 제공
- console : 브라우저의 동일한 전역 변수와 유사함.
- fetch : Fetch API를 사용할 수 있게됨.
- process : process class의 인스턴스가 포함되어 커맨드라인 매개변수와 표준 입력 표준 출력에 접근 가능.
- structuredClone : 개체 복사를 위한 브라우저 호완 함수
- URL : URL을 처리하는 클래스
