import type {Metadata} from 'next';
import Link from 'next/link';
import {Providers} from '@/lib/providers';
import {Button} from '@/components/ui/button';
import './globals.css';
export const metadata: Metadata = {title: 'dol-pin · 콘서트 물품 대여', description: '콘서트에서 필요한 한정된 품목을 개인 간 빌려 쓰는 서비스'};
export default function Layout({children}: {children: React.ReactNode}) {
  return <html lang="ko"><body><Providers>
    <header className="border-b"><nav aria-label="주 메뉴" className="mx-auto flex min-h-20 max-w-[1440px] flex-wrap items-center gap-3 px-4 py-4 sm:gap-8 sm:px-6 lg:px-12">
      <Link href="/" className="text-3xl font-bold tracking-tight">dol-pin</Link>
      <Link href="/items">물품 탐색</Link><Link href="/account">계정</Link>
      <Button asChild className="ml-auto"><Link href="/items/new">내 물품 등록</Link></Button>
    </nav></header>
    <main className="mx-auto max-w-[1440px] px-6 py-10 lg:px-12">{children}</main>
  </Providers></body></html>;
}
