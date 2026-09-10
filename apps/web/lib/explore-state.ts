import {useSearchParams,usePathname} from 'next/navigation';
type Filters={search:string;category:string;concertId:string};
export function useExploreState() {
 const params=useSearchParams();const pathname=usePathname();
 return {search:params.get('search')??'',category:params.get('category')??'',concertId:params.get('concertId')??'',
 set(values:Partial<Filters>){
  const next=new URLSearchParams(window.location.search);
  for(const [key,value] of Object.entries(values)){if(value)next.set(key,value);else next.delete(key);}
  window.history.replaceState(null,'',`${pathname}${next.size?'?'+next:''}`);
 }};
}
