'use client';

import {useState} from 'react';
import {Camera, ChevronLeft, ChevronRight, ImageOff, Smartphone, WandSparkles} from 'lucide-react';
import {Button} from '@/components/ui/button';
import {cn} from '@/lib/utils';

export function ProductImage({src, alt, category, className, eager = false}: {src?: string; alt: string; category?: string; className?: string; eager?: boolean}) {
  const [failedSrc, setFailedSrc] = useState<string>();
  const Icon = category === 'phone' ? Smartphone : category === 'camera' ? Camera : category === 'lightstick' ? WandSparkles : ImageOff;
  if (!src || failedSrc === src) return <div role="img" aria-label={`${alt} · 사진을 표시할 수 없습니다`} className={cn('flex flex-col items-center justify-center gap-2 bg-secondary text-muted-foreground', className)}><Icon className="size-10" aria-hidden="true"/><span className="text-xs">사진을 불러올 수 없어요</span></div>;
  return <img src={src} alt={alt} className={className} loading={eager ? 'eager' : 'lazy'} decoding="async" onError={() => setFailedSrc(src)}/>;
}

export function ProductGallery({photos, title, category}: {photos: string[]; title: string; category?: string}) {
  const [selected, setSelected] = useState(0);
  const index = Math.min(selected, Math.max(0, photos.length - 1));
  return <section className="flex min-w-0 flex-col gap-3" aria-label="상품 사진">
    <div className="relative overflow-hidden rounded-2xl border bg-card">
      <ProductImage src={photos[index]} alt={`${title} 사진 ${index + 1}`} category={category} eager className="aspect-[4/3] max-h-[420px] w-full object-contain"/>
      {photos.length > 1 ? <><div className="absolute inset-x-3 top-1/2 flex -translate-y-1/2 justify-between"><Button variant="outline" size="icon" aria-label="이전 사진" onClick={() => setSelected((index - 1 + photos.length) % photos.length)}><ChevronLeft aria-hidden="true"/></Button><Button variant="outline" size="icon" aria-label="다음 사진" onClick={() => setSelected((index + 1) % photos.length)}><ChevronRight aria-hidden="true"/></Button></div><p aria-live="polite" className="absolute bottom-3 right-3 rounded-full bg-card/95 px-3 py-1 text-xs font-semibold">{index + 1} / {photos.length}</p></> : null}
    </div>
    {photos.length > 1 ? <div className="flex gap-2 overflow-x-auto py-1" aria-label="사진 선택">{photos.map((src, i) => <button type="button" key={`${src}:${i}`} aria-label={`${i + 1}번째 사진 보기`} aria-pressed={i === index} onClick={() => setSelected(i)} className={cn('size-14 shrink-0 overflow-hidden rounded-lg border-2', i === index ? 'border-primary' : 'border-transparent')}><ProductImage src={src} alt="" className="size-full object-cover"/></button>)}</div> : null}
  </section>;
}
