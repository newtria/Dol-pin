import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {errorResponse,jsonResponse,optionsResponse} from "../_shared/http.ts";
import {closeAuthAccount} from "../_shared/account-closure.ts";
import {ApiError} from "../_shared/errors.ts";

const url=Deno.env.get("SUPABASE_URL")!;
const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const dispatchToken=Deno.env.get("SERVICE_DELIVERY_TOKEN");
const expoToken=Deno.env.get("EXPO_ACCESS_TOKEN");
const operationsWebhook=Deno.env.get("OPS_ALERT_WEBHOOK_URL");
type Delivery={id:string;notification_id:string;token:string;status:string;receipt_id:string|null;attempt_count:number};
type ExpoResult={status?:string;id?:string;details?:{error?:string}};
async function expo(path:string,body:unknown,requestFetch:typeof fetch):Promise<{ok:boolean;status:number;data:unknown}>{
 const result=await requestFetch(`https://exp.host/--/api/v2/push/${path}`,{
  method:"POST",headers:{"Content-Type":"application/json",...(expoToken?{Authorization:`Bearer ${expoToken}`}:{})},
  body:JSON.stringify(body),signal:AbortSignal.timeout(10000),
 });
 return {ok:result.ok,status:result.status,data:await result.json().catch(()=>null)};
}
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return optionsResponse();
 if(req.method!=="POST")return jsonResponse(405,{});
 if(!dispatchToken||req.headers.get("Authorization")!==`Bearer ${dispatchToken}`)return jsonResponse(403,{});
 const deadline=Date.now()+50000;
 const requestFetch:typeof fetch=(input,init)=>{
  const remaining=deadline-Date.now();
  if(remaining<=0)return Promise.reject(new DOMException("Worker deadline reached","TimeoutError"));
  const timeout=AbortSignal.timeout(Math.min(10000,remaining));
  return fetch(input,{...init,signal:init?.signal?AbortSignal.any([init.signal,timeout]):timeout});
 };
 try{
  const admin=createClient(url,key,{auth:{persistSession:false},global:{fetch:requestFetch}});
  const lease=crypto.randomUUID();
  async function queueReminders(){
   const reminders=await admin.rpc("queue_service_reminders");
   if(reminders.error)throw reminders.error;
  }
  async function closeAccounts(){
  const closures=await admin.from("account_closures").select("user_id,attempts").is("auth_deleted_at",null)
   .or(`last_attempt_at.is.null,last_attempt_at.lt.${new Date(Date.now()-3600000).toISOString()}`).order("requested_at").limit(10);
  if(closures.error)throw closures.error;
  const closureResults=await Promise.allSettled((closures.data??[]).map(async closure=>{
   const attempt=await admin.from("account_closures").update({attempts:closure.attempts+1,last_attempt_at:new Date().toISOString()})
    .eq("user_id",closure.user_id).eq("attempts",closure.attempts).select("user_id");
   if(attempt.error)throw attempt.error;
   if(!attempt.data?.length)return;
   if(await closeAuthAccount(admin,closure.user_id)){
    const done=await admin.from("account_closures").update({auth_deleted_at:new Date().toISOString()}).eq("user_id",closure.user_id);
    if(done.error)throw done.error;
   }else throw new ApiError("UPSTREAM_UNAVAILABLE");
  }));
  const failedClosures=closureResults.filter(result=>result.status==='rejected').length;
  if(failedClosures){
   console.error(JSON.stringify({event:'account_cleanup_failed',count:failedClosures}));
   throw new ApiError("UPSTREAM_UNAVAILABLE");
  }
  }
  async function cleanupPhotos(){
  const photos=await admin.rpc("claim_orphan_product_photos");
  if(photos.error)throw photos.error;
  if(photos.data?.length){
   // Use Storage's API to remove underlying blobs, not only metadata rows.
   const removed=await admin.storage.from("product-photos").remove(photos.data);
   if(removed.error)throw removed.error;
   const marked=await admin.from("product_photo_deletions").update({deleted_at:new Date().toISOString()}).in("path",photos.data);
   if(marked.error)throw marked.error;
  }
  }
  async function deliverNotifications(){
  async function process(delivery:Delivery){
   const finish=async(status:string,receipt:string|null=null,code:string|null=null)=>{
    const result=await admin.rpc("finish_notification_delivery",{p_id:delivery.id,p_lease:lease,p_status:status,p_receipt:receipt,p_code:code});
    if(result.error)throw result.error;
   };
   try{
    let result:ExpoResult|undefined;
    if(delivery.status==="receipt"){
     if(!delivery.receipt_id){await finish("review",null,"MISSING_RECEIPT");return;}
     const response=await expo("getReceipts",{ids:[delivery.receipt_id]},requestFetch);
     if(!response.ok){await finish("receipt",delivery.receipt_id,"RECEIPT_UNAVAILABLE");return;}
     result=(response.data as {data?:Record<string,ExpoResult>}|null)?.data?.[delivery.receipt_id];
     if(!result){await finish(delivery.attempt_count>=12?"review":"receipt",delivery.receipt_id,"RECEIPT_PENDING");return;}
    }else{
     const [notification,token]=await Promise.all([
      admin.from("notifications").select("id,user_id,kind,title,body,reservation_id").eq("id",delivery.notification_id).single(),
      admin.from("push_tokens").select("user_id").eq("token",delivery.token).maybeSingle(),
     ]);
     if(notification.error)throw notification.error;
     if(token.error)throw token.error;
     if(token.data?.user_id!==notification.data.user_id){await finish("failed",null,"TOKEN_REMOVED");return;}
     const response=await expo("send",{to:delivery.token,title:notification.data.title,body:notification.data.body,
      sound:"default",channelId:"transactions",data:{notificationId:notification.data.id,reservationId:notification.data.reservation_id,kind:notification.data.kind,userId:notification.data.user_id}},requestFetch);
     if(!response.ok){
      await finish(response.status===429?"pending":"review",null,response.status===429?"RATE_LIMITED":"SEND_OUTCOME_UNKNOWN");return;
     }
     const data=(response.data as {data?:ExpoResult|ExpoResult[]}|null)?.data;
     result=Array.isArray(data)?data[0]:data;
    }
    if(!result||!["ok","error"].includes(result.status??"")){
     await finish(delivery.status==="receipt"?"receipt":"review",delivery.receipt_id,delivery.status==="receipt"?"RECEIPT_UNAVAILABLE":"SEND_OUTCOME_UNKNOWN");
    }else if(result.status==="ok"){
     if(delivery.status==="receipt")await finish("sent",delivery.receipt_id);
     else if(result.id)await finish("receipt",result.id);
     else await finish("review",null,"MISSING_TICKET");
    }else if(result?.details?.error==="DeviceNotRegistered"){
     const invalid=await admin.from("push_tokens").delete().eq("token",delivery.token);
     if(invalid.error)throw invalid.error;
    }else if(result?.details?.error==="MessageRateExceeded")await finish("pending",null,"RATE_LIMITED");
    else await finish("review",null,"PROVIDER_REJECTED");
   }catch{
    await finish(delivery.status==="receipt"?"receipt":"review",delivery.receipt_id,
     delivery.status==="receipt"?"RECEIPT_UNAVAILABLE":"SEND_OUTCOME_UNKNOWN");
   }
  }
  // Claim only a wave that can start now. Reserve four bounded requests for
  // claim, lookups, provider and result persistence before claiming more work.
  let processed=0;
  while(processed<40&&deadline-Date.now()>40000){
   const claimed=await admin.rpc("claim_notification_deliveries",{p_lease:lease});
   if(claimed.error)throw claimed.error;
   const deliveries=(claimed.data??[]) as Delivery[];
   if(!deliveries.length)break;
   const results=await Promise.allSettled(deliveries.map(process));
   if(results.some(result=>result.status==="rejected"))throw new ApiError("SERVICE_UNAVAILABLE");
   processed+=deliveries.length;
  }
  return processed;
  }
  async function sendOperationsAlert(){
  if(operationsWebhook){
   const health=await admin.rpc("operations_health");
   if(health.error)throw health.error;
   const services=health.data.services;
   const summary={pushNeedsReview:services.pushNeedsReview,pendingClosures:services.pendingClosures,photoCleanupNeedsReview:services.photoCleanupNeedsReview,
    pendingReports:services.pendingReports,rentalReviews:services.rentalReviews,payoutNeedsReview:services.payoutNeedsReview,paymentRecoveryStalled:services.paymentRecoveryStalled,
    paymentNeedsReview:services.payments?.needsReview??0,paymentRecoveryConfigured:services.payments?.configured===true,
    deliveryConfigured:services.configured===true};
   // Retry the last failed delivery even if its original backlog has cleared;
   // otherwise the external watchdog would report a failure forever.
   if(summary.pushNeedsReview||summary.pendingClosures||summary.photoCleanupNeedsReview||summary.pendingReports||summary.rentalReviews||summary.payoutNeedsReview||summary.paymentRecoveryStalled||summary.paymentNeedsReview||!summary.paymentRecoveryConfigured||!summary.deliveryConfigured||services.alertDeliveryFailures>0){
    const digest=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(JSON.stringify(summary)));
    const signature=Array.from(new Uint8Array(digest),value=>value.toString(16).padStart(2,"0")).join("");
    const alertLease=crypto.randomUUID();
    const claim=await admin.rpc("claim_service_alert",{p_signature:signature,p_lease:alertLease});
    if(claim.error)throw claim.error;
    if(claim.data){
     let success=false;
     try{
      const endpoint=new URL(operationsWebhook);
      if(endpoint.protocol!=="https:")throw new Error("Invalid operations webhook");
      const response=await requestFetch(endpoint,{method:"POST",headers:{"Content-Type":"application/json"},
       body:JSON.stringify({event:"dolpin_operations_attention",summary}),signal:AbortSignal.timeout(8000),redirect:"error"});
      success=response.ok;
     }catch{/* Persist a bounded retry without disclosing endpoint credentials. */}
     const finished=await admin.rpc("finish_service_alert",{p_lease:alertLease,p_success:success});
     if(finished.error)throw finished.error;
     if(!success)throw new ApiError("UPSTREAM_UNAVAILABLE");
    }
   }
  }
  }
  // Separate queues should not delay one another. Every network call shares a
  // deadline below pg_net's 60-second timeout, while durable leases survive loss.
  const results=await Promise.allSettled([queueReminders(),closeAccounts(),cleanupPhotos(),deliverNotifications(),sendOperationsAlert()]);
  const failed=results.find(result=>result.status==="rejected");
  if(failed?.status==="rejected")throw failed.reason;
  const delivery=results[3];
  return jsonResponse(200,{processed:delivery.status==="fulfilled"?delivery.value:0});
 }catch(error){return errorResponse(error);}
});
