import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {requireAuthenticatedUser} from "../_shared/auth.ts";
import {closeAuthAccount} from "../_shared/account-closure.ts";
import {errorResponse,jsonResponse,optionsResponse,parseJsonBody} from "../_shared/http.ts";

const url=Deno.env.get("SUPABASE_URL")!;
const key=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return optionsResponse();
 if(req.method!=="POST")return jsonResponse(405,{});
 try {
  const caller=await requireAuthenticatedUser(req,url,key);
  if(caller instanceof Response)return caller;
  const body=await parseJsonBody<{action?:string}>(req,1024);
  if(body instanceof Response)return body;
  if(body.action!=="close")return jsonResponse(400,{});
  const admin=createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input,init)=>fetch(input,{...init,signal:AbortSignal.timeout(10000)})}});
  const prepared=await admin.rpc("begin_account_closure",{p_user_id:caller.id});
  if(prepared.error){
   if(prepared.error.code==="PCL01")return jsonResponse(409,{code:"ACCOUNT_HAS_OPEN_TRADES"});
   throw prepared.error;
  }
  // Deidentify Auth while preserving transaction/evidence references. Public
  // access was closed first, so a failed Auth call cannot revive the account.
  if(!await closeAuthAccount(admin,caller.id))return jsonResponse(202,{status:"pending"});
  const finished=await admin.from("account_closures").update({auth_deleted_at:new Date().toISOString()}).eq("user_id",caller.id);
  if(finished.error)return jsonResponse(202,{status:"pending"});
  return jsonResponse(200,{status:"closed"});
 } catch(error){return errorResponse(error);}
});
