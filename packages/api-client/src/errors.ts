export type ApiFailure = {
  code?: string;
  error?: string;
  retryable?: boolean;
  requestId?: string;
  retryAfter?: number;
};

export class ApiRequestError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  readonly requestId?: string;
  readonly retryAfter?: number;
  constructor(failure: ApiFailure) {
    super(failure.error ?? '처리 결과를 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.');
    this.name = 'ApiRequestError';
    this.code = failure.code ?? 'REQUEST_FAILED';
    this.retryable = failure.retryable ?? true;
    this.requestId = failure.requestId;
    this.retryAfter = failure.retryAfter;
  }
}

const messages = {
  INVALID_REQUEST: '입력 내용을 확인해 주세요.',
  AUTH_REQUIRED: '로그인이 필요합니다. 다시 로그인해 주세요.',
  AUTH_CALLBACK_INVALID: '로그인을 확인하지 못했습니다. 확인 링크가 만료되었을 수 있습니다. 다시 로그인하거나 확인 메일을 새로 받아 주세요.',
  FORBIDDEN: '이 작업을 수행할 권한이 없습니다.',
  NOT_FOUND: '요청한 정보를 찾을 수 없습니다. 목록에서 다시 선택해 주세요.',
  METHOD_NOT_ALLOWED: '지원하지 않는 요청입니다. 화면을 새로 연 뒤 다시 시도해 주세요.',
  STATE_CONFLICT: '거래 상태가 변경되었습니다. 최신 상태를 확인해 주세요.',
  PAYMENT_REVIEW_REQUIRED: '자동 처리가 멈춰 운영 확인이 필요합니다. 중복 결제하거나 물품을 전달하지 말고 거래 내역을 확인해 주세요.',
  PAYLOAD_TOO_LARGE: '사진 또는 입력 내용의 용량을 줄여 주세요.',
  UNSUPPORTED_MEDIA: '지원하지 않는 사진 형식입니다. JPG, PNG, WebP 사진을 선택해 주세요.',
  RATE_LIMITED: '요청이 많아 잠시 기다려야 합니다. 잠시 후 다시 시도해 주세요.',
  INTERNAL_ERROR: '오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
  UPSTREAM_UNAVAILABLE: '외부 서비스의 응답을 확인하지 못했습니다. 잠시 후 처리 결과를 다시 확인해 주세요.',
  SERVICE_UNAVAILABLE: '서비스를 일시적으로 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
  REQUEST_TIMEOUT: '응답이 지연되고 있습니다. 중복 요청하기 전에 처리 결과를 다시 확인해 주세요.',
  RENTAL_REQUEST_STORAGE_CORRUPT: '저장된 예약 요청을 확인하지 못했습니다. 중복 예약을 막기 위해 새 요청을 중지했습니다. 거래 내역을 확인한 뒤 고객 지원에 문의해 주세요.',
  RENTAL_REQUEST_IN_PROGRESS: '다른 화면에서 예약 요청을 처리하고 있습니다. 잠시 후 거래 내역을 확인해 주세요.',
  RENTAL_REQUEST_LOCK_UNAVAILABLE: '이 브라우저에서 예약 요청을 안전하게 저장할 수 없습니다. 최신 브라우저를 이용해 주세요.',
  invalid_credentials: '이메일 또는 비밀번호를 확인해 주세요.',
  email_not_confirmed: '이메일 확인이 필요합니다. 받은 메일의 링크로 가입을 확인해 주세요.',
  user_already_exists: '가입 정보를 확인해 주세요. 이미 계정이 있다면 로그인해 주세요.',
  email_exists: '가입 정보를 확인해 주세요. 이미 계정이 있다면 로그인해 주세요.',
  weak_password: '더 안전한 비밀번호를 사용해 주세요. 길이와 문자 구성을 확인해 주세요.',
  otp_expired: '인증번호 또는 확인 링크가 올바르지 않거나 만료되었습니다. 새 번호나 확인 메일을 받아 주세요.',
  over_request_rate_limit: '요청이 많아 잠시 기다려야 합니다. 잠시 후 다시 시도해 주세요.',
  over_email_send_rate_limit: '메일 요청이 많습니다. 잠시 기다린 뒤 다시 받아 주세요.',
  over_sms_send_rate_limit: '인증번호 요청이 많습니다. 잠시 기다린 뒤 다시 받아 주세요.',
  signup_disabled: '지금은 가입을 진행할 수 없습니다. 잠시 후 다시 시도해 주세요.',
  email_provider_disabled: '지금은 이메일 로그인을 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.',
  refresh_token_not_found: '로그인이 필요합니다. 다시 로그인해 주세요.',
  refresh_token_already_used: '로그인이 만료되었습니다. 다시 로그인해 주세요.',
  session_not_found: '로그인이 만료되었습니다. 다시 로그인해 주세요.',
  '23P01': '이미 예약된 기간입니다. 다른 기간을 선택해 주세요.',
  '23505': '이미 처리된 요청이거나 중복된 정보입니다. 최신 상태를 확인해 주세요.',
  '42501': '이 작업을 수행할 권한이 없습니다.',
  PDR01: '자동 처리가 멈춰 운영 확인이 필요합니다. 중복 결제하거나 물품을 전달하지 말고 거래 내역을 확인해 주세요.',
  PGRST116: '요청한 정보를 찾을 수 없습니다. 목록에서 다시 선택해 주세요.',
  PGRST301: '로그인이 만료되었습니다. 다시 로그인해 주세요.',
} as const;

// Transitional allowlist for app-owned errors that predate typed error codes.
// Exact matching preserves recovery instructions without trusting SDK messages.
const localMessages = new Map([
  '날짜와 시간을 YYYY-MM-DD HH:mm 형식으로 입력해 주세요.',
  '실제 존재하는 날짜와 시간을 입력해 주세요.',
  '예약 결과를 확인하지 못했습니다. 같은 요청으로 재시도해 주세요.',
  '결제 처리 상태를 확인하지 못했습니다.',
  '인수를 확인하지 못했습니다.',
  '반납 사진을 불러오지 못했습니다.',
  '반납 사진을 먼저 선택해 주세요.',
  '사진을 읽지 못했습니다.',
  '등록한 물품을 확인하지 못했습니다.',
  '결제 정보를 확인하지 못했습니다.',
  '결제 링크를 확인할 수 없습니다. 거래 상세에서 결제 결과를 확인하거나 결제를 시작해 주세요.',
  '결제가 완료되지 않았습니다. 다시 결제하거나 거래로 돌아갈 수 있습니다.',
  '결제 정보를 불러오지 못했습니다. 거래 상세에서 결과를 확인해 주세요.',
  '지금은 결제를 시작할 수 없습니다. 잠시 후 거래 상세에서 다시 시도해 주세요.',
  '결제가 완료되지 않았습니다. 다시 시도하거나 거래로 돌아가 주세요.',
  '물품을 찾을 수 없습니다.',
  '저장된 요청을 확인하고 있습니다.',
  '상품을 다시 확인해 주세요.',
  '5MB 이하의 JPG, PNG, WebP 사진을 선택해 주세요.',
  '5MB 이하 JPG, PNG, WebP 사진을 선택해 주세요.',
  '5MB 이하 사진을 선택해 주세요.',
  'JPG, PNG, WebP 사진을 선택해 주세요.',
].map(message => [message, message] as const));

/** Only this app-owned catalogue crosses either platform's error UI boundary. */
export function errorMessage(error: unknown): string {
  const value = error && typeof error === 'object' ? error as {code?: unknown; message?: unknown; name?: unknown} : {};
  const code = typeof value.code === 'string' ? value.code : '';
  if (Object.hasOwn(messages, code)) return messages[code as keyof typeof messages];
  const message = typeof value.message === 'string' ? value.message : typeof error === 'string' ? error : '';
  const localMessage = localMessages.get(message);
  if (localMessage) return localMessage;
  if (/KeyChain|SecureStore|getValueWithKeyAsync|entitlement/i.test(message))
    return '로그인 정보를 불러오지 못했습니다. 앱을 다시 실행해 주세요.';
  if (value.name === 'TimeoutError' || value.name === 'AbortError') return messages.REQUEST_TIMEOUT;
  if (/network|fetch failed|failed to fetch|internet|timed? ?out|네트워크/i.test(message))
    return '연결이 원활하지 않습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
  if (/token has expired|invalid otp/i.test(message)) return messages.otp_expired;
  if (/rate limit|too many requests/i.test(message)) return messages.RATE_LIMITED;
  if (/같은 기간에 이미 수락된 예약/.test(message)) return messages['23P01'];
  if (/로그인이 필요|jwt expired|session.*expired/i.test(message)) return messages.AUTH_REQUIRED;
  return messages.INTERNAL_ERROR;
}

/** Never echo an arbitrary requestId supplied by a server or URL. */
export function errorRequestId(error: unknown): string | undefined {
  if (!error || typeof error !== 'object' || !('requestId' in error)) return;
  const requestId = error.requestId;
  if (typeof requestId === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(requestId)) return requestId;
}
