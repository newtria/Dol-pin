// Development fixtures only. Hosted releases must provide their own public policies.
export async function GET(_request: Request, {params}: {params: Promise<{document: string}>}) {
  if (process.env.NODE_ENV !== 'development' || !/^http:\/\/127\.0\.0\.1:\d+$/.test(process.env.NEXT_PUBLIC_SUPABASE_URL ?? '')) {
    return new Response('Not found', {status: 404});
  }
  const {document} = await params;
  if (document !== 'terms' && document !== 'privacy') return new Response('Not found', {status: 404});
  const title = document === 'terms' ? '이용약관 동의 화면 — 로컬 개발용' : '개인정보 안내 화면 — 로컬 개발용';
  return new Response(`${title}\n\n이 페이지는 로컬 개발 환경에서 가입과 동의 흐름을 확인하기 위한 테스트 안내입니다. 실제 서비스의 이용약관이나 개인정보 처리방침이 아닙니다.\n테스트 계정과 가상 거래만 사용하세요. 로컬 DB에는 입력한 테스트 데이터가 저장되며 개발자가 조회·삭제할 수 있습니다.\n실제 서비스 배포 시 운영자가 승인한 별도의 약관과 개인정보 처리방침을 설정해야 합니다.\n`, {
    headers: {'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store'},
  });
}
