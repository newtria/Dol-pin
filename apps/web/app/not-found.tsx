import Link from 'next/link';
import {Button} from '@/components/ui/button';
import {Empty,EmptyHeader,EmptyTitle,EmptyDescription,EmptyContent} from '@/components/ui/empty';

export default function NotFound() {
  return <Empty className="min-h-[55vh] border bg-card"><EmptyHeader><p className="eyebrow">404</p><EmptyTitle>찾으시는 페이지가 없어요</EmptyTitle><EmptyDescription>주소가 바뀌었거나 더 이상 제공되지 않는 페이지예요. 진행 중인 예약은 내 거래에서 확인할 수 있어요.</EmptyDescription></EmptyHeader><EmptyContent><Button asChild><Link href="/items">물품 탐색</Link></Button><Button asChild variant="outline"><Link href="/rentals">내 거래 확인</Link></Button></EmptyContent></Empty>;
}
