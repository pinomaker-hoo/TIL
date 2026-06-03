# RAG (검색 증강 생성)

## 개요

RAG(Retrieval-Augmented Generation)에 대해 학습한다. LLM이 모르는 정보를 답할 수 있게 만드는 가장 일반적인 방법이다. 동작 원리, 구성 요소, 간단한 예제 코드, 흔한 함정까지 다룬다.

> 사전 지식이 필요하다면 [AI 입문 문서](./index.md)를 먼저 읽는 것을 권장한다.

<br />

---

## 1. RAG란 무엇인가

RAG는 **Retrieval-Augmented Generation**의 약자로, "검색으로 보강한 생성"이라는 뜻이다. LLM이 답을 만들기 전에 **외부 자료를 검색**해서 그 내용을 참고해 답하게 하는 기법이다.

> 비유: **오픈북 시험을 보는 학생**. 학생(LLM)이 자기 머릿속 지식만으로 답하는 게 아니라, 시험장에 가져온 책(외부 문서)에서 관련 부분을 찾아 보고 답을 작성한다.

```
일반 LLM:    질문 → LLM → 답변 (학습된 지식만 사용)
RAG:        질문 → 검색 → 관련 문서 + 질문 → LLM → 답변
                  ↑
              외부 자료(사내 위키, PDF 등)
```

<br />

## 2. 왜 필요한가

LLM의 세 가지 한계를 동시에 해결한다.

| LLM의 한계 | RAG가 해결하는 방식 |
| --- | --- |
| 학습 시점 이후 정보를 모름 | 최신 문서를 검색해서 프롬프트에 넣음 |
| 사내/도메인 정보를 모름 | 사내 위키, PDF, DB를 검색해서 넣음 |
| 환각(Hallucination) 발생 | 실제 검색된 출처를 근거로 답하게 유도 |

또한 **답변의 출처(어느 문서에서 가져왔는지)를 제시할 수 있다**는 점이 큰 장점이다.

<br />

## 3. RAG 동작 흐름

RAG는 두 단계로 나뉜다. **사전 준비 단계**(인덱싱)와 **질문 처리 단계**(검색 + 생성)이다.

### (1) 사전 준비 단계 — Indexing

문서를 미리 벡터 DB에 저장해두는 과정이다.

```
[사전 준비]

  원본 문서 (PDF/Word/MD/HTML 등)
        │
        ▼
   ① 문서 로딩
        │
        ▼
   ② 청크 분할 (Chunking)
      → 긴 문서를 작은 조각으로 자름
        │
        ▼
   ③ 임베딩 생성 (각 청크를 벡터로 변환)
        │
        ▼
   ④ 벡터 DB에 저장
      [청크 텍스트 + 벡터 + 메타데이터]
```

### (2) 질문 처리 단계 — Retrieval + Generation

실제 사용자 질문이 들어왔을 때의 흐름이다.

```
[질문 시]

  사용자 질문
       │
       ▼
  ⑤ 질문을 임베딩으로 변환
       │
       ▼
  ⑥ 벡터 DB에서 유사한 청크 검색 (Top-K)
       │
       ▼
  ⑦ 검색 결과 + 질문을 프롬프트로 조립
       │
       ▼
  ⑧ LLM에 전달 → 답변 생성
       │
       ▼
   최종 답변 (+ 출처 표시 가능)
```

<br />

## 4. 핵심 구성 요소

### (1) 문서 로더 (Document Loader)

다양한 형식의 원본 문서를 텍스트로 읽어들이는 역할이다.

| 형식 | 도구 예시 |
| --- | --- |
| PDF | PyPDFLoader, pdf-parse |
| HTML | BeautifulSoup, cheerio |
| Markdown | UnstructuredMarkdownLoader |
| Notion / Confluence | 공식 API 기반 로더 |
| DB | SQL 쿼리 결과 → 텍스트 |

<br />

### (2) 청킹 (Chunking)

긴 문서를 작은 조각(청크)으로 자르는 작업이다. RAG 품질에 **가장 큰 영향을 미치는 단계**이다.

**왜 자르는가?**

- LLM의 컨텍스트 윈도우에는 한계가 있어 한 번에 모든 문서를 못 넣음
- 검색 정확도가 올라감 (질문과 관련된 짧은 조각만 가져옴)
- 임베딩은 짧은 텍스트일수록 의미를 잘 표현함

**청크 크기 선택**

| 청크 크기 | 장단점 |
| --- | --- |
| 너무 작음 (100자) | 맥락이 끊겨 답이 부정확함 |
| 너무 큼 (5000자) | 노이즈가 많아 검색 정확도 하락 |
| **권장 (500~1500자)** | 일반적인 균형점 |

청크끼리 약간 겹치게(Overlap, 보통 10~20%) 자르는 것이 좋다. 문장이 잘리는 문제를 줄여준다.

<br />

### (3) 임베딩 모델

텍스트를 벡터로 변환하는 모델이다.

| 모델 | 제공사 | 특징 |
| --- | --- | --- |
| text-embedding-3-small | OpenAI | 저렴하고 빠름. 기본값으로 좋음 |
| text-embedding-3-large | OpenAI | 더 정확하지만 비쌈 |
| Cohere embed-multilingual | Cohere | 다국어 강점 |
| ko-sroberta-multitask | 오픈소스 | 한국어 특화 |
| bge-m3 | 오픈소스 | 다국어 + 무료, 로컬 호스팅 가능 |

**주의:** 인덱싱 단계와 질문 단계에서 **같은 임베딩 모델**을 사용해야 한다. 다른 모델을 쓰면 좌표계가 달라져 검색이 동작하지 않는다.

<br />

### (4) 벡터 DB

벡터를 저장하고 유사도 기반으로 검색하는 DB이다.

| 벡터 DB | 특징 |
| --- | --- |
| Pinecone | 완전 매니지드. 운영 부담 없음 |
| Chroma | 로컬 개발/소규모 프로젝트에 좋음 |
| Weaviate | 오픈소스 + 매니지드 둘 다 제공 |
| Qdrant | 빠르고 가벼움, 자체 호스팅 |
| pgvector | PostgreSQL 확장. 기존 DB에 그대로 추가 |

> 처음 시작할 때는 **pgvector**나 **Chroma**가 가장 진입장벽이 낮다.

<br />

### (5) LLM

최종 답변을 만드는 생성 모델이다. GPT, Claude, Gemini 등 어떤 LLM이든 RAG의 "생성" 단계에 쓸 수 있다.

<br />

## 5. 간단한 예제 코드

> 실제 동작하는 완성본이 아니라 흐름을 보여주는 의사코드이다.

### (1) Python — LangChain

```python
from langchain_community.document_loaders import PyPDFLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import Chroma

# ── 사전 준비 단계 ──
docs = PyPDFLoader("manual.pdf").load()
chunks = RecursiveCharacterTextSplitter(
    chunk_size=1000, chunk_overlap=200
).split_documents(docs)

vectorstore = Chroma.from_documents(
    chunks, OpenAIEmbeddings(model="text-embedding-3-small")
)

# ── 질문 처리 단계 ──
question = "환불 정책이 어떻게 되나요?"
related = vectorstore.similarity_search(question, k=3)

prompt = f"""아래 문서를 참고해 답하세요.
[문서]
{[c.page_content for c in related]}

[질문]
{question}
"""
answer = ChatOpenAI(model="gpt-4o").invoke(prompt)
print(answer.content)
```

### (2) Node.js — LangChain.js

```typescript
import { PDFLoader } from "@langchain/community/document_loaders/fs/pdf"
import { RecursiveCharacterTextSplitter } from "langchain/text_splitter"
import { OpenAIEmbeddings, ChatOpenAI } from "@langchain/openai"
import { Chroma } from "@langchain/community/vectorstores/chroma"

// ── 사전 준비 단계 ──
const docs = await new PDFLoader("manual.pdf").load()
const chunks = await new RecursiveCharacterTextSplitter({
  chunkSize: 1000,
  chunkOverlap: 200,
}).splitDocuments(docs)

const vectorstore = await Chroma.fromDocuments(
  chunks,
  new OpenAIEmbeddings({ model: "text-embedding-3-small" }),
)

// ── 질문 처리 단계 ──
const question = "환불 정책이 어떻게 되나요?"
const related = await vectorstore.similaritySearch(question, 3)

const prompt = `아래 문서를 참고해 답하세요.
[문서]
${related.map((d) => d.pageContent).join("\n")}

[질문]
${question}`

const answer = await new ChatOpenAI({ model: "gpt-4o" }).invoke(prompt)
console.log(answer.content)
```

두 코드의 흐름은 동일하다. **로드 → 청킹 → 임베딩 + 저장 → 검색 → 프롬프트 조립 → LLM 호출**이라는 RAG의 기본 패턴을 따른다.

<br />

## 6. 흔히 마주치는 문제

### (1) 검색 결과가 엉뚱하다

원인은 보통 다음 셋 중 하나이다.

- 청크 크기가 부적절함 (너무 작거나 너무 큼)
- 한국어 문서인데 영어 위주 임베딩 모델을 씀 → 한국어 친화 모델로 교체
- 질문과 문서의 어휘가 다름 → **하이브리드 검색**(키워드 검색 + 벡터 검색) 도입 고려

<br />

### (2) Garbage In, Garbage Out

검색된 청크가 부정확하면 LLM도 그걸 근거로 잘못된 답을 만든다. **검색 품질이 RAG 품질을 결정한다.**

대응:
- 검색 결과를 한 번 더 LLM으로 **재순위(Re-ranking)** 시킴
- Top-K를 늘려 후보를 많이 뽑고 그 중 추리기

<br />

### (3) 컨텍스트 윈도우 초과

검색된 청크를 모두 프롬프트에 넣다 보면 토큰 한계를 넘기기 쉽다. 청크 수 제한과 압축(summarization)을 병행한다.

<br />

### (4) 출처 표시 누락

답변에 어느 문서에서 가져왔는지 표시하지 않으면 RAG의 큰 장점을 살리지 못한다. 청크에 **메타데이터(파일명, 페이지 번호)** 를 같이 저장하고 프롬프트에 포함시켜 표기하도록 유도한다.

<br />

## 7. 사용 사례

| 사례 | 설명 |
| --- | --- |
| 사내 문서 챗봇 | Notion/Confluence를 임베딩해서 "휴가 정책은?" 같은 질문에 응답 |
| 고객지원 봇 | 매뉴얼, FAQ를 인덱싱해서 1차 문의 자동 응답 |
| 코드베이스 Q&A | 사내 레포지토리를 인덱싱해서 코드 위치/사용법 검색 |
| 법률/의료 어시스턴트 | 법령/의학 자료에서 출처와 함께 답변 |
| 영업 자료 검색 | 영업팀이 과거 제안서, 계약서에서 빠르게 정보 찾기 |

<br />

## 8. 요약

- RAG = **검색 + 생성**의 결합
- 핵심 흐름: 문서 → 청킹 → 임베딩 → 벡터 DB → 검색 → 프롬프트 조립 → LLM
- 청킹과 임베딩 모델 선택이 품질의 80%를 좌우한다
- 파인튜닝과의 비교는 [의사결정 가이드](./rag-vs-fine-tuning.md)를 참고한다
