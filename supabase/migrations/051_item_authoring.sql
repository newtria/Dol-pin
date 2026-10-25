-- The request and its item commit together. A lost HTTP response can therefore
-- be retried without creating a second listing for the same physical item.
CREATE TABLE public.item_creation_requests (
 owner_id uuid NOT NULL REFERENCES public.users(id),
 request_id uuid NOT NULL,
 input_hash bytea NOT NULL,
 item_id uuid NOT NULL REFERENCES public.rental_items(id),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(owner_id,request_id)
);
ALTER TABLE public.item_creation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.item_creation_requests FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.item_creation_requests TO service_role;

-- Creation is a command, just like editing. Revoke both table and historical
-- column grants so clients cannot bypass required details or request identity.
REVOKE INSERT ON public.rental_items FROM authenticated;
REVOKE INSERT(id,lender_id,concert_id,category,title,description,photos,daily_price,currency,
 deposit,pickup_method,available_from,available_to,pickup_area,pickup_note) ON public.rental_items FROM authenticated;

CREATE FUNCTION public.valid_item_pickup_text(p_value jsonb,p_max_length integer) RETURNS text
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$
DECLARE value text;
BEGIN
 IF jsonb_typeof(p_value) IS DISTINCT FROM 'string' THEN
  RAISE EXCEPTION '만남 지역과 상세 장소를 입력해 주세요.' USING ERRCODE='22023';
 END IF;
 -- The same whitespace set as the client's String.trim(), independent of locale.
 value:=btrim(p_value#>>'{}',U&'\0009\000A\000B\000C\000D\0020\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF');
 IF length(value) NOT BETWEEN 2 AND p_max_length THEN
  RAISE EXCEPTION '만남 지역과 상세 장소를 입력해 주세요.' USING ERRCODE='22023';
 END IF;
 RETURN value;
END $$;
REVOKE ALL ON FUNCTION public.valid_item_pickup_text(jsonb,integer) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.create_my_item(p_request_id uuid,p_input jsonb)
RETURNS public.rental_items LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE actor uuid:=auth.uid(); request public.item_creation_requests; item public.rental_items; input public.rental_items; area text; note text;
BEGIN
 IF actor IS NULL THEN RAISE EXCEPTION '로그인이 필요합니다.' USING ERRCODE='42501'; END IF;
 IF p_request_id IS NULL OR jsonb_typeof(p_input) IS DISTINCT FROM 'object' OR EXISTS(
  SELECT 1 FROM jsonb_object_keys(p_input) k WHERE k NOT IN
  ('title','description','category','concert_id','daily_price','deposit','photos','pickup_method','pickup_area','pickup_note','available_from','available_to'))
 THEN RAISE EXCEPTION '등록할 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(actor::text||p_request_id::text,51));
 SELECT * INTO request FROM public.item_creation_requests WHERE owner_id=actor AND request_id=p_request_id;
 IF FOUND THEN
  IF request.input_hash IS DISTINCT FROM sha256(convert_to(p_input::text,'UTF8')) THEN
   RAISE EXCEPTION '같은 등록 요청의 내용을 변경할 수 없습니다.' USING ERRCODE='PIT01';
  END IF;
  SELECT * INTO item FROM public.rental_items WHERE id=request.item_id AND lender_id=actor;
  IF NOT FOUND THEN RAISE EXCEPTION '등록한 물품을 확인할 수 없습니다.' USING ERRCODE='42501'; END IF;
  RETURN item;
 END IF;
 PERFORM public.assert_active_account(actor);
 -- Legacy listings may have no meeting details. Every new listing must carry
 -- the same required public area and private instructions as the client form.
 area:=public.valid_item_pickup_text(p_input->'pickup_area',100);
 note:=public.valid_item_pickup_text(p_input->'pickup_note',300);
 input:=jsonb_populate_record(NULL::public.rental_items,p_input);
 input.pickup_area:=area;input.pickup_note:=note;
 INSERT INTO public.rental_items(lender_id,title,description,category,concert_id,daily_price,deposit,
  photos,currency,pickup_method,pickup_area,pickup_note,available_from,available_to)
 VALUES(actor,input.title,input.description,input.category,input.concert_id,input.daily_price,input.deposit,
  input.photos,'KRW',input.pickup_method,input.pickup_area,input.pickup_note,input.available_from,input.available_to)
 RETURNING * INTO item;
 INSERT INTO public.item_creation_requests(owner_id,request_id,input_hash,item_id)
 VALUES(actor,p_request_id,sha256(convert_to(p_input::text,'UTF8')),item.id);
 RETURN item;
END $$;
REVOKE ALL ON FUNCTION public.create_my_item(uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.create_my_item(uuid,jsonb) TO authenticated;

-- Read public fields, private instructions and their edit version in one
-- snapshot; combining two HTTP reads can pair an old note with a new version.
CREATE FUNCTION public.get_my_item(p_item_id uuid) RETURNS public.rental_items
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.rental_items;
BEGIN
 SELECT * INTO item FROM public.rental_items WHERE id=p_item_id AND lender_id=auth.uid();
 IF NOT FOUND THEN RAISE EXCEPTION '물품 수정 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 RETURN item;
END $$;
REVOKE ALL ON FUNCTION public.get_my_item(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_item(uuid) TO authenticated;

-- NOW() repeats within a transaction. Each listing change needs a distinct
-- version, including changes made by status/moderation commands.
CREATE FUNCTION public.touch_rental_item_version() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 NEW.updated_at:=greatest(clock_timestamp(),OLD.updated_at+interval '1 microsecond');
 RETURN NEW;
END $$;
DROP TRIGGER set_rental_items_updated_at ON public.rental_items;
CREATE TRIGGER set_rental_items_updated_at BEFORE UPDATE ON public.rental_items
 FOR EACH ROW EXECUTE FUNCTION public.touch_rental_item_version();
REVOKE ALL ON FUNCTION public.touch_rental_item_version() FROM PUBLIC,anon,authenticated;

-- No default or unversioned overload: old callers must refresh their editor.
DROP FUNCTION public.update_my_item(uuid,jsonb);
CREATE FUNCTION public.update_my_item(p_item_id uuid,p_input jsonb,p_expected_version timestamptz)
RETURNS public.rental_items LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE item public.rental_items; input public.rental_items; area text; note text;
BEGIN
 PERFORM public.assert_active_account();
 SELECT * INTO item FROM public.rental_items WHERE id=p_item_id AND lender_id=auth.uid() FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '물품 수정 권한이 없습니다.' USING ERRCODE='42501'; END IF;
 IF p_expected_version IS NULL OR item.updated_at IS DISTINCT FROM p_expected_version THEN
  RAISE EXCEPTION '물품 정보가 변경되었습니다. 최신 정보를 다시 불러와 주세요.' USING ERRCODE='PIV01';
 END IF;
 IF jsonb_typeof(p_input) IS DISTINCT FROM 'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_input) k WHERE k NOT IN
 ('title','description','category','concert_id','daily_price','deposit','photos','pickup_method','pickup_area','pickup_note','available_from','available_to'))
 THEN RAISE EXCEPTION '수정할 내용을 확인해 주세요.' USING ERRCODE='22023'; END IF;
 -- Omitted details preserve legacy NULLs; explicitly supplied details must
 -- satisfy the same contract as creation (including JSON types and whitespace).
 IF p_input ? 'pickup_area' THEN
  area:=public.valid_item_pickup_text(p_input->'pickup_area',100);
 END IF;
 IF p_input ? 'pickup_note' THEN
  note:=public.valid_item_pickup_text(p_input->'pickup_note',300);
 END IF;
 input:=jsonb_populate_record(item,p_input);
 IF p_input ? 'pickup_area' THEN input.pickup_area:=area; END IF;
 IF p_input ? 'pickup_note' THEN input.pickup_note:=note; END IF;
 IF input.pickup_method IS DISTINCT FROM 'direct' THEN RAISE EXCEPTION '직접 전달만 지원합니다.' USING ERRCODE='22023'; END IF;
 UPDATE public.rental_items SET title=input.title,description=input.description,category=input.category,
 concert_id=input.concert_id,daily_price=input.daily_price,deposit=input.deposit,photos=input.photos,
 pickup_method=input.pickup_method,pickup_area=input.pickup_area,pickup_note=input.pickup_note,
 available_from=input.available_from,available_to=input.available_to WHERE id=item.id RETURNING * INTO item;
 RETURN item;
END $$;
REVOKE ALL ON FUNCTION public.update_my_item(uuid,jsonb,timestamptz) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.update_my_item(uuid,jsonb,timestamptz) TO authenticated;
