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
