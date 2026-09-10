/** Only app-owned copy crosses the UI boundary. Never render server/SDK messages. */
export function errorMessage(error: unknown): string {
  const value = error && typeof error === 'object' ? error as {code?: unknown; message?: unknown} : {};
  const code = typeof value.code === 'string' ? value.code : '';
  const message = typeof value.message === 'string' ? value.message : typeof error === 'string' ? error : '';
  if (/KeyChain|SecureStore|getValueWithKeyAsync|entitlement/i.test(message))
    return '로그인 정보를 불러오지 못했습니다. 앱을 다시 실행해 주세요.';
  if (/network|fetch failed|failed to fetch|internet|timed? ?out|네트워크/i.test(message))
    return '연결이 원활하지 않습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
  if (code === 'otp_expired' || /token has expired|invalid otp/i.test(message))
    return '인증번호가 올바르지 않거나 만료되었습니다. 새 번호를 받아 다시 입력해 주세요.';
  if (code === 'over_request_rate_limit' || /rate limit|too many requests/i.test(message))
    return '요청이 많아 잠시 기다려야 합니다. 잠시 후 다시 시도해 주세요.';
  if (code === '23P01' || /같은 기간에 이미 수락된 예약/.test(message))
    return '이미 예약된 기간입니다. 다른 기간을 선택해 주세요.';
  if (code === 'PGRST116') return '요청한 정보를 찾을 수 없습니다. 목록에서 다시 선택해 주세요.';
  if (code === 'refresh_token_not_found' || /로그인이 필요|jwt expired|session.*expired/i.test(message))
    return '로그인이 필요합니다. 다시 로그인해 주세요.';
  return '오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
}
