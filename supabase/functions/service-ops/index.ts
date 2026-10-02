import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {requireAuthenticatedUser} from "../_shared/auth.ts";
import {errorResponse,jsonResponse,optionsResponse,parseJsonBody} from "../_shared/http.ts";

const url=Deno.env.get("SUPABASE_URL")!;
const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return optionsResponse();
 if(req.method!=="POST")return jsonResponse(405,{});
 try {
  const caller=await requireAuthenticatedUser(req,url,key);
  if(caller instanceof Response)return caller;
  const admin=createClient(url,key,{auth:{persistSession:false},global:{fetch:(input,init)=>fetch(input,{...init,signal:AbortSignal.timeout(10000)})}});
  const account=await admin.auth.admin.getUserById(caller.id);
  if(account.error||account.data.user.app_metadata?.dolpin_operator!==true)return jsonResponse(403,{});
  const active=await admin.rpc("account_is_active",{p_user_id:caller.id});
  if(active.error)throw active.error;
  if(active.data!==true)return jsonResponse(403,{});
  const body=await parseJsonBody<{action?:string;targetId?:string;value?:boolean;reason?:string;offset?:number}>(req,4096);
  if(body instanceof Response)return body;
  if(body.action==="list"){
   const offset=body.offset??0;
   if(!Number.isSafeInteger(offset)||offset<0||offset>1000000)return jsonResponse(400,{});
   const [reports,users,items,notifications,closures,health]=await Promise.all([
    admin.from("reports").select("id,reporter_id,reported_user_id,reported_item_id,reservation_id,reason,description,status,created_at").eq("status","pending").order("created_at").order("id").range(offset,offset+100),
    admin.from("users").select("id,nickname,suspended_at,deleted_at").not("suspended_at","is",null).is("deleted_at",null).order("suspended_at").order("id").range(offset,offset+100),
    admin.from("rental_items").select("id,title,lender_id,moderated_at,status").not("moderated_at","is",null).order("moderated_at").order("id").range(offset,offset+100),
    admin.from("notification_deliveries").select("id,status,last_code,attempt_count,receipt_id").eq("status","review").order("next_attempt_at").order("id").range(offset,offset+100),
    admin.from("account_closures").select("user_id,requested_at,attempts").is("auth_deleted_at",null).order("requested_at").order("user_id").range(offset,offset+100),
    admin.rpc("service_health"),
   ]);
   for(const result of [reports,users,items,notifications,closures,health])if(result.error)throw result.error;
   const hasMore=[reports,users,items,notifications,closures].some(result=>(result.data?.length??0)>100);
   return jsonResponse(200,{reports:reports.data?.slice(0,100),users:users.data?.slice(0,100),items:items.data?.slice(0,100),
    notifications:notifications.data?.slice(0,100).map(({receipt_id,...notification})=>({...notification,canRetry:receipt_id!==null||["PROVIDER_REJECTED","RATE_LIMITED"].includes(notification.last_code??"")})),
    closures:closures.data?.slice(0,100),health:health.data,hasMore});
  }
  if(body.action==="itemDetail"){
   if(typeof body.targetId!=="string"||!/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(body.targetId))return jsonResponse(400,{});
   const item=await admin.from("rental_items").select("id,title,description,photos,daily_price,deposit,status,moderated_at").eq("id",body.targetId).maybeSingle();
   if(item.error)throw item.error;
   if(!item.data)return jsonResponse(404,{});
   const audit=await admin.from("service_audit").insert({actor_id:caller.id,action:"inspect_item",target_id:body.targetId});
   if(audit.error)throw audit.error;
   return jsonResponse(200,item.data);
  }
  if(!["suspend","item","resolved","dismissed","retry_notification","dismiss_notification"].includes(body.action??"")||typeof body.targetId!=="string"||!/^[a-f\d]{8}-(?:[a-f\d]{4}-){3}[a-f\d]{12}$/i.test(body.targetId))return jsonResponse(400,{});
  if(body.reason!==undefined&&(typeof body.reason!=="string"||body.reason.length>500))return jsonResponse(400,{});
  if((body.action==="suspend"||body.action==="item")&&(typeof body.value!=="boolean"||!body.reason||body.reason.trim().length<2))return jsonResponse(400,{});
  const result=await admin.rpc("moderate_service",{p_actor:caller.id,p_action:body.action,p_target:body.targetId,p_value:body.value??null,p_reason:body.reason??null});
  if(result.error)throw result.error;
  return jsonResponse(200,{ok:true});
 }catch(error){return errorResponse(error);}
});
