'use client';

import Link from 'next/link';
import {usePathname} from 'next/navigation';
import {Search, ArrowLeftRight, MessageCircle, UserRound, Plus, LifeBuoy} from 'lucide-react';
import {Button} from '@/components/ui/button';
import {cn} from '@/lib/utils';

const destinations = [
  {href: '/items', label: '물품 탐색', icon: Search},
  {href: '/rentals', label: '내 거래', icon: ArrowLeftRight},
  {href: '/notifications', label: '메시지·알림', icon: MessageCircle},
  {href: '/account', label: '내 계정', icon: UserRound},
];

export function SiteNavigation() {
  const pathname = usePathname();
  const active = (href: string) => href === '/items'
    ? pathname === '/' || pathname === '/items' || (pathname.startsWith('/items/') && !pathname.includes('/mine') && !pathname.includes('/new'))
    : pathname.startsWith(href);
  return <>
    <header className="sticky top-0 z-30 border-b bg-background/95 backdrop-blur-md">
      <div className="mx-auto flex h-20 max-w-[1240px] items-center justify-between gap-5 px-4 lg:px-8">
        <Link href="/" aria-label="dol-pin 홈" className="flex shrink-0 items-center gap-2.5">
          <img src="/icon.svg" alt="" className="size-9"/>
          <span className="text-2xl font-extrabold tracking-[-.06em]">dol-pin<span className="text-primary">.</span></span>
        </Link>
        <nav aria-label="주 메뉴" className="hidden items-center gap-1 md:flex">
          {destinations.map(({href, label}) => <Link key={href} href={href} aria-current={active(href) ? 'page' : undefined}
            className={cn('rounded-xl px-4 py-2.5 text-sm font-semibold transition-colors hover:bg-secondary', active(href) ? 'bg-accent text-primary' : 'text-muted-foreground')}>{label}</Link>)}
        </nav>
        <div className="flex items-center gap-2">
          <Button asChild variant="ghost" size="icon" className="hidden lg:inline-flex"><Link href="/support" aria-label="고객 문의"><LifeBuoy aria-hidden="true"/></Link></Button>
          <Button asChild variant="outline"><Link href="/items/new"><Plus data-icon="inline-start" aria-hidden="true"/>물품 등록</Link></Button>
        </div>
      </div>
    </header>
    <nav aria-label="모바일 주 메뉴" className="fixed inset-x-0 bottom-0 z-40 grid grid-cols-4 border-t bg-card px-2 pt-2 pb-[max(.5rem,env(safe-area-inset-bottom))] md:hidden">
      {destinations.map(({href, label, icon: Icon}) => <Link key={href} href={href} aria-current={active(href) ? 'page' : undefined}
        className={cn('flex min-h-14 flex-col items-center justify-center gap-1 rounded-xl text-[11px] font-semibold', active(href) ? 'bg-accent text-primary' : 'text-muted-foreground')}>
        <Icon className="size-5" aria-hidden="true"/>{label}
      </Link>)}
    </nav>
  </>;
}
