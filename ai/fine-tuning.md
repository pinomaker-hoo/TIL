# 파인튜닝 (Fine-tuning)

## 개요

파인튜닝(Fine-tuning)에 대해 학습한다. 사전학습된 LLM을 특정 도메인이나 목적에 맞게 **추가 학습**시키는 기법이다. 개념, 동작 흐름, 종류(LoRA/QLoRA), 비용과 한계, 그리고 언제 쓰지 말아야 하는지까지 정리한다.

> 사전 지식이 필요하다면 [AI 입문 문서](./index.md)를 먼저 읽는 것을 권장한다.

<br />

---

## 1. 파인튜닝이란 무엇인가

이미 학습된 LLM에 **추가 데이터를 더 학습시켜** 모델의 동작을 우리 목적에 맞게 바꾸는 작업이다.

> 비유: **일반 의사를 외과 전문의로 추가 교육시키는 것**. 이미 의학 전반(LLM 사전학습)을 알고 있는 사람에게, 외과 수술 사례(파인튜닝 데이터)를 집중적으로 보여주어 외과 전문가로 만든다.

```
[일반 LLM]                  [파인튜닝된 LLM]
  ↑                              ↑
  사전학습                       사전학습 + 추가 학습
  (인터넷 텍스트)                (인터넷 텍스트 + 우리 데이터)
```

<br />

## 2. 왜 필요한가

프롬프트만으로는 해결하기 어려운 다음 경우에 사용한다.

### (1) 일관된 출력 형식

매번 정해진 JSON 스키마나 보고서 양식으로 답하게 하고 싶을 때.

```
입력: "회원가입 요청"
출력: {"intent":"signup","fields":["email","password"]}
```

수백 개의 예시를 보여주면 모델이 형식을 학습한다.

<br />

### (2) 도메인 말투/톤앤매너

법률 자문 문서 톤, 의료 진단 보고서 톤, 사내 고객지원 톤처럼 **일관된 말투**를 학습시킬 때.

<br />

### (3) 프롬프트로 안 되는 반복 패턴

특정 분류, 추출, 변환 작업을 매번 길게 프롬프트로 설명하기 어려울 때. 파인튜닝하면 프롬프트가 짧아지고 추론 비용이 줄어든다.

<br />

## 3. 동작 흐름

```
   ┌─────────────────────┐
   │  사전학습된 모델     │   (예: Llama 3, GPT-4o-mini)
   │  (Base Model)       │
   └──────────┬──────────┘
              │
              │  +  학습 데이터셋
              │     (질문/답변 쌍 수백~수천 건)
              │
              ▼
        ┌──────────┐
        │  학습    │   (GPU 사용, 시간/비용 발생)
        └─────┬────┘
              │
              ▼
   ┌─────────────────────┐
   │  파인튜닝된 모델     │   (Fine-tuned Model)
   │  (우리 전용)         │
   └─────────────────────┘
```

<br />

## 4. 학습 데이터 형식

대부분의 파인튜닝 플랫폼은 **JSONL 형식**(한 줄에 하나의 학습 예시)을 쓴다.

### OpenAI / 일반적인 채팅 형식

```json
{"messages":[{"role":"system","content":"너는 우리 회사 CS 봇이다."},{"role":"user","content":"환불 가능한가요?"},{"role":"assistant","content":"네, 수령 후 7일 이내 환불 가능합니다."}]}
{"messages":[{"role":"system","content":"너는 우리 회사 CS 봇이다."},{"role":"user","content":"배송 얼마나 걸리나요?"},{"role":"assistant","content":"평일 기준 2~3일 소요됩니다."}]}
```

> 데이터 수집과 정제가 **파인튜닝에서 가장 어렵고 시간이 오래 걸리는 단계**이다.

<br />

## 5. 파인튜닝의 종류

### (1) Full Fine-tuning

모델의 **모든 파라미터를 다시 학습**시키는 방식이다.

- 장점: 가장 강력한 학습 효과
- 단점: GPU 메모리와 비용이 매우 많이 듦, 시간 오래 걸림
- 7B 모델 기준 수백 GB의 GPU 메모리가 필요할 수 있음

<br />

### (2) LoRA (Low-Rank Adaptation)

**일부 작은 행렬만 추가로 학습**시키는 효율적인 방법이다. 원본 모델은 그대로 두고 작은 "어댑터" 가중치만 학습한다.

- 장점: 메모리/비용이 Full FT의 1/10 이하, 학습 빠름
- 단점: 극단적으로 큰 변화를 주기는 어려움
- **현재 파인튜닝의 사실상 표준**

<br />

### (3) QLoRA

LoRA + **양자화(Quantization)** 를 결합해 메모리를 더 줄인 방법이다. 모델 가중치를 4비트로 압축해 저장한다.

- 장점: 7B 모델을 노트북 GPU 한 장으로도 학습 가능한 수준까지 가벼워짐
- 단점: 약간의 정확도 손실 가능

<br />

### (4) PEFT (Parameter-Efficient Fine-Tuning)

LoRA, Prefix Tuning 등을 포함하는 **상위 개념**이다. Hugging Face의 `peft` 라이브러리가 표준처럼 쓰인다.

<br />

### 비교표

| 방식 | 학습 파라미터 | GPU 메모리 | 학습 속도 | 효과 |
| --- | --- | --- | --- | --- |
| Full Fine-tuning | 100% | 매우 많음 | 느림 | 매우 강함 |
| LoRA | 0.1~1% | 보통 | 빠름 | 강함 |
| QLoRA | 0.1~1% | 적음 | 빠름 | 강함 |

> 입문자는 일단 **"LoRA"라는 단어만 기억해도 충분**하다. 대부분의 파인튜닝 가이드는 LoRA 기준이다.

<br />

## 6. 간단한 예제

### (1) OpenAI Fine-tuning API — 가장 쉬운 방법

```python
from openai import OpenAI
client = OpenAI()

# ① 학습 데이터 업로드
file = client.files.create(
    file=open("train.jsonl", "rb"),
    purpose="fine-tune",
)

# ② 학습 시작
job = client.fine_tuning.jobs.create(
    training_file=file.id,
    model="gpt-4o-mini-2024-07-18",
)

# ③ 학습 완료 후 새 모델 ID로 호출
# job.fine_tuned_model 예: "ft:gpt-4o-mini:my-org:custom:abc123"
```

GPU 관리, 환경 설정이 전혀 필요 없다. 비용은 토큰 단위로 과금된다.

<br />

### (2) Hugging Face PEFT — 직접 LoRA 학습

```python
from transformers import AutoModelForCausalLM, AutoTokenizer
from peft import LoraConfig, get_peft_model
from datasets import load_dataset

# ① 베이스 모델 로드
model = AutoModelForCausalLM.from_pretrained("meta-llama/Llama-3-8B")
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3-8B")

# ② LoRA 설정 — 어댑터만 학습
lora_config = LoraConfig(r=8, lora_alpha=16, target_modules=["q_proj", "v_proj"])
model = get_peft_model(model, lora_config)

# ③ 데이터셋 로드 후 Trainer로 학습
dataset = load_dataset("json", data_files="train.jsonl")
# ... Trainer 설정 후 model.train()

# ④ 어댑터 저장 (베이스 모델과 별도)
model.save_pretrained("./my-lora-adapter")
```

자체 GPU나 클라우드 GPU(예: AWS, GCP, Runpod)가 필요하다.

<br />

## 7. 파인튜닝의 비용과 어려움

### (1) 학습 데이터가 가장 어렵다

좋은 학습 데이터셋을 만드는 게 **전체 작업의 80% 이상**이다.

- 수백~수천 건의 고품질 질문/답변 쌍이 필요
- 형식이 일관되어야 함
- 잘못된 데이터가 섞이면 모델이 그걸 그대로 배움 (Garbage In, Garbage Out)

<br />

### (2) GPU 비용

- Full Fine-tuning: 큰 모델은 수백~수천 달러 수준
- LoRA/QLoRA: 수십 달러 수준으로 낮출 수 있음
- OpenAI 같은 API: 토큰당 과금, 관리 부담 없음

<br />

### (3) 데이터가 바뀌면 다시 학습해야 한다

새 정보가 추가될 때마다 재학습이 필요하다. **자주 갱신되는 정보에는 부적합**하다.

<br />

### (4) 평가가 어렵다

파인튜닝이 잘 됐는지 객관적으로 평가하기 까다롭다. 별도의 평가 데이터셋과 지표가 필요하다.

<br />

## 8. 언제 쓰지 말아야 하는가

다음 경우에는 파인튜닝보다 다른 방법을 먼저 검토한다.

| 상황 | 더 나은 방법 |
| --- | --- |
| 자주 바뀌는 정보를 답해야 함 | **RAG** |
| 사내 문서/매뉴얼을 참고해 답해야 함 | **RAG** |
| 학습 데이터가 100건 미만 | **프롬프트 엔지니어링** |
| 한 번만 쓰고 말 작업 | **프롬프트 엔지니어링** |
| 출처를 명시해야 함 | **RAG** |

> 흔한 오해: "파인튜닝하면 새 지식이 모델에 들어간다."
> → **부정확하다.** 파인튜닝은 "말투/형식/패턴"을 배우는 데 강하고, "사실 지식 주입"에는 약하다. 지식 주입은 **RAG**가 훨씬 효과적이다.

<br />

## 9. 요약

- 파인튜닝 = 사전학습된 모델에 **추가 학습**을 시켜 동작을 바꾸는 작업
- 입문자가 알아야 할 것: **LoRA**가 표준
- 잘하는 것: 일관된 형식, 도메인 말투, 반복 패턴 학습
- 못하는 것: 최신 지식, 자주 바뀌는 정보, 적은 데이터로 학습
- 데이터 준비가 가장 어려운 단계
- RAG와의 선택 기준은 [의사결정 가이드](./rag-vs-fine-tuning.md)를 참고한다
