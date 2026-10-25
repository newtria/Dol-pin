import {createClient} from "https://esm.sh/@supabase/supabase-js@2";
import {requireAuthenticatedUser} from "../_shared/auth.ts";
import {closeAccountIdentity} from "../_shared/account-closure.ts";
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
  const result=await closeAccountIdentity(admin,caller.id);
  return jsonResponse(result.status==='pending'?202:200,result);
 } catch(error){
  if(error&&typeof error==='object'&&'code' in error&&error.code==='PCL01')return jsonResponse(409,{code:'ACCOUNT_HAS_OPEN_TRADES'});
  return errorResponse(error);
 }
});
