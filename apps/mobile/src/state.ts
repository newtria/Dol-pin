import {create} from 'zustand';
// Interaction state only. Server rows and quoted prices never enter this store.
type ExploreState = {
  concertId?: string; category?: string; search: string; pickupArea: string; startsAt: string; endsAt: string;
  resetVersion: number;
  set: (filter: Partial<Pick<ExploreState, 'concertId' | 'category' | 'search' | 'pickupArea' | 'startsAt' | 'endsAt'>>, resetVersion?: number) => void;
  clear: () => void;
};
export const useExploreState = create<ExploreState>((set) => ({
  search: '', pickupArea: '', startsAt: '', endsAt: '', resetVersion: 0,
  // A delayed search from the previous account must not restore cleared filters.
  set: (filter, resetVersion) => set(current => resetVersion !== undefined && resetVersion !== current.resetVersion ? current : filter),
  clear: () => set(current => ({concertId: undefined, category: undefined, search: '', pickupArea: '', startsAt: '', endsAt: '', resetVersion: current.resetVersion + 1})),
}));
