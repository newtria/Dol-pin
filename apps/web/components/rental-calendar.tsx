'use client';
import {useEffect,useState} from 'react';
import {Button} from './ui/button';

type Slot = {starts_at: string; ends_at: string};
const koreaDate = () => new Date(Date.now() + 9 * 3600000).toISOString().slice(0, 10);

function dayAvailability(day: string, slots: Slot[]) {
  const start = Date.parse(`${day}T00:00:00+09:00`), end = start + 86400000;
  const overlaps = slots.map(slot => [Math.max(start, Date.parse(slot.starts_at)), Math.min(end, Date.parse(slot.ends_at))])
    .filter(([from, to]) => from < to).sort((a, b) => a[0] - b[0]);
  let cursor = start;
  for (const [from, to] of overlaps) {if (from > cursor) break; cursor = Math.max(cursor, to);}
  return cursor >= end ? 'full' : overlaps.length ? 'partial' : 'open';
}

export function RentalCalendar({startsAt, endsAt, slots, availableFrom, availableTo, disabled, onSelect}: {
  startsAt: string; endsAt: string; slots: Slot[]; availableFrom?: string | null; availableTo?: string | null;
  disabled?: boolean; onSelect: (field: 'startsAt' | 'endsAt', day: string, time?: string) => void;
}) {
  const today = koreaDate();
  const [month, setMonth] = useState(() => (startsAt || (availableFrom && availableFrom > today ? availableFrom : today)).slice(0, 7));
  useEffect(() => {if (startsAt) setMonth(startsAt.slice(0, 7));}, [startsAt.slice(0, 7)]);
  const [endpoint, setEndpoint] = useState<'startsAt' | 'endsAt'>('startsAt');
  const [year, monthNumber] = month.split('-').map(Number);
  const count = new Date(Date.UTC(year, monthNumber, 0)).getUTCDate();
  const offset = new Date(Date.UTC(year, monthNumber - 1, 1)).getUTCDay();
  function move(delta: number) {setMonth(new Date(Date.UTC(year, monthNumber - 1 + delta, 1)).toISOString().slice(0, 7));}
  return <section aria-label="대여 날짜 달력" className="rounded-2xl border bg-card p-4 sm:p-5">
    <div className="mb-4 flex gap-2" aria-label="선택할 날짜"><Button type="button" variant={endpoint === 'startsAt' ? 'default' : 'outline'} aria-pressed={endpoint === 'startsAt'} disabled={disabled} onClick={() => setEndpoint('startsAt')}>받는 날 선택</Button><Button type="button" variant={endpoint === 'endsAt' ? 'default' : 'outline'} aria-pressed={endpoint === 'endsAt'} disabled={disabled} onClick={() => setEndpoint('endsAt')}>반납일 선택</Button></div>
    <div className="mb-4 flex items-center justify-between"><Button type="button" variant="ghost" aria-label="이전 달" disabled={disabled || month <= today.slice(0, 7)} onClick={() => move(-1)}>←</Button><h3 className="font-semibold" aria-live="polite">{year}년 {monthNumber}월</h3><Button type="button" variant="ghost" aria-label="다음 달" disabled={disabled} onClick={() => move(1)}>→</Button></div>
    <div className="grid grid-cols-7 gap-1 text-center text-xs text-muted-foreground" aria-hidden="true">{['일', '월', '화', '수', '목', '금', '토'].map(day => <span key={day} className="py-2">{day}</span>)}</div>
    <div className="grid grid-cols-7 gap-1">{Array.from({length: offset}, (_, index) => <span key={`space-${index}`}/>)}{Array.from({length: count}, (_, index) => {
      const day = `${month}-${String(index + 1).padStart(2, '0')}`;
      const availability = dayAvailability(day, slots);
      const midnight = Date.parse(`${day}T00:00:00+09:00`);
      const midnightReturn = availability === 'full' && slots.some(slot => Date.parse(slot.starts_at) === midnight) && !slots.some(slot => Date.parse(slot.starts_at) < midnight && Date.parse(slot.ends_at) > midnight);
      const blocked = day < today || !!availableFrom && day < availableFrom || !!availableTo && day > availableTo || availability === 'full' && (endpoint === 'startsAt' || !midnightReturn);
      const selected = day === startsAt.slice(0, 10) || day === endsAt.slice(0, 10);
      const inRange = day > startsAt.slice(0, 10) && day < endsAt.slice(0, 10);
      return <button key={day} type="button" disabled={disabled || blocked} aria-pressed={selected} aria-label={`${year}년 ${monthNumber}월 ${index + 1}일${blocked ? ', 예약 불가' : availability === 'full' ? ', 자정 반납만 선택 가능' : availability === 'partial' ? ', 일부 시간 예약 있음' : ', 선택 가능'}${day === startsAt.slice(0, 10) ? ', 받는 날' : ''}${day === endsAt.slice(0, 10) ? ', 반납일' : ''}`} onClick={() => {onSelect(endpoint, day, availability === 'full' ? '00:00' : undefined); if (endpoint === 'startsAt') setEndpoint('endsAt');}} className={`flex min-h-12 flex-col items-center justify-center rounded-lg text-sm transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring disabled:cursor-not-allowed disabled:text-muted-foreground/40 ${selected ? 'bg-primary font-bold text-primary-foreground' : inRange ? 'bg-primary/10' : 'hover:bg-muted'}`}><span>{index + 1}</span>{availability !== 'open' && !blocked ? <span className={`text-[9px] ${selected ? 'text-primary-foreground' : 'text-muted-foreground'}`}>{availability === 'full' ? '자정 반납' : '일부 예약'}</span> : null}</button>;
    })}</div>
    <p className="mt-4 text-xs leading-5 text-muted-foreground">흐린 날짜는 선택할 수 없습니다. ‘일부 예약’ 날짜는 아래에서 가능한 시간을 확인해 주세요. 모든 시간은 한국 시간입니다.</p>
  </section>;
}
