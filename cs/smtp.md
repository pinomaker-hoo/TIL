# SMTP

## SMTP란

SMTP는 Simple Mail Transfer Protocol의 약자로, 인터넷을 통해 이메일을 전송하는 데 사용되는 표준 프로토콜로, 서로 다른 이메일 시스템 간의 메세지 전달 및 중계를 가능하게 해주며 TCP/IP를 기반으로 한다.

## SMTP의 동작 원리

이메일 시스템에는 크게 MUA, MTA, MDA의 3가지 구성 요소가 있다.

1. MUA(Mail User Agent)

   사용자의 이메일 클라이언트로, 메세지를 작성하고 받은 메일을 읽을 수 있다.

2. MTA(Mail Transfer Agent)

   메세지를 수신하고 전달하는 서버로, SMTP를 사용해 메세지를 전송한다.

3. MUA(Mail Delivery Agent)

   메세지를 최종 수신자의 메일 박스에 배달하는 서버

<br />
<br />

SMTP는 아래와 같은 과정을 통해 이메일을 전송한다.

![Image](https://github.com/user-attachments/assets/40289c6f-790f-4fe6-8ec8-89719b887fad)

1. MUA를 통한 이메일 작성 및 발송을 요청
2. MUA는 이메일을 발신자의 MTA로 전송
3. 발신자의 MTA는 DNS를 통해 수신자의 메일 서버 주소 확인하여 수신자의 MTA로 이메일 전달
4. 수신자의 MTA는 MDA로 전달
5. MDA는 이메일을 수신자의 메일 박스에 전달
6. 수신자는 자신의 MUA를 통해 메일 박스를 확인하고 이메일 확인

## AWS SES

AWS SES(Simple Email Service)는 AWS에서 제공하는 클라우드 기반의 이메일 발송 및 수신 서비스다. 대량 이메일 발송과 트랜잭션 이메일 발송, 수신 기능, IP 관리 기능등을 제공한다.

AWS SES는 MTA의 역할을 처리하게 된다. SMTP 서버처럼 이메일을 다른 MTA로 전달하는 역할을 하게 된다. AWS SES는 이메일 발송 서비스이지만, 수신 기능도 사용 가능하다.

AWS SES에서는 두 가지 IP 옵션을 제공한다.

1.  공유 IP

    - 기본적으로 모든 SES 사용자가 공유하는 IP 주소
    - 추가 비용 없이 사용 가능하나, 다른 사용자의 행동에 의해 IP 평판에 영향을 끼칠 수 있음.

2.  전용 IP

    - 특정 AWS 계정에만 할당되는 고유한 IP 주소
    - 다른 사용자와 분리되어 독립적으로 평판 관리 가능
    - 추가 비용 발생함
