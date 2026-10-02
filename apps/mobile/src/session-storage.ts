import {useSyncExternalStore} from 'react';
import {Platform} from 'react-native';
import * as SecureStore from 'expo-secure-store';

// A keychain outage must not stop public screens or authentication from opening.
// The fallback is process memory only; tokens never move to unencrypted storage.
const memory = new Map<string, string | null>();
const listeners = new Set<() => void>();
let persistent = true;
function unavailable() {
  if (!persistent) return;
  persistent = false;
  for (const listener of listeners) listener();
}
export function useSessionPersistence() {
  return useSyncExternalStore(listener => {listeners.add(listener); return () => {listeners.delete(listener);};}, () => persistent, () => true);
}
export const sessionStorage = {
  async getItem(name: string): Promise<string | null> {
    if (!persistent) return memory.get(name) ?? null;
    try {
      const value = Platform.OS === 'web'
        ? (typeof window === 'undefined' ? null : window.localStorage.getItem(name))
        : await SecureStore.getItemAsync(name);
      memory.set(name, value);
      return value;
    } catch {unavailable(); return memory.get(name) ?? null;}
  },
  async setItem(name: string, value: string): Promise<void> {
    memory.set(name, value);
    if (!persistent) return;
    try {
      if (Platform.OS === 'web') window.localStorage.setItem(name, value);
      else await SecureStore.setItemAsync(name, value);
    } catch {unavailable();}
  },
  async removeItem(name: string): Promise<void> {
    memory.set(name, null);
    // Degraded reads/writes must never skip deleting an older persisted login.
    // Keep the tombstone even when deletion fails so this process cannot revive it.
    try {
      if (Platform.OS === 'web') window.localStorage.removeItem(name);
      else await SecureStore.deleteItemAsync(name);
    } catch {unavailable();}
  },
};
