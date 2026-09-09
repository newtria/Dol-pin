import {create} from 'zustand';
import {createJSONStorage,persist} from 'zustand/middleware';
type Draft={startsAt:string;endsAt:string;requestId?:string};
type State={
 owner:string|null;drafts:Record<string,Draft>;
 setDraft:(itemId:string,draft:Draft)=>void;
 removeDraft:(itemId:string)=>void;
 ensureOwner:(owner:string|null)=>void;
};
// Tab-local form input survives browser history restoration/reload. Server
// rows, payment evidence and quoted amounts are never persisted here.
export const useRentalDrafts=create<State>()(persist(set=>({
 owner:null,drafts:{},
 setDraft:(itemId,draft)=>set(state=>({drafts:{...state.drafts,[itemId]:draft}})),
 removeDraft:itemId=>set(state=>{const drafts={...state.drafts};delete drafts[itemId];return{drafts};}),
 ensureOwner:owner=>set(state=>state.owner===owner?state:{owner,drafts:{}}),
}),{name:'dolpin-rental-input',storage:createJSONStorage(()=>sessionStorage),version:1}));
