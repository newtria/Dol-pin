import {create} from 'zustand';
type Filters = {search: string; category: string; concertId: string};
const initial: Filters = {search: '', category: '', concertId: ''};
export const useExploreState = create<Filters & {set: (value: Partial<Filters>) => void; clear: () => void}>(set => ({...initial, set, clear: () => set(initial)}));
