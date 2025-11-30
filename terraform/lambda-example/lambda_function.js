/**
 * AWS Lambda 함수 핸들러
 * 
 * AWS Lambda에서 자동으로 호출하는 함수입니다.
 * event 파라미터는 Lambda 호출 시 전달되는 데이터를 포함합니다.
 * API Gateway를 통해 호출되는 경우 HTTP 요청 정보가 포함됩니다.
 * 
 * @param {Object} event - Lambda 호출 이벤트 데이터
 * @returns {Object} API Gateway에 대한 HTTP 응답 객체
 */
exports.handler = async (event) => {
  // 이벤트 로깅 - CloudWatch Logs에 기록됨
  console.log('Event: ', JSON.stringify(event, null, 2));
  
  // API Gateway에 대한 응답 객체 생성
  const response = {
    statusCode: 200,                      // HTTP 상태 코드 (200: 성공)
    headers: {
      'Content-Type': 'application/json', // 응답 컨텐츠 타입
    },
    body: JSON.stringify({                // 응답 본문 (JSON 문자열로 변환)
      message: 'Hello from Lambda!',      // 응답 메시지
      timestamp: new Date().toISOString(), // 현재 시간 (ISO 형식)
      event: event,                      // 입력된 이벤트 데이터 그대로 반환
    }),
  };
  
  // 응답 반환
  return response;
};
