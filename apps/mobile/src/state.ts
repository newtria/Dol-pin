import {create} from 'zustand';
// Interaction state only. Server rows and quoted prices never enter this store.
type ExploreState = {
  concertId?: string; category?: string; search: string; pickupArea: string; startsAt: string; endsAt: string;
  set: (filter: Partial<Pick<ExploreState, 'concertId' | 'category' | 'search' | 'pickupArea' | 'startsAt' | 'endsAt'>>) => void;
  clear: () => void;
};
export const useExploreState = create<ExploreState>((set) => ({
  search: '',pickupArea:'',startsAt:'',endsAt:'', set, clear: () => set({concertId: undefined, category: undefined, search: '',pickupArea:'',startsAt:'',endsAt:''}),
}));
