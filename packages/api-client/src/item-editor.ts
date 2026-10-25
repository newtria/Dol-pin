// An edit screen must fetch its own current snapshot before populating fields.
// Cached values can outlive a successful save or another device's changes.
export const itemEditorQueryPolicy={staleTime:0,refetchOnMount:'always' as const};
export function freshItemForEditor<T>(query:{data?:T;isSuccess:boolean;isFetchedAfterMount:boolean;isFetching:boolean}):T|undefined{
 return query.isSuccess&&query.isFetchedAfterMount&&!query.isFetching?query.data:undefined;
}
import type {ItemInput} from '@dolpin/contracts';
import {ApiRequestError} from './errors.ts';

type EditableItem=Omit<ItemInput,'description'|'category'|'pickup_method'|'pickup_area'|'pickup_note'>&{
 updated_at:string|null;description:string|null;category:string;pickup_method:string;pickup_area:string|null;pickup_note:string|null;
};
export type ItemEditorSnapshot={version:string;input:ItemInput};
/** Capture together with form.reset; background query updates must not replace this version. */
export function captureItemEditorSnapshot(item:EditableItem):ItemEditorSnapshot{
 if(!item.updated_at)throw new ApiRequestError({code:'PIV01'});
 return {version:item.updated_at,input:{
  title:item.title,description:item.description??'',category:item.category as ItemInput['category'],concert_id:item.concert_id,
  daily_price:item.daily_price,deposit:item.deposit,photos:[...item.photos],pickup_method:'direct',
  pickup_area:item.pickup_area??'',pickup_note:item.pickup_note??'',available_from:item.available_from,available_to:item.available_to,
 }};
}
