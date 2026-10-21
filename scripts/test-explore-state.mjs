import assert from 'node:assert/strict';
import {beforeEach, test} from 'node:test';
import {useExploreState} from '../apps/mobile/src/state.ts';

beforeEach(() => useExploreState.getState().clear());

test('account reset discards a pending search even after the next account searches', () => {
  const previous = useExploreState.getState();
  const pendingSearch = () => previous.set({search: '이전 계정 검색'}, previous.resetVersion);

  previous.clear();
  const current = useExploreState.getState();
  current.set({search: '새 계정 검색', pickupArea: '잠실'}, current.resetVersion);
  const active = useExploreState.getState();
  pendingSearch();

  assert.equal(useExploreState.getState(), active);
  assert.equal(useExploreState.getState().search, '새 계정 검색');
  assert.equal(useExploreState.getState().pickupArea, '잠실');
});

test('clearing invalidates local drafts even when no applied filters remain', () => {
  const initialVersion = useExploreState.getState().resetVersion;
  useExploreState.getState().set({concertId: 'concert', category: 'camera', search: '카메라', pickupArea: '잠실', startsAt: '2099-10-18T10:00', endsAt: '2099-10-18T14:00'});
  useExploreState.getState().clear();
  const cleared = useExploreState.getState();

  assert.deepEqual([cleared.concertId, cleared.category, cleared.search, cleared.pickupArea, cleared.startsAt, cleared.endsAt], [undefined, undefined, '', '', '', '']);
  assert.equal(cleared.resetVersion, initialVersion + 1);
  cleared.clear();
  assert.equal(useExploreState.getState().resetVersion, initialVersion + 2);
});

test('changing a category preserves an in-flight search from the same account', () => {
  const editing = useExploreState.getState();
  editing.set({category: 'camera'});
  editing.set({search: '카메라'}, editing.resetVersion);

  assert.equal(useExploreState.getState().category, 'camera');
  assert.equal(useExploreState.getState().search, '카메라');
  assert.equal(useExploreState.getState().resetVersion, editing.resetVersion);
});
