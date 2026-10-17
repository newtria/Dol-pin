import {router,type Href} from 'expo-router';
import {sessionStorage} from './session-storage';
const key='dolpin.auth-return';
// Only internal consumer routes can be resumed after authentication.
function safe(value:string|null):value is string{return !!value&&/^\/(?:rentals(?:\/[a-zA-Z0-9-]+)?|items\/(?:new|mine)|notifications|support|payouts)(?:\?[^\r\n]*)?$/.test(value);}
export async function beginSignIn(path:string){
 if(safe(path))await sessionStorage.setItem(key,path);
 router.push('/account');
}
export async function authReturn(){const value=await sessionStorage.getItem(key);return safe(value)?value as Href:null;}
export async function clearAuthReturn(){await sessionStorage.removeItem(key);}
