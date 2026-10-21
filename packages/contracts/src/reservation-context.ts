type RouteValue = string|readonly string[]|null;
export type ReservationPeriodSource = {startsAt?:RouteValue;endsAt?:RouteValue};

/** Expo returns repeated query parameters as arrays; match URLSearchParams.get. */
export function reservationRouteValue(value:unknown):string {
 const first=Array.isArray(value)?value[0]:value;
 return typeof first==='string'?first:'';
}

function localTime(value:RouteValue|undefined):string {
 let text=reservationRouteValue(value).trim().replace(' ','T');
 if(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$/.test(text)){
  const time=Date.parse(text),day=Date.parse(`${text.slice(0,10)}T00:00:00Z`);
  // Do not normalize February 30 into March or pass malformed values to calendars.
  if(!Number.isFinite(time)||!Number.isFinite(day)||new Date(day).toISOString().slice(0,10)!==text.slice(0,10))return '';
  text=new Date(time+9*3600000).toISOString().slice(0,16);
 }
 if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(text))return '';
 const time=Date.parse(`${text}:00+09:00`);
 return Number.isFinite(time)&&new Date(time+9*3600000).toISOString().slice(0,16)===text?text:'';
}

/** A period belongs to one source; never pair a new route start with an old draft end. */
export function reservationInitialPeriod(...sources:readonly (ReservationPeriodSource|undefined)[]):{startsAt:string;endsAt:string} {
 const source=sources.find(value=>reservationRouteValue(value?.startsAt).trim()||reservationRouteValue(value?.endsAt).trim());
 return {startsAt:localTime(source?.startsAt),endsAt:localTime(source?.endsAt)};
}

/** A date-link change must reset form state even when the item and account stay the same. */
export function reservationContextKey(owner:string|null|undefined,item:string,period:ReservationPeriodSource):string {
 return JSON.stringify([owner??null,item,reservationRouteValue(period.startsAt),reservationRouteValue(period.endsAt)]);
}
