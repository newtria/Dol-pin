import assert from 'node:assert/strict';
import {test} from 'node:test';
import {createApi} from '../packages/api-client/src/index.ts';

function catalogueClient(result, calls = []) {
  return {
    rpc: async (name, args) => {calls.push({name, args}); return result;},
    from: () => {throw new Error('Public discovery must not fall back to owner-visible table rows');},
  };
}

test('missing catalogue migration fails consistently with and without filters', async () => {
  for (const filter of [{}, {search: '응원봉'}, {pickupArea: '잠실'}, {startsAt: '2099-10-18T01:00:00Z', endsAt: '2099-10-18T05:00:00Z'}]) {
    const client = catalogueClient({data: null, error: {code: 'PGRST202', message: 'Missing search RPC'}});
    await assert.rejects(createApi(client).items(filter), error => error.code === 'SERVICE_UNAVAILABLE');
  }
});

test('catalogue filters and cursor reach the database before pagination', async () => {
  const calls = [];
  const data = Array.from({length: 51}, (_, index) => ({id: String(index), created_at: '2099-10-01T00:00:00Z', photos: []}));
  const api = createApi(catalogueClient({data, error: null}, calls));
  const filter = {search: '  100%_응원봉  ', category: ' lightstick ', pickupArea: ' 잠실 ', startsAt: '2099-10-18T01:00:00Z', endsAt: '2099-10-18T05:00:00Z'};
  const cursor = {createdAt: '2099-10-02T00:00:00Z', id: 'before'};
  const page = await api.items(filter, cursor);
  assert.deepEqual(calls, [{name: 'search_rental_items', args: {
    p_concert_id: null, p_category: 'lightstick', p_search: '100%_응원봉', p_pickup_area: '잠실',
    p_starts_at: filter.startsAt, p_ends_at: filter.endsAt,
    p_before_created_at: cursor.createdAt, p_before_id: cursor.id,
  }}]);
  assert.equal(page.rows.length, 50);
  assert.equal(page.rows[49].id, '49');
  assert.deepEqual(page.nextCursor, {createdAt: data[49].created_at, id: '49'});
});

test('null timestamps retain a usable cursor and permission failures stay failures', async () => {
  const data = Array.from({length: 51}, (_, index) => ({id: String(index), created_at: null, photos: []}));
  const page = await createApi(catalogueClient({data, error: null})).items({});
  assert.deepEqual(page.nextCursor, {createdAt: '-infinity', id: '49'});
  const forbidden = createApi(catalogueClient({data: null, error: {code: '42501', message: 'Denied'}}));
  await assert.rejects(forbidden.items({}), error => error.code === '42501');
});
