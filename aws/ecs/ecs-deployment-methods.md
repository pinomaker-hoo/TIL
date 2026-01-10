# AWS ECS 배포 방법

AWS ECS에 애플리케이션을 배포하는 방법은 여러 가지가 있습니다. 수동 배포도 가능하지만, 대부분의 프로덕션 환경에서는 자동화된 CI/CD 파이프라인을 구축하여 배포합니다. 아래에서 다양한 ECS 배포 방법을 살펴보겠습니다.

## 1. AWS 관리 콘솔을 통한 수동 배포

AWS 관리 콘솔을 통해 수동으로 ECS에 배포하는 것이 가능합니다. 하지만 이 방법은 테스트 환경이나 간단한 업데이트에만 적합합니다.

### 수동 배포 단계:

1. **AWS 콘솔 로그인**: AWS 관리 콘솔에 로그인합니다.
2. **ECS 서비스 접속**: ECS 서비스로 이동합니다.
3. **클러스터 선택**: 배포할 클러스터를 선택합니다.
4. **서비스 업데이트**: 기존 서비스를 선택하고 '업데이트' 버튼을 클릭합니다.
5. **새 작업 정의 선택**: 새 버전의 작업 정의를 선택합니다.
6. **배포 옵션 설정**: 롤링 업데이트 등의 배포 옵션을 설정합니다.
7. **업데이트 적용**: 변경 사항을 저장하고 배포를 시작합니다.

## 2. AWS CLI를 사용한 배포

AWS CLI(Command Line Interface)를 사용하면 명령줄에서 ECS 배포를 자동화할 수 있습니다.

### CLI 배포 예시:

```bash
# 새 작업 정의 등록
aws ecs register-task-definition --cli-input-json file://task-definition.json

# 서비스 업데이트
aws ecs update-service \
  --cluster my-cluster \
  --service my-service \
  --task-definition my-task-definition:latest \
  --force-new-deployment
```

## 3. AWS CodePipeline을 사용한 CI/CD 파이프라인

AWS CodePipeline을 사용하여 소스 코드 변경부터 ECS 배포까지 완전 자동화된 CI/CD 파이프라인을 구축할 수 있습니다.

### 파이프라인 구성 요소:

1. **소스 스테이지**: GitHub, CodeCommit 등에서 소스 코드 변경 감지
2. **빌드 스테이지**: CodeBuild를 사용하여 Docker 이미지 빌드 및 ECR에 푸시
3. **배포 스테이지**: ECS 서비스 업데이트

### 작동 방식:

1. 개발자가 코드를 리포지토리에 푸시합니다.
2. CodePipeline이 변경을 감지하고 파이프라인을 트리거합니다.
3. CodeBuild가 Docker 이미지를 빌드하고 ECR에 푸시합니다.
4. 새 이미지를 참조하는 새 작업 정의가 생성됩니다.
5. ECS 서비스가 새 작업 정의로 업데이트됩니다.

## 4. AWS CDK 또는 CloudFormation을 사용한 인프라스트럭처 코드(IaC)

AWS CDK(Cloud Development Kit) 또는 CloudFormation을 사용하여 ECS 인프라와 배포를 코드로 정의할 수 있습니다.

### CDK 예시 (TypeScript):

```typescript
import * as cdk from 'aws-cdk-lib';
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecr from 'aws-cdk-lib/aws-ecr';

export class MyEcsStack extends cdk.Stack {
  constructor(scope: cdk.App, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // ECR 리포지토리 참조
    const repository = ecr.Repository.fromRepositoryName(
      this,
      'Repository',
      'my-app-repo'
    );

    // ECS 클러스터
    const cluster = new ecs.Cluster(this, 'Cluster', {
      vpc: vpc,
    });

    // Fargate 서비스
    const service = new ecs.FargateService(this, 'Service', {
      cluster,
      taskDefinition: new ecs.FargateTaskDefinition(this, 'TaskDef', {
        memoryLimitMiB: 512,
        cpu: 256,
      }),
      desiredCount: 2,
    });

    // 컨테이너 추가
    const container = service.taskDefinition.addContainer('Container', {
      image: ecs.ContainerImage.fromEcrRepository(repository, 'latest'),
      memoryLimitMiB: 512,
    });

    container.addPortMappings({
      containerPort: 80,
    });
  }
}
```

## 5. Terraform을 사용한 배포

Terraform을 사용하여 ECS 인프라와 배포를 관리할 수 있습니다.

### Terraform 배포 워크플로우:

1. Terraform 코드로 ECS 인프라 정의
2. CI/CD 파이프라인에서 Docker 이미지 빌드 및 ECR 푸시
3. 새 이미지 태그로 Terraform 변수 업데이트
4. `terraform apply`를 실행하여 ECS 서비스 업데이트

## 6. GitHub Actions를 사용한 배포

GitHub Actions를 사용하여 GitHub에서 직접 ECS 배포 파이프라인을 구축할 수 있습니다.

### GitHub Actions 워크플로우 예시:

```yaml
name: Deploy to Amazon ECS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: Deploy
    runs-on: ubuntu-latest

    steps:
    - name: Checkout
      uses: actions/checkout@v2

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ap-northeast-2

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1

    - name: Build, tag, and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: my-app-repo
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        echo "::set-output name=image::$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

    - name: Fill in the new image ID in the Amazon ECS task definition
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: task-definition.json
        container-name: my-container
        image: ${{ steps.build-image.outputs.image }}

    - name: Deploy Amazon ECS task definition
      uses: aws-actions/amazon-ecs-deploy-task-definition@v1
      with:
        task-definition: ${{ steps.task-def.outputs.task-definition }}
        service: my-service
        cluster: my-cluster
        wait-for-service-stability: true
```

## 7. AWS Copilot을 사용한 간소화된 배포

AWS Copilot은 ECS 애플리케이션의 빌드, 릴리스 및 운영을 간소화하는 CLI 도구입니다.

### Copilot 명령어 예시:

```bash
# 애플리케이션 초기화
copilot app init my-app

# 서비스 생성
copilot svc init --name api --svc-type "Load Balanced Web Service"

# 환경 생성
copilot env init --name prod --profile default --app my-app

# 배포
copilot svc deploy --name api --env prod
```

## 8. Blue/Green 배포 전략

ECS는 AWS CodeDeploy와 통합하여 블루/그린 배포를 지원합니다. 이 방법은 새 버전(그린)을 배포하고 트래픽을 점진적으로 이동시킨 후, 문제가 없으면 이전 버전(블루)을 제거합니다.

### 블루/그린 배포 설정:

1. CodeDeploy 애플리케이션 및 배포 그룹 생성
2. ECS 서비스에 대한 배포 구성 설정
3. 트래픽 라우팅 및 롤백 설정 구성
4. 배포 트리거 및 모니터링

## 배포 모범 사례

1. **컨테이너 이미지 태깅**: 의미 있는 태그 전략 사용 (예: Git 커밋 해시, 시맨틱 버전)
2. **불변 인프라**: 새 버전을 배포할 때 기존 리소스를 수정하지 않고 새 리소스 생성
3. **비밀 관리**: 민감한 정보는 AWS Secrets Manager 또는 Parameter Store 사용
4. **롤백 계획**: 배포 실패 시 자동 롤백 메커니즘 구현
5. **모니터링**: CloudWatch를 통한 배포 모니터링 및 경보 설정
6. **점진적 배포**: 카나리 배포 또는 트래픽 분할을 통한 위험 최소화

## 결론

AWS ECS에 배포하는 방법은 여러 가지가 있으며, 프로젝트의 복잡성과 요구 사항에 따라 적절한 방법을 선택할 수 있습니다. 소규모 프로젝트나 테스트 환경에서는 AWS 콘솔이나 CLI를 통한 수동 배포가 적합할 수 있지만, 프로덕션 환경에서는 CI/CD 파이프라인을 구축하여 배포 프로세스를 자동화하는 것이 좋습니다. AWS CodePipeline, GitHub Actions, Jenkins 등의 도구를 사용하여 소스 코드 변경부터 ECS 배포까지 완전 자동화된 파이프라인을 구축할 수 있습니다.
