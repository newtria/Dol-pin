'use client';
import {Suspense,useState,useEffect,useLayoutEffect,useRef} from 'react';
import {ApiRequestError,ItemRequestRetired,itemEditorQueryPolicy,freshItemForEditor,captureItemEditorSnapshot,type ItemEditorSnapshot,type ItemCreationRequest} from '@dolpin/api-client';
import {pendingItems} from '@/lib/pending-items';
import {accountHref} from '@/components/auth-return';
import {ConcertSelect} from '@/components/concert-select';
import Link from 'next/link';
import {useRouter,useSearchParams} from 'next/navigation';
import {useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery, useQueryClient} from '@tanstack/react-query';
import {itemInput, categories, categoryLabels, formatWon, type ItemInput} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field, FieldGroup, FieldLabel, FieldDescription, FieldError} from '@/components/ui/field';
import {Select, SelectTrigger, SelectValue, SelectContent, SelectGroup, SelectItem} from '@/components/ui/select';
export default function NewItem() {
  return <Suspense fallback={<p>물품을 확인하고 있습니다.</p>}><ItemEditorRoute/></Suspense>;
}
function ItemEditorRoute(){
  const {session}=useApi();const edit=useSearchParams().get('edit')??'';
  return <ItemEditor key={`${session?.user.id??'signed-out'}:${edit}`} edit={edit}/>;
}
function ItemEditor({edit}:{edit:string}){
  const {client, api, session, ready} = useApi(); const router = useRouter(); const queries = useQueryClient();
  const [uploading, setUploading] = useState(false); const [uploadError, setUploadError] = useState<unknown>();
  const initialized=useRef('');const mounted=useRef(false);
  const editorSnapshot=useRef<ItemEditorSnapshot|null>(null);const [reloading,setReloading]=useState(false);const [reloadError,setReloadError]=useState<unknown>();
  useLayoutEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  const [editorReady,setEditorReady]=useState(!edit);
  const [recovery,setRecovery]=useState<{owner:string;request:ItemCreationRequest|null}>();
  const [recoveryError,setRecoveryError]=useState<unknown>();const [recoveryAttempt,setRecoveryAttempt]=useState(0);const [startingNew,setStartingNew]=useState(false);
  const profile=useQuery({queryKey:['profile',session?.user.id],queryFn:()=>api.profile(session!.user.id),enabled:!!session});
  const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus,enabled:!!session});
  const returnTo=edit?`/items/new?edit=${edit}`:'/items/new';
  const existing=useQuery({queryKey:['edit-item',edit,session?.user.id],enabled:!!edit&&!!session,...itemEditorQueryPolicy,queryFn:()=>api.itemForEdit(edit)});
  const form = useForm<ItemInput>({resolver: zodResolver(itemInput), defaultValues: {title: '', description: '', category: 'lightstick', concert_id: null, daily_price: 5000, deposit: 30000, photos: [], pickup_method: 'direct', pickup_area: '', pickup_note: ''}});
  const photos = form.watch('photos');
  useEffect(()=>{const item=freshItemForEditor(existing);if(item&&initialized.current!==item.id){try{const snapshot=captureItemEditorSnapshot(item);form.reset(snapshot.input);editorSnapshot.current=snapshot;initialized.current=item.id;setEditorReady(true);}catch(error){setReloadError(error);}}},[existing.data,existing.isSuccess,existing.isFetchedAfterMount,existing.isFetching,form]);
  const recoveryReady=!!session&&recovery?.owner===session.user.id;
  const saved=recoveryReady?recovery.request:null;
  useEffect(()=>{
    if(edit||!session)return;let active=true;
    setRecovery(undefined);setRecoveryError(undefined);
    void pendingItems.read(session.user.id).then(request=>{if(active){if(request)form.reset(request.input);setRecovery({owner:session.user.id,request});}}).catch(error=>{if(active)setRecoveryError(error);});
    return()=>{active=false;};
  },[edit,session?.user.id,recoveryAttempt,form]);
  const create = useMutation({mutationFn:async(input:ItemInput)=>{
    if(!mounted.current||!session||uploading||!ready||!edit&&!recoveryReady)throw new ApiRequestError({code:'AUTH_REQUIRED'});
    if(edit)return api.updateItem(edit,input,editorSnapshot.current?.version??'');
    const owner=session.user.id;const request=saved??{requestId:crypto.randomUUID(),input:itemInput.parse(input)};
    setRecoveryError(undefined);setRecovery({owner,request});
    try{return await pendingItems.submit(owner,request,request=>{
      if(!mounted.current)throw new ApiRequestError({code:'AUTH_REQUIRED'});
      return api.createItem(request.input,request.requestId,owner);
    });}catch(error){
      if(mounted.current&&error instanceof ItemRequestRetired&&error.completedItemId)setRecovery({owner,request:{...request,completedItemId:error.completedItemId}});
      else if(mounted.current)try{const request=await pendingItems.read(owner);if(mounted.current)setRecovery({owner,request});}catch(recoveryError){if(mounted.current)setRecoveryError(recoveryError);}
      throw error;
    }
  },onSuccess:async item=>{
    if(!mounted.current)return;const {data,error}=await client.auth.getSession();
    if(!mounted.current||error||data.session?.user.id!==session?.user.id)return;
    if(edit){const snapshot=captureItemEditorSnapshot(item);form.reset(snapshot.input);editorSnapshot.current=snapshot;}
    queries.setQueryData(['edit-item',item.id,session!.user.id],item);
    if(!edit)setRecovery(current=>current?{...current,request:current.request?{...current.request,completedItemId:item.id}:null}:current);
    void queries.invalidateQueries({queryKey:['items']});void queries.invalidateQueries({queryKey:['my-items']});void queries.invalidateQueries({queryKey:['item',item.id]});
    router.replace(`/items/${item.id}`);
  }});
  async function reloadLatest(){
    if(!edit||reloading||create.isPending||uploading)return;setReloading(true);setReloadError(undefined);
    try{const result=await existing.refetch();if(result.error)throw result.error;const item=freshItemForEditor(result);if(!item)throw new ApiRequestError({code:'NOT_FOUND'});
      if(mounted.current){const snapshot=captureItemEditorSnapshot(item);form.reset(snapshot.input);editorSnapshot.current=snapshot;initialized.current=item.id;setEditorReady(true);create.reset();}}
    catch(error){if(mounted.current)setReloadError(error);}finally{if(mounted.current)setReloading(false);}
  }
  async function startNew(){
    if(!session||!saved?.completedItemId||startingNew)return;setStartingNew(true);setRecoveryError(undefined);
    try{await pendingItems.startNew(session.user.id,saved.requestId);if(mounted.current){form.reset({title:'',description:'',category:'lightstick',concert_id:null,daily_price:5000,deposit:30000,photos:[],pickup_method:'direct',pickup_area:'',pickup_note:'',available_from:null,available_to:null});setRecovery({owner:session.user.id,request:null});create.reset();}}
    catch(error){if(mounted.current)setRecoveryError(error);}finally{if(mounted.current)setStartingNew(false);}
  }
  async function upload(file?: File) {
    if (!file || !session || !mounted.current || uploading || create.isPending || saved || photos.length >= 5) return;
    setUploading(true); setUploadError(undefined);
    try {
      if (file.size > 5 * 1024 * 1024 || !['image/jpeg','image/png','image/webp'].includes(file.type)) throw new Error('5MB 이하의 JPG, PNG, WebP 사진을 선택해 주세요.');
      const path = `${session.user.id}/${crypto.randomUUID()}.${file.type.split('/')[1]}`;
      const {error} = await client.storage.from('product-photos').upload(path, file, {contentType: file.type}); if (error) throw error;
      const url = client.storage.from('product-photos').getPublicUrl(path).data.publicUrl;
      if(mounted.current)form.setValue('photos', [...photos, url], {shouldValidate: true});
    } catch (error) {if(mounted.current)setUploadError(error);} finally {if(mounted.current)setUploading(false);}
  }
  if (!ready) return <p>계정을 확인하고 있습니다.</p>;
  if (!session) return <section className="flex flex-col items-start gap-6"><h1 className="text-2xl font-bold">로그인 후 물품을 등록해 주세요.</h1><Button asChild><Link href={accountHref(returnTo)}>로그인하고 계속하기</Link></Button></section>;
  if(!edit&&!recoveryReady)return <section className="flex flex-col gap-4"><p role="status">이전에 저장한 물품 등록 요청을 확인하고 있습니다.</p><Failure error={recoveryError}/>{recoveryError?<Button onClick={()=>setRecoveryAttempt(value=>value+1)}>저장된 요청 다시 확인</Button>:null}<Link href="/items/mine">내 물품에서 등록 결과 확인</Link></section>;
  if(saved)return <section className="mx-auto flex max-w-lg flex-col gap-4 rounded-2xl border bg-card p-6"><h1 className="text-2xl font-bold">{saved.completedItemId?'등록한 물품이 있습니다':'이전 물품 등록 결과를 확인해 주세요'}</h1><p className="font-semibold">{saved.input.title}</p><p>입력한 내용과 사진을 보관했습니다. 같은 요청으로 확인해 중복 등록을 막습니다.</p>{saved.completedItemId?<><Button asChild><Link href={`/items/${saved.completedItemId}`}>등록한 물품 보기</Link></Button><Button variant="outline" disabled={startingNew||create.isPending} onClick={()=>void startNew()}>새 물품 등록</Button></>:<Button disabled={create.isPending} onClick={()=>create.mutate(saved.input)}>{create.isPending?'등록 결과 확인 중…':'등록 결과 다시 확인'}</Button>}<Failure error={recoveryError??create.error}/><Link href="/items/mine">내 물품 관리</Link></section>;
  if(consent.isPending||profile.isPending)return <p role="status">거래 이용 정보를 확인하고 있습니다.</p>;
  if(consent.isError||profile.isError)return <section><Failure error={consent.error??profile.error}/><Button onClick={()=>{void consent.refetch();void profile.refetch();}}>계정 정보 다시 확인</Button></section>;
  if(!profile.data||!consent.data?.accepted)return <section className="mx-auto flex max-w-lg flex-col items-start gap-4 rounded-2xl border bg-card p-6"><h1 className="text-2xl font-bold">물품 등록을 준비해 주세요</h1><p className="leading-7 text-muted-foreground">계정의 닉네임과 거래 이용 동의를 먼저 확인하면 물품을 등록할 수 있습니다.</p><Button asChild><Link href={accountHref(returnTo)}>계정 설정하고 계속하기</Link></Button></section>;
  if(reloading||edit&&!editorReady)return <section><p>최신 물품 정보를 확인하고 있습니다.</p><Failure error={reloadError??existing.error}/>{!reloading&&(existing.isError||reloadError)?<Button onClick={()=>void reloadLatest()}>물품 다시 확인</Button>:null}</section>;
  return <section className="mx-auto flex max-w-3xl flex-col gap-6"><Link href="/items/mine" className="w-fit text-sm font-medium text-muted-foreground">← 내 물품 관리</Link><header><p className="mb-2 text-sm font-semibold text-primary">내 물품 빌려주기</p><h1 className="text-3xl font-bold">콘서트 물품 {edit?'수정':'등록'}</h1><p className="mt-2 text-sm leading-6 text-muted-foreground">사진, 이용 조건, 만날 장소를 알려 주세요. 상세 장소는 예약 수락 후에만 공개됩니다.</p></header><form onSubmit={event=>{event.preventDefault();if(!uploading&&!create.isPending&&mounted.current)void form.handleSubmit(value=>{if(mounted.current)create.mutate(value);})(event);}}><fieldset disabled={create.isPending||uploading} className="flex flex-col gap-6">
    <section className="rounded-2xl border bg-card p-5 sm:p-6"><h2 className="mb-6 text-lg font-semibold">1. 어떤 물품인가요?</h2><FieldGroup>
    <Field data-invalid={!!form.formState.errors.photos}><FieldLabel htmlFor="photos">상품 사진 · {photos.length}/5</FieldLabel><FieldDescription>첫 사진이 대표 사진입니다. 전체 모습과 구성품, 흠집을 보여 주세요. JPG·PNG·WebP, 장당 5MB 이하.</FieldDescription><Input id="photos" type="file" accept="image/jpeg,image/png,image/webp" disabled={uploading||create.isPending||photos.length>=5} onChange={e=>{void upload(e.target.files?.[0]);e.target.value='';}}/><FieldError errors={[form.formState.errors.photos]}/></Field>
    {photos.length?<div className="grid grid-cols-2 gap-3 sm:grid-cols-3">{photos.map((src,index)=><div key={src} className="overflow-hidden rounded-xl border"><img src={src} alt={`상품 사진 ${index+1}${index===0?', 대표 사진':''}`} className="aspect-square w-full object-cover"/><div className="flex flex-col gap-2 p-2">{index===0?<span className="text-center text-xs font-semibold text-primary">대표 사진</span>:<Button type="button" variant="ghost" disabled={create.isPending||uploading} onClick={()=>{const next=[...photos];[next[0],next[index]]=[next[index],next[0]];form.setValue('photos',next,{shouldDirty:true});}}>대표 사진으로</Button>}<Button type="button" variant="outline" disabled={create.isPending||uploading} onClick={()=>form.setValue('photos',photos.filter(p=>p!==src),{shouldValidate:true,shouldDirty:true})}>사진 {index+1} 제거</Button></div></div>)}</div>:null}<Failure error={uploadError}/>{uploading?<p role="status" className="text-sm text-primary">사진을 업로드하고 있습니다.</p>:null}
    <Field data-invalid={!!form.formState.errors.title}><FieldLabel htmlFor="title">상품명</FieldLabel><Input id="title" maxLength={80} placeholder="예: 공식 응원봉 2세대 · 배터리 포함" aria-invalid={!!form.formState.errors.title} {...form.register('title')}/><FieldError errors={[form.formState.errors.title]}/></Field>
    <Field><FieldLabel htmlFor="category">품목</FieldLabel><Select value={form.watch('category')} onValueChange={v=>form.setValue('category',v as ItemInput['category'],{shouldDirty:true})}><SelectTrigger id="category"><SelectValue/></SelectTrigger><SelectContent><SelectGroup>{categories.map(c=><SelectItem key={c} value={c}>{categoryLabels[c]}</SelectItem>)}</SelectGroup></SelectContent></Select></Field>
    <Field data-invalid={!!form.formState.errors.description}><FieldLabel htmlFor="description">상품 설명</FieldLabel><textarea id="description" className="min-h-36 w-full rounded-xl border bg-background p-3 text-sm leading-6 focus-visible:outline-2 focus-visible:outline-ring" maxLength={2000} placeholder="구성품, 작동 상태, 사용 시 주의할 점을 알려 주세요." aria-invalid={!!form.formState.errors.description} {...form.register('description')}/><FieldDescription>상품 사진과 설명은 누구나 볼 수 있습니다. 개인정보와 연락처는 넣지 마세요.</FieldDescription><FieldError errors={[form.formState.errors.description]}/></Field>
    </FieldGroup></section>
    <section className="rounded-2xl border bg-card p-5 sm:p-6"><h2 className="mb-6 text-lg font-semibold">2. 대여 조건을 정해 주세요</h2><FieldGroup><div className="grid gap-5 sm:grid-cols-2">{(['daily_price','deposit'] as const).map(name=><Field key={name} data-invalid={!!form.formState.errors[name]}><FieldLabel htmlFor={name}>{name==='daily_price'?'하루 대여료 (원)':'보증금 (원)'}</FieldLabel><Input id={name} type="number" inputMode="numeric" min={name==='daily_price'?100:0} max={name==='daily_price'?1000000:3000000} step={1} aria-invalid={!!form.formState.errors[name]} {...form.register(name,{valueAsNumber:true})}/><FieldDescription>{name==='daily_price'?'24시간마다 부과되는 금액':'반납 확인 후 빌린 분에게 반환'}</FieldDescription><FieldError errors={[form.formState.errors[name]]}/></Field>)}</div><ConcertSelect value={form.watch('concert_id')} onChange={value=>form.setValue('concert_id',value,{shouldDirty:true})}/><div className="grid gap-5 sm:grid-cols-2">{(['available_from','available_to'] as const).map(name=><Field key={name}><FieldLabel htmlFor={name}>{name==='available_from'?'대여 가능 시작일':'대여 가능 마지막 날'}</FieldLabel><Input id={name} type="date" value={form.watch(name)??''} onChange={e=>form.setValue(name,e.target.value||null,{shouldValidate:true,shouldDirty:true})}/><FieldError errors={[form.formState.errors[name]]}/></Field>)}</div><p className="text-xs text-muted-foreground">공연과 날짜는 선택 사항입니다. 날짜를 비워 두면 대여 가능 기간을 제한하지 않습니다.</p></FieldGroup></section>
    <section className="rounded-2xl border bg-card p-5 sm:p-6"><h2 className="mb-6 text-lg font-semibold">3. 어디에서 만날까요?</h2><FieldGroup><Field data-invalid={!!form.formState.errors.pickup_area}><FieldLabel htmlFor="pickup_area">공개할 만남 지역</FieldLabel><FieldDescription>공연장·역 이름처럼 대략적인 지역만 입력하세요.</FieldDescription><Input id="pickup_area" maxLength={100} placeholder="예: 올림픽공원역 / KSPO DOME" {...form.register('pickup_area')}/><FieldError errors={[form.formState.errors.pickup_area]}/></Field><Field data-invalid={!!form.formState.errors.pickup_note}><FieldLabel htmlFor="pickup_note">상세 인수·반납 장소</FieldLabel><FieldDescription>예약을 수락한 거래 상대에게만 안내됩니다.</FieldDescription><textarea id="pickup_note" className="min-h-24 w-full rounded-xl border bg-background p-3 text-sm leading-6 focus-visible:outline-2 focus-visible:outline-ring" maxLength={300} placeholder="예: 공연 2시간 전 올림픽공원역 3번 출구에서 만나요. 반납도 같은 장소입니다." {...form.register('pickup_note')}/><FieldError errors={[form.formState.errors.pickup_note]}/></Field></FieldGroup></section>
    <div className="rounded-2xl border border-primary/20 bg-primary/5 p-5"><p className="text-sm leading-6">직접 인수·반납하는 물품입니다. {edit?'이미 수락한 거래의 조건은 변경되지 않습니다.':'예약 요청을 받으면 기간과 조건을 확인한 뒤 수락할 수 있습니다.'}</p><p className="mt-3 font-semibold">{Number.isFinite(form.watch('daily_price'))?formatWon(form.watch('daily_price')):'—'} / 24시간 · 보증금 {Number.isFinite(form.watch('deposit'))?formatWon(form.watch('deposit')):'—'}</p><Button className="mt-5 w-full" disabled={uploading||create.isPending}>{uploading?'사진 업로드 중…':create.isPending?'저장 중…':edit?'수정 저장':'물품 등록'}</Button><Failure error={create.error}/><Failure error={reloadError}/>{edit&&(create.error as {code?:string}|null)?.code==='PIV01'?<Button type="button" className="mt-3 w-full" variant="outline" disabled={uploading} onClick={()=>void reloadLatest()}>입력한 내용을 버리고 최신 정보 불러오기</Button>:null}</div>
  </fieldset></form></section>;
}
