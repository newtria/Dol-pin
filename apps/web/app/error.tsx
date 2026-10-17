'use client';
import {Button} from '@/components/ui/button';
import Link from 'next/link';
export default function PageError({reset}:{error:Error&{digest?:string};reset:()=>void}){
 return <section className="surface mx-auto flex max-w-xl flex-col items-start gap-5"><h1 className="page-heading">화면을 불러오지 못했어요</h1><p className="text-muted-foreground">다시 불러와 주세요. 결제 중이었다면 내 거래에서 처리 결과부터 확인해 주세요.</p><div className="flex flex-wrap gap-3"><Button onClick={reset}>다시 시도</Button><Button asChild variant="outline"><Link href="/rentals">내 거래 확인</Link></Button></div><Link href="/support" className="text-sm text-muted-foreground underline underline-offset-4">계속 문제가 생기나요? 고객 문의</Link></section>;
}
