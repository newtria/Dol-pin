-- One bounded counter per account/feature; concurrent Edge instances share it.
CREATE TABLE public.api_usage_limits (
 feature text PRIMARY KEY,per_minute integer NOT NULL CHECK(per_minute>0),per_day integer NOT NULL CHECK(per_day>0)
);
INSERT INTO public.api_usage_limits VALUES('gemini-analyze',3,30);
CREATE TABLE public.api_usage_counters (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 feature text NOT NULL REFERENCES public.api_usage_limits(feature),
 day_start date NOT NULL,day_count integer NOT NULL DEFAULT 0,
 minute_start timestamptz NOT NULL,minute_count integer NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id,feature)
);
ALTER TABLE public.api_usage_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_usage_counters ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.api_usage_limits,public.api_usage_counters FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.api_usage_limits,public.api_usage_counters TO service_role;
CREATE FUNCTION public.consume_api_quota(p_user_id uuid,p_feature text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE policy public.api_usage_limits; counter public.api_usage_counters; current_time_value timestamptz; current_day date; wait_seconds integer;
BEGIN
 SELECT * INTO policy FROM public.api_usage_limits WHERE feature=p_feature;
 IF p_user_id IS NULL OR policy.feature IS NULL THEN RAISE EXCEPTION 'Invalid quota request' USING ERRCODE='22023'; END IF;
 current_time_value:=clock_timestamp();current_day:=(current_time_value AT TIME ZONE 'UTC')::date;
 INSERT INTO public.api_usage_counters(user_id,feature,day_start,minute_start)
 VALUES(p_user_id,p_feature,current_day,current_time_value) ON CONFLICT DO NOTHING;
 SELECT * INTO counter FROM public.api_usage_counters WHERE user_id=p_user_id AND feature=p_feature FOR UPDATE;
 current_time_value:=clock_timestamp();current_day:=(current_time_value AT TIME ZONE 'UTC')::date;
 IF counter.day_start<>current_day THEN counter.day_count:=0;counter.day_start:=current_day; END IF;
 IF counter.minute_start+interval '1 minute'<=current_time_value THEN counter.minute_count:=0;counter.minute_start:=current_time_value; END IF;
 IF counter.day_count>=policy.per_day OR counter.minute_count>=policy.per_minute THEN
  wait_seconds:=greatest(1,ceil(extract(epoch FROM CASE WHEN counter.day_count>=policy.per_day
   THEN ((current_day+1)::timestamp AT TIME ZONE 'UTC') ELSE counter.minute_start+interval '1 minute' END-current_time_value))::integer);
  RETURN jsonb_build_object('allowed',false,'retryAfter',wait_seconds);
 END IF;
 UPDATE public.api_usage_counters SET day_start=counter.day_start,day_count=counter.day_count+1,
 minute_start=counter.minute_start,minute_count=counter.minute_count+1 WHERE user_id=p_user_id AND feature=p_feature;
 RETURN jsonb_build_object('allowed',true,'remaining',policy.per_day-counter.day_count-1);
END $$;
REVOKE ALL ON FUNCTION public.consume_api_quota(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.consume_api_quota(uuid,text) TO service_role;
