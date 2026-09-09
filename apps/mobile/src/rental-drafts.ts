import {create} from 'zustand';
type Draft = {startsAt:string; endsAt:string; requestId?:string};
type State = {
  drafts:Record<string,Draft>;
  setDraft:(itemId:string,draft:Draft)=>void;
  removeDraft:(itemId:string)=>void;
  clear:()=>void;
};
// Local input and retry identity only. Quotes and rental rows stay in Query.
export const useRentalDrafts=create<State>(set=>({
  drafts:{},
  setDraft:(itemId,draft)=>set(state=>({drafts:{...state.drafts,[itemId]:draft}})),
  removeDraft:itemId=>set(state=>{const drafts={...state.drafts};delete drafts[itemId];return {drafts};}),
  clear:()=>set({drafts:{}}),
}));
