import {Alert, AlertTitle, AlertDescription} from '@/components/ui/alert';
export function Failure({error}: {error: unknown}) {
  return error ? <Alert variant="destructive"><AlertTitle>요청을 처리하지 못했습니다.</AlertTitle><AlertDescription>{error instanceof Error ? error.message : String(error)}</AlertDescription></Alert> : null;
}
