import {useSearchParams,usePathname} from 'next/navigation';
import {localExploreTime} from './explore-time';
export {localExploreTime} from './explore-time';
export type ExploreFilters={search:string;category:string;concertId:string;pickupArea:string;startsAt:string;endsAt:string};
export function useExploreState() {
 const params=useSearchParams();const pathname=usePathname();
 return {search:params.get('search')??'',category:params.get('category')??'',concertId:params.get('concertId')??'',pickupArea:params.get('pickupArea')??'',startsAt:localExploreTime(params.get('startsAt')),endsAt:localExploreTime(params.get('endsAt')),
 set(values:Partial<ExploreFilters>){
  const next=new URLSearchParams(window.location.search);
  for(const [key,value] of Object.entries(values)){if(value)next.set(key,value);else next.delete(key);}
  window.history.replaceState(null,'',`${pathname}${next.size?'?'+next:''}`);
 }};
}
