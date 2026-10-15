export type CheckoutProgress={status:string;recoveryState?:string;nextRetryAt?:string|null};
export type CheckoutConfirmation={paymentKey:string;amount:number};
type RecoveryCommand={action:'status'}|({action:'confirm'}&CheckoutConfirmation);

// Workers only look up payments. The browser that received the payment key must
// retry approval if its first confirmation lost a lease or a provider response.
export async function recoverCheckout(
 call:(command:RecoveryCommand)=>Promise<CheckoutProgress>,
 confirmation:CheckoutConfirmation|null,
 active:()=>boolean=()=>true,
):Promise<CheckoutProgress> {
 const result=await call({action:'status'});
 if(!active()||!confirmation||!['accepted','processing'].includes(result.status)||result.recoveryState==='needs_review')return result;
 // Only the server can distinguish an approval backoff from a worker lookup
 // delay. It checks the lease and retry clock before any provider command.
 const confirmed=await call({action:'confirm',...confirmation});
 // A denied claim returns only "processing". Keep the status read's retry
 // details so the UI can still explain the server's scheduled work.
 return {...result,...confirmed};
}
