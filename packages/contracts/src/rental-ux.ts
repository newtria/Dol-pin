import type {RentalRecoveryStatus} from './index.ts';

function timestamp(value:string):number {
 const text=value.trim().replace(' ','T');
 if(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(text)) {
  const time=Date.parse(`${text}:00+09:00`);
  return Number.isFinite(time)&&new Date(time+9*3600000).toISOString().slice(0,16)===text?time:NaN;
 }
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$/.test(text))return NaN;
 const day=Date.parse(`${text.slice(0,10)}T00:00:00Z`);
 if(!Number.isFinite(day)||new Date(day).toISOString().slice(0,10)!==text.slice(0,10))return NaN;
 return Date.parse(text);
}

/** Immediate form feedback only. Reservation acceptance remains authoritative. */
export function rentalPeriodConflict(
 startsAt:string,endsAt:string,slots:readonly {starts_at:string;ends_at:string}[],
 availableFrom?:string|null,availableTo?:string|null,
):string|null {
 const start=timestamp(startsAt),end=timestamp(endsAt);
 if(!Number.isFinite(start)||!Number.isFinite(end))return '대여 시작과 반납 날짜·시간을 모두 입력해 주세요.';
 if(end<=start)return '반납 시간은 대여 시작 시간 이후로 선택해 주세요.';
 if(start<=Date.now())return '대여 시작은 현재 시간 이후로 선택해 주세요.';
 const startDay=new Date(start+9*3600000).toISOString().slice(0,10);
 const endDay=new Date(end+9*3600000).toISOString().slice(0,10);
 if(availableFrom&&startDay<availableFrom)return `${availableFrom}부터 빌릴 수 있어요. 시작 날짜를 변경해 주세요.`;
 if(availableTo&&endDay>availableTo)return `${availableTo}까지 반납해야 해요. 반납 날짜를 변경해 주세요.`;
 for(const slot of slots) {
  const occupiedStart=timestamp(slot.starts_at),occupiedEnd=timestamp(slot.ends_at);
  if(!Number.isFinite(occupiedStart)||!Number.isFinite(occupiedEnd)||occupiedEnd<=occupiedStart)
   return '예약 가능 시간을 확인하지 못했어요. 다시 불러와 주세요.';
  if(start<occupiedEnd&&end>occupiedStart)return '이미 예약된 시간과 겹쳐요. 대여 시작 또는 반납 시간을 변경해 주세요.';
 }
 return null;
}

export type RentalStepInput={
 status:string|null;lender_id:string;borrower_id:string;payment_action?:string|null;
 payment_attempt_merchant_uid?:string|null;payment_due_at?:string|null;
};
export type RentalNextStep={
 title:string;body:string;actionLabel:string;tone:'action'|'waiting'|'success'|'warning'|'neutral';priority:number;
};

/** Presentation hints never grant permission to execute a transaction command. */
export function rentalNextStep(
 rental:RentalStepInput,userId:string|null|undefined,recovery?:RentalRecoveryStatus,
 pickup?:{borrowerConfirmed:boolean;lenderConfirmed:boolean},
):RentalNextStep {
 const step=(title:string,body:string,actionLabel:string,tone:RentalNextStep['tone'],priority:number):RentalNextStep=>({title,body,actionLabel,tone,priority});
 const lender=!!userId&&rental.lender_id===userId;
 if(!userId||(!lender&&rental.borrower_id!==userId))return step('거래 내역 확인','거래에 참여한 계정으로 로그인해 주세요.','거래 확인','neutral',3);
 if(recovery?.state==='needs_review')return step('운영자가 결제 처리를 확인하고 있어요','중복 결제나 물품 전달을 잠시 멈추고 처리 내역을 확인해 주세요.','처리 내역 확인','warning',0);
 if(recovery?.state==='retry_scheduled'||recovery?.state==='processing')return step('결제 처리 결과를 확인하고 있어요','다시 결제하지 않아도 됩니다. 확인이 끝날 때까지 물품 전달·반납을 기다려 주세요.','처리 상태 확인','waiting',2);
 if(rental.payment_action) {
  const settling=rental.payment_action==='settle_pending';
  return step(settling?'보증금 반환을 처리하고 있어요':'환불 결과를 확인하고 있어요','처리가 끝나면 거래 상태가 바뀝니다. 같은 요청을 다시 제출하지 않아도 됩니다.','처리 상태 확인','waiting',2);
 }
 if(rental.payment_attempt_merchant_uid)return step('결제 결과를 확인하고 있어요','중복 결제하지 말고 거래 상세에서 결제 결과를 확인해 주세요.','결제 결과 확인','warning',0);
 switch(rental.status) {
  case 'requested':return lender
   ?step('예약 요청에 답해 주세요','대여 기간과 금액을 확인하고 수락 여부를 알려 주세요.','요청 확인','action',0)
   :step('빌려주는 분의 수락을 기다려요','수락한 뒤 결제할 수 있어요. 아직 예약이 확정된 상태는 아닙니다.','요청 내역 보기','waiting',2);
  case 'accepted': {
   if(rental.payment_due_at&&Date.parse(rental.payment_due_at)<=Date.now())return step('결제 기한이 지났어요','만료 처리 여부를 확인해 주세요. 이미 결제했다면 다시 결제하지 마세요.','예약 상태 확인','warning',1);
   return lender
    ?step('빌리는 분의 결제를 기다려요','결제가 완료된 뒤에 물품을 전달해 주세요.','예약 내역 보기','waiting',2)
    :step('결제하고 예약을 확정해 주세요','결제 기한 안에 대여료와 보증금을 결제해 주세요.','결제하기','action',0);
  }
  case 'pending':return step('결제 상태 확인이 필요해요','거래 상세에서 진행 상황을 확인해 주세요. 이미 결제했다면 다시 결제하지 마세요.','결제 상태 확인','warning',1);
  case 'paid': {
   const confirmed=lender?pickup?.lenderConfirmed:pickup?.borrowerConfirmed;
   if(confirmed)return step('거래 상대의 인수 확인을 기다려요','내 확인은 저장됐어요. 양쪽이 확인하면 사용 중으로 바뀝니다.','인수 상태 보기','waiting',2);
   return lender
    ?step('물품 전달을 확인해 주세요','약속한 장소에서 실제로 물품을 건넨 뒤 확인해 주세요.','전달 확인','action',0)
    :step('물품 수령을 확인해 주세요','약속한 장소에서 실제로 물품을 받은 뒤 확인해 주세요.','수령 확인','action',0);
  }
  case 'picked_up':return lender
   ?step('빌리는 분이 사용 중이에요','약속한 반납 시간을 확인해 주세요. 반납 사진이 제출되면 상태를 확인할 수 있어요.','반납 일정 보기','waiting',2)
   :step('사용 후 반납을 제출해 주세요','실제로 물품을 반납한 뒤 상태를 보여 주는 사진을 제출해 주세요.','반납하기','action',1);
  case 'returned':return lender
   ?step('반납된 물품을 확인해 주세요','실물과 사진을 확인한 뒤 반납을 확정하면 보증금 반환이 시작됩니다.','반납 확인','action',0)
   :step('빌려주는 분의 반납 확인을 기다려요','반납 확인 후 보증금이 반환됩니다. 카드사 반영에는 시간이 걸릴 수 있어요.','반납 내역 보기','waiting',2);
  case 'disputed':return step('거래 문제를 확인하고 있어요','접수한 내용과 증빙을 확인할 수 있어요. 추가 증빙이 있다면 거래 상세에 남겨 주세요.','접수 내역 보기','warning',1);
  case 'settled':return step('거래를 마쳤어요','반납과 보증금 반환이 처리됐어요. 카드사 내역 반영에는 시간이 걸릴 수 있습니다.','완료 내역 보기','success',3);
  case 'resolved':return step('거래 문제 처리가 끝났어요','판정 내용과 반환 금액을 확인해 주세요.','처리 결과 보기','neutral',3);
  case 'cancelled':return step('취소된 거래예요','결제한 거래의 환불 내역은 카드사 반영 후 확인할 수 있어요.','취소 내역 보기','neutral',3);
  case 'expired':return step('결제 기한이 지나 만료됐어요','다시 빌리려면 상품에서 가능한 기간을 확인하고 새로 요청해 주세요.','만료 내역 보기','neutral',3);
  case 'rejected':return step('이번 예약은 수락되지 않았어요','다른 기간이나 물품으로 예약할 수 있어요.','요청 내역 보기','neutral',3);
  default:return step('거래 상태를 확인해 주세요','거래 상세에서 현재 상태와 조건을 확인할 수 있어요.','거래 내역 보기','neutral',3);
 }
}
