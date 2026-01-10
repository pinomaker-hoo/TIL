# Bitbucket과 AWS CodePipeline 연동하기

Bitbucket을 소스 코드 저장소로 사용하면서 AWS CodePipeline을 통해 ECS에 자동 배포하는 방법을 알아보겠습니다. Bitbucket의 코드 변경을 트리거로 하여 AWS의 CI/CD 파이프라인을 실행할 수 있습니다.

## Bitbucket과 AWS CodePipeline 연동 방법

AWS CodePipeline은 기본적으로 Bitbucket과의 직접 통합을 제공하지 않습니다. 하지만 다음과 같은 방법으로 연동이 가능합니다:

### 1. AWS CodeStar 커넥션 사용 (권장 방법)

AWS CodeStar 커넥션은 Bitbucket과 같은 타사 소스 코드 제공자와 AWS 개발자 도구를 연결하는 기능입니다.

#### 설정 단계:

1. **AWS 관리 콘솔에서 CodeStar 커넥션 생성**:
   - AWS 관리 콘솔에 로그인
   - Developer Tools > Settings > Connections로 이동
   - "Create connection" 클릭
   - 제공자로 "Bitbucket" 선택
   - 연결 이름 입력 후 "Connect to Bitbucket" 클릭
   - Bitbucket 계정으로 로그인하여 권한 부여

2. **CodePipeline에서 소스 단계 설정**:
   - CodePipeline 콘솔에서 파이프라인 생성 또는 편집
   - 소스 단계에서 "Source provider"로 "Bitbucket (CodeStar Connection)" 선택
   - 이전에 생성한 연결 선택
   - 리포지토리 이름과 브랜치 지정

```json
{
  "name": "Source",
  "actions": [
    {
      "name": "Source",
      "actionTypeId": {
        "category": "Source",
        "owner": "AWS",
        "provider": "CodeStarSourceConnection",
        "version": "1"
      },
      "configuration": {
        "ConnectionArn": "arn:aws:codestar-connections:region:account-id:connection/connection-id",
        "FullRepositoryId": "bitbucket-account/repository-name",
        "BranchName": "main"
      },
      "outputArtifacts": [
        {
          "name": "SourceCode"
        }
      ]
    }
  ]
}
```

### 2. AWS CodePipeline 웹훅 사용

Bitbucket 웹훅을 사용하여 코드 변경 시 AWS CodePipeline을 트리거할 수 있습니다.

#### 설정 단계:

1. **AWS CloudFormation 템플릿 생성**:
   - API Gateway와 Lambda 함수를 설정하여 Bitbucket 웹훅을 처리하는 CloudFormation 템플릿 생성
   - Lambda 함수는 CodePipeline을 트리거하는 역할 수행

2. **Bitbucket 웹훅 설정**:
   - Bitbucket 리포지토리 > Repository settings > Webhooks로 이동
   - "Add webhook" 클릭
   - URL에 API Gateway 엔드포인트 입력
   - 트리거할 이벤트 선택 (예: Repository push)
   - 웹훅 활성화

3. **Lambda 함수 코드 예시**:

```python
import boto3
import json
import os

def lambda_handler(event, context):
    # Bitbucket 웹훅 페이로드 파싱
    body = json.loads(event['body'])
    
    # 푸시된 브랜치 확인
    try:
        branch = body['push']['changes'][0]['new']['name']
        if branch != 'main':  # 원하는 브랜치만 트리거
            return {
                'statusCode': 200,
                'body': json.dumps('Branch not monitored')
            }
    except:
        return {
            'statusCode': 400,
            'body': json.dumps('Invalid webhook payload')
        }
    
    # CodePipeline 트리거
    pipeline_name = os.environ['PIPELINE_NAME']
    codepipeline = boto3.client('codepipeline')
    
    response = codepipeline.start_pipeline_execution(
        name=pipeline_name
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps('Pipeline started successfully')
    }
```

### 3. AWS CodeBuild와 Bitbucket 직접 연동

CodeBuild는 Bitbucket과 직접 연동이 가능하며, 이를 CodePipeline의 일부로 사용할 수 있습니다.

#### 설정 단계:

1. **CodeBuild 프로젝트 생성**:
   - AWS 관리 콘솔에서 CodeBuild로 이동
   - "Create build project" 클릭
   - 소스 제공자로 "Bitbucket" 선택
   - Bitbucket 계정 연결 및 리포지토리 선택
   - 웹훅 옵션 활성화 (코드 변경 시 자동 빌드)

2. **CodePipeline에서 CodeBuild 사용**:
   - CodePipeline에서 소스 단계를 S3로 설정
   - CodeBuild 프로젝트가 빌드 결과물을 S3에 업로드하도록 설정
   - CodePipeline이 S3의 결과물을 사용하여 배포 진행

## 실제 구현 예시: Bitbucket에서 ECS로 배포하는 파이프라인

### 1. 전체 아키텍처

```
Bitbucket Repository
      │
      ▼
AWS CodeStar Connection
      │
      ▼
AWS CodePipeline
      │
      ├─────────┬─────────┬─────────┐
      │         │         │         │
      ▼         ▼         ▼         ▼
   Source    Build     Deploy    Notify
 (Bitbucket) (CodeBuild) (ECS)  (SNS/Slack)
```

### 2. buildspec.yml 예시 (CodeBuild용)

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=${COMMIT_HASH:=latest}
  build:
    commands:
      - echo Build started on `date`
      - echo Building the Docker image...
      - docker build -t $ECR_REPOSITORY_URI:$IMAGE_TAG .
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $ECR_REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definitions file...
      - aws ecs describe-task-definition --task-definition $ECS_TASK_DEFINITION --query taskDefinition > taskdef.json
      - envsubst < container-definition-update.json > container-definition.json
      - jq --argfile container container-definition.json '.containerDefinitions[0] = $container' taskdef.json > taskdef-update.json
      - jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' taskdef-update.json > taskdef-new.json
      - aws ecs register-task-definition --cli-input-json file://taskdef-new.json
      - echo "{\"ImageURI\":\"$ECR_REPOSITORY_URI:$IMAGE_TAG\"}" > imageDefinition.json

artifacts:
  files:
    - imageDefinition.json
    - appspec.yaml
    - taskdef-new.json
```

### 3. appspec.yaml 예시 (CodeDeploy용)

```yaml
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: "my-container"
          ContainerPort: 80
```

### 4. CloudFormation 템플릿 예시 (CodePipeline 설정)

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Parameters:
  BitbucketConnectionArn:
    Type: String
    Description: ARN of the CodeStar connection to Bitbucket
  
  RepositoryName:
    Type: String
    Description: Bitbucket repository name (e.g. username/repo)
  
  BranchName:
    Type: String
    Default: main
    Description: Branch name to monitor for changes
  
  EcsClusterName:
    Type: String
    Description: Name of the ECS cluster
  
  EcsServiceName:
    Type: String
    Description: Name of the ECS service

Resources:
  ArtifactBucket:
    Type: AWS::S3::Bucket
    Properties:
      VersioningConfiguration:
        Status: Enabled

  CodeBuildServiceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codebuild.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/AmazonECR-FullAccess'
        - 'arn:aws:iam::aws:policy/AmazonECS-FullAccess'

  CodePipelineServiceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codepipeline.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - 'arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess'
        - 'arn:aws:iam::aws:policy/AmazonS3FullAccess'
        - 'arn:aws:iam::aws:policy/AmazonECS-FullAccess'

  CodeBuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Artifacts:
        Type: CODEPIPELINE
      Environment:
        Type: LINUX_CONTAINER
        ComputeType: BUILD_GENERAL1_SMALL
        Image: aws/codebuild/amazonlinux2-x86_64-standard:3.0
        PrivilegedMode: true
        EnvironmentVariables:
          - Name: ECR_REPOSITORY_URI
            Value: !Sub ${AWS::AccountId}.dkr.ecr.${AWS::Region}.amazonaws.com/my-repository
          - Name: ECS_TASK_DEFINITION
            Value: my-task-definition
      ServiceRole: !GetAtt CodeBuildServiceRole.Arn
      Source:
        Type: CODEPIPELINE
        BuildSpec: buildspec.yml

  Pipeline:
    Type: AWS::CodePipeline::Pipeline
    Properties:
      RoleArn: !GetAtt CodePipelineServiceRole.Arn
      ArtifactStore:
        Type: S3
        Location: !Ref ArtifactBucket
      Stages:
        - Name: Source
          Actions:
            - Name: Source
              ActionTypeId:
                Category: Source
                Owner: AWS
                Provider: CodeStarSourceConnection
                Version: '1'
              Configuration:
                ConnectionArn: !Ref BitbucketConnectionArn
                FullRepositoryId: !Ref RepositoryName
                BranchName: !Ref BranchName
              OutputArtifacts:
                - Name: SourceCode
        
        - Name: Build
          Actions:
            - Name: BuildAndPushImage
              ActionTypeId:
                Category: Build
                Owner: AWS
                Provider: CodeBuild
                Version: '1'
              Configuration:
                ProjectName: !Ref CodeBuildProject
              InputArtifacts:
                - Name: SourceCode
              OutputArtifacts:
                - Name: BuildOutput
        
        - Name: Deploy
          Actions:
            - Name: DeployToECS
              ActionTypeId:
                Category: Deploy
                Owner: AWS
                Provider: ECS
                Version: '1'
              Configuration:
                ClusterName: !Ref EcsClusterName
                ServiceName: !Ref EcsServiceName
                FileName: imageDefinition.json
              InputArtifacts:
                - Name: BuildOutput
```

## Bitbucket 파이프라인을 사용한 대안

AWS CodePipeline 대신 Bitbucket Pipelines을 사용하여 ECS에 직접 배포할 수도 있습니다.

### bitbucket-pipelines.yml 예시:

```yaml
image: atlassian/default-image:3

pipelines:
  branches:
    main:
      - step:
          name: Build and Push to ECR
          services:
            - docker
          script:
            - apt-get update && apt-get install -y python3-pip jq
            - pip3 install awscli
            - aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            - aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            - aws configure set region $AWS_DEFAULT_REGION
            - aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REPOSITORY_URI
            - docker build -t $ECR_REPOSITORY_URI:$BITBUCKET_COMMIT .
            - docker push $ECR_REPOSITORY_URI:$BITBUCKET_COMMIT
      - step:
          name: Deploy to ECS
          script:
            - apt-get update && apt-get install -y python3-pip jq
            - pip3 install awscli
            - aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            - aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            - aws configure set region $AWS_DEFAULT_REGION
            - aws ecs update-service --cluster $ECS_CLUSTER --service $ECS_SERVICE --force-new-deployment
```

## 보안 고려사항

1. **IAM 권한**: AWS 서비스에 접근하기 위한 최소 권한 원칙 적용
2. **비밀 관리**: Bitbucket 리포지토리 설정에서 환경 변수로 AWS 자격 증명 저장
3. **연결 권한**: CodeStar 연결에는 필요한 최소 권한만 부여

## 모범 사례

1. **브랜치 기반 배포**: 개발, 스테이징, 프로덕션 환경에 대한 별도의 브랜치와 파이프라인 구성
2. **배포 승인**: 프로덕션 배포 전 수동 승인 단계 추가
3. **알림 설정**: Slack 또는 이메일을 통한 배포 상태 알림 구성
4. **롤백 전략**: 배포 실패 시 자동 롤백 메커니즘 구현

## 결론

Bitbucket을 소스 코드 저장소로 사용하면서 AWS CodePipeline을 통해 ECS에 자동 배포하는 방법은 여러 가지가 있습니다. AWS CodeStar 커넥션을 사용하는 방법이 가장 간단하고 권장되는 방법이지만, 웹훅이나 CodeBuild 직접 연동 방식도 상황에 따라 유용할 수 있습니다. 또는 Bitbucket Pipelines을 사용하여 AWS 서비스에 직접 배포하는 방법도 고려할 수 있습니다. 프로젝트의 요구사항과 팀의 선호도에 따라 적절한 방법을 선택하면 됩니다.
