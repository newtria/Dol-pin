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
  pickup_area: z.string().trim().min(2, '공개할 만남 지역을 입력해 주세요').max(100),
  pickup_note: z.string().trim().min(2, '거래 상대에게 안내할 상세 장소를 입력해 주세요').max(300),
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

// Presentation only: the server still computes and freezes authoritative amounts.
export function rentalEstimate(startsAt:string,endsAt:string,dailyPrice:number,deposit:number) {
 try {
  const duration=Date.parse(koreaTime(endsAt))-Date.parse(koreaTime(startsAt));
  if(duration<=0)return null;
  const days=Math.ceil(duration/86400000),fee=days*dailyPrice;
  if(!Number.isSafeInteger(fee+deposit))return null;
  return {days,fee,deposit,total:fee+deposit};
 } catch {return null;}
}

export type RentalRecoveryStatus = {state:'idle'|'processing'|'retry_scheduled'|'needs_review';next_retry_at:string|null;reference:string};

export function rentalGuidance(r:{status:string|null;payment_action:string|null;payment_attempt_merchant_uid:string|null},lender:boolean,recovery?:RentalRecoveryStatus) {
 if(recovery?.state==='needs_review')return {title:'결제 처리에 운영 확인이 필요해요',body:'자동 처리가 멈췄습니다. 중복 결제하거나 인수·반납을 진행하지 마세요. 문의할 때 아래 거래 번호를 알려 주세요.'};
 if(recovery?.state==='retry_scheduled')return {title:'결제 확인을 다시 시도할 예정이에요',body:'안내된 시각 이후 서버에서 다시 확인합니다. 그동안 중복 결제하거나 인수·반납을 진행하지 마세요.'};
 if(r.payment_action)return {title:'환불 결과를 확인하고 있어요',body:'확인이 끝날 때까지 물품 전달·반납을 진행하지 마세요. 아래에서 처리 상태를 다시 확인할 수 있습니다.'};
 switch(r.status) {
  case 'requested':return lender?{title:'예약 요청을 확인해 주세요',body:'대여 기간과 금액을 확인한 뒤 수락하거나 거절해 주세요.'}:{title:'빌려주는 분의 수락을 기다리고 있어요',body:'수락하면 결제할 수 있습니다. 아직 물품이 확보된 상태는 아닙니다.'};
  case 'accepted':return r.payment_attempt_merchant_uid?{title:'결제 결과를 확인하고 있어요',body:'중복 결제하지 마세요. 거래 상세에서 처리 상태를 이어서 확인할 수 있습니다.'}:lender?{title:'빌리는 분의 결제를 기다리고 있어요',body:'결제 완료를 확인한 뒤 약속한 장소에서 물품을 전달해 주세요.'}:{title:'결제하면 예약이 확정돼요',body:'아래 기한 안에 대여료와 보증금을 결제해 주세요.'};
  case 'paid':return lender?{title:'약속한 장소에서 물품을 전달해 주세요',body:'빌리는 분에게 실제로 건넨 뒤 아래 버튼으로 전달을 확인해 주세요.'}:{title:'약속한 장소에서 물품을 받아 주세요',body:'빌려주는 분이 전달을 확인하면 사용 중으로 바뀝니다.'};
  case 'picked_up':return lender?{title:'빌리는 분이 물품을 사용 중이에요',body:'반납 사진이 제출되면 물품 상태를 확인해 주세요.'}:{title:'사용 후 물품을 반납해 주세요',body:'약속한 장소에 실제로 반납한 뒤 사진을 선택하고 반납 제출을 눌러 주세요.'};
  case 'returned':return lender?{title:'반납된 물품을 확인해 주세요',body:'사진과 실제 물품 상태를 확인한 뒤 수령을 확정하면 보증금이 반환됩니다.'}:{title:'빌려주는 분의 반납 확인을 기다리고 있어요',body:'수령 확인 후 보증금 반환을 진행합니다. 카드사 반영에는 시간이 걸릴 수 있습니다.'};
  case 'settled':return {title:'반납과 보증금 반환이 처리됐어요',body:'카드사 반영 시점에 따라 환불 내역이 늦게 표시될 수 있습니다.'};
  case 'expired':return {title:'결제 기한이 지나 예약이 만료됐어요',body:'대여를 원하시면 상품에서 새 예약을 요청해 주세요.'};
  case 'cancelled':return {title:'거래가 취소됐어요',body:'결제한 거래의 환불 내역은 카드사 반영 후 확인할 수 있습니다.'};
  case 'rejected':return {title:'이번 예약은 수락되지 않았어요',body:'다른 기간이나 물품으로 예약을 요청해 주세요.'};
  case 'disputed':return {title:'거래 문제를 확인하고 있어요',body:'처리 결과가 확정될 때까지 거래 증빙을 보관해 주세요.'};
  default:return {title:'거래 상태를 확인해 주세요',body:'아래 거래 내역에서 현재 상태와 조건을 확인할 수 있습니다.'};
 }
}
