import {Alert, AlertTitle, AlertDescription} from '@/components/ui/alert';
import {errorMessage, errorRequestId} from '@dolpin/api-client/errors';

export function Failure({error}: {error: unknown}) {
  if (!error) return null;
  const requestId = errorRequestId(error);
  return <Alert variant="destructive"><AlertTitle>요청을 처리하지 못했습니다.</AlertTitle><AlertDescription><p>{errorMessage(error)}</p>{requestId ? <p className="break-all text-xs">문의 코드: {requestId}</p> : null}</AlertDescription></Alert>;
}
