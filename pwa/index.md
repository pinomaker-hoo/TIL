# PWA

![Image](https://github.com/user-attachments/assets/57f615e8-87c3-4cc5-a6f0-ca33dbf2e893)

PWA는 Progressive Web App의 약자로 웹과 네이티브 앱의 기능 모두 이점을 갖도록 특정 기술과 표준 패턴을 사용해 개발된 웹앱이다.

일반적으로 앱을 개발한다고 하면 3가지 방법을 사용한다.

1. Native APP

   android는 java/kotlin과 android studio를 사용해서 만들고, ios는 object-c/switf와 xcode를 사용하여 만든다. Native App의 경우는 네이티브 API를 직접 호출하기에 빠른 속도와 부드러운 UI/UX를 제공 가능하며, OS 별로 최신 기능을 가장 빠르게 지원하고 OS에 최적화된 어플을 개발 가능하지만 1개의 서비스에 ios/aos를 각각 개발해야하기에 리소스가 많이 필요하다는 것이 단점이다.

2. Cross Platform App

   React Native나 Flutter를 사용하여, 단일 코드 베이스로 ios/aos를 모두 개발 가능하기에 속도도 빠르고 리소스가 소모가 적다 또한 핫 리로드 기능을 사용할 수도 있으며 충분히 네이티브 기능을 사용할 수 있으나 네이티브 대비하여 최신 기능 지원에 대한 속도와 패키지 의존도 문제, 속도 문제가 있을 수 있다.

3. Webview App

   Webview App은 웹 사이트를 모바일 사이즈에 대응하게 구현하여 이를 패키징하여 제공하는 앱이다. 이는 기존 웹 사이트가 있다면 최소한의 수정으로 앱을 출시 가능하며, 앱을 업데이트 하지 않고 웹을 업데이트 하여 최신화 할 수 있고, 네이티브 기술 없이도 개발 가능하다는 장점이 있지만 심사가 어렵고, 네이티브 기능을 제한적으로 사용할 수 있고 브라우저 엔진을 사용하기에 느린 단점이 있다.

3가지 방법을 상황에 맞게 사용하면 된다. 나 같은 경우는 주로 Cross Platform App을 사용하거나 Webview App을 사용하여 개발해 리소스를 줄이는 경우가 많았다.

PWA는 웹뷰 패키징과 유사하지만 다르다. 가장 큰 차이는 브라우저 기능으로만 돌아간다는 것이다. PWA의 경우는 3가지 요소로 구성된다.

- Service Worker

  백그라운드에서 실행되는 스크립트로, 오프라인 캐싱, 푸시 알림, 백그라운드 동기화 등을 처리 한다.

- Web App Manifest

  앱의 메타 정보를 JSON으로 정의하여 이를 기반으로 홈 화면에 추가 기능을 제공한다.

- Https

  PWA는 보안으로 HTTPS 환경에서만 작동한다.

PWA를 사용하면 아래와 같은 장점이 있다.

1. 설치 없이 네이티브와 같은 경험을 제공한다.

   PWA는 별도의 앱 스토어에서 설치를 하는 것이 아닌 홈화면에 바로 추가하여 사용 하는 것이기에 접근성이 낮다.

2. 빠른 로딩 속도와 오프라인 지원

   Service Worker를 활용해 캐싱을 통해 빠른 페이지 로딩과 오프라인 상태를 지원 가능하다.

3. 푸시 알림 지원

   이전에는 iOS에선 지원을 안 해줬는 데, 현재는 둘 다 가능하다.(ios 16.4부터 지원)

4. 크로스 플랫폼 지원

   하나의 코드 베이스로 iOS, Android, Windows까지 지원하여 개발 비용을 절감 가능하다.

5. 앱 스토어 심사가 필요 없다.

   브라우저에서 앱을 제공하기에 앱 심사 없이 웹 사이트 배포만으로 제공이 가능하다.

<br />
<br />

## React로 PWA 구현하기.

라이브러리

```
React 18
Vite
Typescript
```

위의 조건에서 진행하였기에 나는 vite-plugin-pwa를 설치하여 진행한다.

```
pnpm add -D vite-plugin-pwa
```

위의 패키지를 설치한 후에 vite.config.js를 아래와 같이 구성한다.

```typescript
import react from "@vitejs/plugin-react-swc";
import { defineConfig } from "vite";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      manifest: {
        name: process.env.VITE_APP_NAME || "My PWA App",
        short_name: process.env.VITE_APP_SHORT_NAME || "PWA App",
        description:
          process.env.VITE_APP_DESCRIPTION ||
          "This is a PWA using Vite and React",
        theme_color: "#ffffff",
        background_color: "#ffffff",
        display: "standalone",
        icons: [
          {
            src: "/pwa-icon-192.png",
            sizes: "192x192",
            type: "image/png",
          },
          {
            src: "/pwa-icon-512.png",
            sizes: "512x512",
            type: "image/png",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,png,svg}"],
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024, // 4MB까지 허용
      },
      injectManifest: {
        maximumFileSizeToCacheInBytes: 4 * 1024 * 1024, // injectManifest 설정에도 추가
      },
    }),
  ],

  resolve: {},
});
```

그리고 배포를 하게되면, 브라우저에서 홈화면 추가 기능을 통해 앱을 사용 가능하다.
