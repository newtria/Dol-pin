import { z } from 'zod';
export type { Database } from './database';

export const categories = ['lightstick', 'phone', 'camera', 'slogan', 'costume', 'etc'] as const;
export const categoryLabels: Record<(typeof categories)[number], string> = {
  lightstick: '응원봉', phone: '휴대폰', camera: '카메라', slogan: '슬로건', costume: '의상', etc: '기타 콘서트 물품',
};
export const itemInput = z.object({
  title: z.string().trim().min(2, '상품명을 2자 이상 입력해 주세요').max(80),
  description: z.string().trim().max(2000),
  category: z.enum(categories),
  concert_id: z.uuid().nullable(),
  daily_price: z.number().int().min(100).max(1000000),
  deposit: z.number().int().min(0).max(3000000),
  photos: z.array(z.url()).min(1, '사진을 추가해 주세요').max(5),
  pickup_method: z.literal('direct'),
  pickup_note: z.string().trim().min(2, '인수·반납 장소를 입력해 주세요').max(300),
});
export type ItemInput = z.infer<typeof itemInput>;
export const phoneInput = z.object({phone: z.string().regex(/^\+82\d{9,10}$/, '+82로 시작하는 전화번호를 입력해 주세요')});
export const profileInput = z.object({nickname: z.string().trim().min(2).max(30)});
export const formatWon = (value: number) => `${new Intl.NumberFormat('ko-KR').format(value)}원`;

// Explicit Korea time input; no device timezone-dependent parsing.
export function koreaTime(value: string): string {
  const normalized = value.trim().replace(' ', 'T');
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(normalized)) throw new Error('날짜와 시간을 YYYY-MM-DD HH:mm 형식으로 입력해 주세요.');
  const parsed = new Date(`${normalized}:00+09:00`);
  if (!Number.isFinite(parsed.getTime()) || new Date(parsed.getTime()+9*3600000).toISOString().slice(0,16)!==normalized)
    throw new Error('실제 존재하는 날짜와 시간을 입력해 주세요.');
  return parsed.toISOString();
}
const localTimeInput = z.string().refine(value => {try {koreaTime(value);return true;} catch {return false;}}, 'YYYY-MM-DD HH:mm 형식의 날짜와 시간을 입력해 주세요.');
export const rentalPeriodInput = z.object({startsAt:localTimeInput,endsAt:localTimeInput}).superRefine((v,ctx)=>{
  try {if (koreaTime(v.endsAt)<=koreaTime(v.startsAt)) ctx.addIssue({code:'custom',path:['endsAt'],message:'반납은 시작 이후여야 합니다.'});} catch {}
});
export const rentalStatusLabels: Record<string,string> = {requested:'수락 대기',accepted:'수락됨',rejected:'거절됨',expired:'결제 기한 만료',pending:'결제 대기',paid:'결제 완료',picked_up:'사용 중',returned:'반납됨',settled:'거래 완료',cancelled:'취소됨',disputed:'분쟁 처리 중',resolved:'분쟁 해결'};
export const formatKoreaTime = (value:string) => new Intl.DateTimeFormat('ko-KR',{timeZone:'Asia/Seoul',month:'long',day:'numeric',hour:'2-digit',minute:'2-digit'}).format(new Date(value));

export function rentalTitle(rental:{terms_snapshot:unknown;item:{title:string}|null}):string {
 const terms=rental.terms_snapshot;
 if(terms&&typeof terms==='object'&&'title' in terms&&typeof terms.title==='string')return terms.title;
 return rental.item?.title??'상품 정보 확인 필요';
}

export function rentalTerms(value:unknown):{description:string;pickupNote:string} {
 if(!value||typeof value!=='object')return {description:'',pickupNote:''};
 const v=value as Record<string,unknown>;
 return {description:typeof v.description==='string'?v.description:'',pickupNote:typeof v.pickup_note==='string'?v.pickup_note:''};
}
