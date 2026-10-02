'use client';
import {Button} from '@/components/ui/button';
import Link from 'next/link';
export default function PageError({reset}:{error:Error&{digest?:string};reset:()=>void}){
 return <section className="flex flex-col items-start gap-5"><h1 className="text-2xl font-bold">화면을 불러오지 못했습니다.</h1><p>잠시 후 다시 시도해 주세요. 결제 중이었다면 내 거래에서 처리 결과부터 확인해 주세요.</p><Button onClick={reset}>다시 시도</Button><Link href="/rentals">내 거래 확인</Link></section>;
}
