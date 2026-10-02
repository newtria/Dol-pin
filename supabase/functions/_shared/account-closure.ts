import type {SupabaseClient} from "https://esm.sh/@supabase/supabase-js@2";

/** Public profile closure happens first. Every Auth step may be retried safely. */
export async function closeAuthAccount(admin:SupabaseClient,userId:string):Promise<boolean> {
 const account=await admin.auth.admin.getUserById(userId);
 if(account.error)return account.error.code==="user_not_found"||account.error.status===404;
 if(!account.data.user)return false;
 // Auth metadata updates merge keys; sending an empty object would retain them.
 const userMetadata=Object.fromEntries(Object.keys(account.data.user.user_metadata??{}).map(key=>[key,null]));
 const restricted=await admin.auth.admin.updateUserById(userId,{user_metadata:userMetadata,ban_duration:"876000h"});
 if(restricted.error)return false;
 const deleted=await admin.auth.admin.deleteUser(userId,true);
 return !deleted.error||deleted.error.code==="user_not_found"||deleted.error.status===404;
}
