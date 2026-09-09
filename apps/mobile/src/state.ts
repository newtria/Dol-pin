import {create} from 'zustand';

// Interaction state only. Server rows and quoted prices never enter this store.
type ExploreState = {
  concertId?: string; category?: string; search: string;
  set: (filter: Partial<Pick<ExploreState, 'concertId' | 'category' | 'search'>>) => void;
  clear: () => void;
};
export const useExploreState = create<ExploreState>((set) => ({
  search: '', set, clear: () => set({concertId: undefined, category: undefined, search: ''}),
}));
