const definitions = {
  INVALID_REQUEST: [400, "입력 내용을 확인해 주세요.", false],
  AUTH_REQUIRED: [401, "로그인이 필요합니다. 다시 로그인해 주세요.", false],
  FORBIDDEN: [403, "이 작업을 수행할 권한이 없습니다.", false],
  NOT_FOUND: [404, "요청한 정보를 찾을 수 없습니다.", false],
  METHOD_NOT_ALLOWED: [405, "지원하지 않는 요청입니다.", false],
  STATE_CONFLICT: [
    409,
    "거래 상태가 변경되었습니다. 최신 상태를 확인해 주세요.",
    false,
  ],
  PAYMENT_REVIEW_REQUIRED: [
    409,
    "결제 처리 결과를 확인 중입니다. 중복 결제를 하지 말고 거래 내역을 확인해 주세요.",
    false,
  ],
  PAYLOAD_TOO_LARGE: [413, "사진 또는 입력 내용의 용량을 줄여 주세요.", false],
  UNSUPPORTED_MEDIA: [415, "지원하지 않는 사진 형식입니다.", false],
  RATE_LIMITED: [429, "요청이 많습니다. 잠시 후 다시 시도해 주세요.", true],
  INTERNAL_ERROR: [
    500,
    "오류가 발생했습니다. 잠시 후 다시 시도해 주세요.",
    true,
  ],
  UPSTREAM_UNAVAILABLE: [
    502,
    "외부 서비스의 응답을 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.",
    true,
  ],
  SERVICE_UNAVAILABLE: [
    503,
    "서비스를 일시적으로 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.",
    true,
  ],
  REQUEST_TIMEOUT: [
    504,
    "응답이 지연되고 있습니다. 잠시 후 처리 결과를 다시 확인해 주세요.",
    true,
  ],
} as const;

export type ErrorCode = keyof typeof definitions;

export class ApiError extends Error {
  constructor(public readonly code: ErrorCode) {
    super(definitions[code][1]);
  }
}

export function publicError(code: ErrorCode) {
  const [status, error, retryable] = definitions[code];
  return { status, code, error, retryable };
}

export function codeForStatus(status: number): ErrorCode {
  return (Object.keys(definitions) as ErrorCode[]).find((code) =>
    definitions[code][0] === status
  ) ?? "INTERNAL_ERROR";
}

export function errorCode(error: unknown): ErrorCode {
  if (error instanceof ApiError) return error.code;
  if (
    error instanceof DOMException &&
    ["TimeoutError", "AbortError"].includes(error.name)
  ) return "REQUEST_TIMEOUT";
  const code = error && typeof error === "object" && "code" in error
    ? String(error.code)
    : "";
  if (code === "PDR01") return "PAYMENT_REVIEW_REQUIRED";
  if (code === "42501") return "FORBIDDEN";
  if (code === "22P02" || code === "22023" || code === "23514") {
    return "INVALID_REQUEST";
  }
  if (["P0001", "23P01", "23505"].includes(code)) return "STATE_CONFLICT";
  if (
    code.startsWith("08") || ["40001", "40P01", "57014", "53300"].includes(code)
  ) return "SERVICE_UNAVAILABLE";
  return "INTERNAL_ERROR";
}

export function isErrorCode(value: unknown): value is ErrorCode {
  return typeof value === "string" && Object.hasOwn(definitions, value);
}

// Provider exceptions may contain credentials, response bodies or infrastructure
// details. Keep those out of the public contract and recovery ledger.
export async function providerCall<T>(run: () => Promise<T>): Promise<T> {
  try {
    return await run();
  } catch (error) {
    if (error instanceof ApiError) throw error;
    const code = errorCode(error);
    throw new ApiError(
      code === "REQUEST_TIMEOUT" ? code : "UPSTREAM_UNAVAILABLE",
    );
  }
}
