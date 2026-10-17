import type {Metadata} from 'next';
import {Providers} from '@/lib/providers';
import {SiteNavigation} from '@/components/site-navigation';
import './globals.css';
export const metadata: Metadata = {title: 'dol-pin · 콘서트 물품 대여', description: '콘서트에서 필요한 한정된 품목을 개인 간 빌려 쓰는 서비스'};
export default function Layout({children}: {children: React.ReactNode}) {
  return <html lang="ko"><body><Providers>
    <a href="#main-content" className="sr-only fixed left-4 top-4 z-50 rounded-lg bg-card p-3 focus:not-sr-only">본문으로 바로가기</a>
    <SiteNavigation/>
    <main id="main-content" tabIndex={-1} className="page-shell outline-none">{children}</main>
  </Providers></body></html>;
}
