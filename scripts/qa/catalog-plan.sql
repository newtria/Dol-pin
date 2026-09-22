\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout='30s';
CREATE TEMP TABLE catalog_benchmark (LIKE public.rental_items INCLUDING ALL) ON COMMIT DROP;
-- Remove only the temporary clone's search index to compare the same data.
DO $$ DECLARE idx record; BEGIN
 FOR idx IN SELECT i.indexrelid::regclass AS name FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid JOIN pg_am a ON a.oid=c.relam
 WHERE i.indrelid='catalog_benchmark'::regclass AND a.amname='gin'
 LOOP EXECUTE format('DROP INDEX %s',idx.name); END LOOP;
END $$;
INSERT INTO catalog_benchmark(id,lender_id,title,description,category,daily_price,deposit,currency,status,created_at,photos,pickup_method)
SELECT gen_random_uuid(),'00000000-0000-4000-8000-000000000001'::uuid,
 '응원봉 '||n,repeat('상품 설명 ',20),'lightstick',5000,30000,'KRW','active',now()-n*interval '1 second',ARRAY['https://example.test/photo.jpg'],'direct'
FROM generate_series(1,100000) n;
ANALYZE catalog_benchmark;
\echo BASELINE_SEARCH_100K
EXPLAIN (ANALYZE,BUFFERS,TIMING OFF) SELECT * FROM catalog_benchmark WHERE status='active' AND title ILIKE '%99999%' ORDER BY created_at DESC,id DESC LIMIT 51;
EXPLAIN (ANALYZE,BUFFERS,TIMING OFF) SELECT * FROM catalog_benchmark WHERE status='active' AND title ILIKE '%99999%' ORDER BY created_at DESC,id DESC LIMIT 51;
CREATE INDEX catalog_benchmark_search ON catalog_benchmark USING gin(title extensions.gin_trgm_ops) WHERE status='active';
ANALYZE catalog_benchmark;
\echo INDEXED_SEARCH_100K
EXPLAIN (ANALYZE,BUFFERS,TIMING OFF) SELECT * FROM catalog_benchmark WHERE status='active' AND title ILIKE '%99999%' ORDER BY created_at DESC,id DESC LIMIT 51;
EXPLAIN (ANALYZE,BUFFERS,TIMING OFF) SELECT * FROM catalog_benchmark WHERE status='active' AND title ILIKE '%99999%' ORDER BY created_at DESC,id DESC LIMIT 51;
DO $$ DECLARE plan json; BEGIN
 EXECUTE $query$EXPLAIN (FORMAT JSON) SELECT * FROM catalog_benchmark WHERE status='active' AND title ILIKE '%99999%' ORDER BY created_at DESC,id DESC LIMIT 51$query$ INTO plan;
 IF plan::text NOT LIKE '%catalog_benchmark_search%' THEN RAISE EXCEPTION 'Selective search does not use the GIN index'; END IF;
 IF (SELECT count(*) FROM catalog_benchmark WHERE title ILIKE '%99999%')<>1 THEN RAISE EXCEPTION 'Search semantics changed'; END IF;
END $$;
ROLLBACK;
