import {useState,useEffect,useLayoutEffect,useRef,useCallback} from 'react';
import {ApiRequestError,ItemRequestRetired,itemEditorQueryPolicy,freshItemForEditor,captureItemEditorSnapshot,type ItemEditorSnapshot,type ItemCreationRequest} from '@dolpin/api-client';
import {randomUUID} from 'expo-crypto';
import {pendingItems} from '../../src/pending-items';
import {DateField} from '../../src/date-field';
import {ConcertSelect} from '../../src/concert-select';
import {Image, ScrollView, Text, View} from 'react-native';
import {router,useLocalSearchParams,useFocusEffect} from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery, useQueryClient} from '@tanstack/react-query';
import {categories, categoryLabels, itemInput, type ItemInput} from '@dolpin/contracts';
import {api, client} from '../../src/client';
import {useSession} from '../../src/session';
import {beginSignIn} from '../../src/auth-return';
import {Button,ValidationText, ErrorText, Field, EmptyState, Section, s} from '../../src/ui';

export default function NewItem() {
  const {session}=useSession();const {edit}=useLocalSearchParams<{edit?:string}>();
  return <ItemEditor key={`${session?.user.id??'signed-out'}:${edit??'new'}`}/>;
}
function ItemEditor(){
  const {session,ready} = useSession();
  const {edit}=useLocalSearchParams<{edit?:string}>();const initialized=useRef('');
  const editorSnapshot=useRef<ItemEditorSnapshot|null>(null);const [reloading,setReloading]=useState(false);const [reloadError,setReloadError]=useState<unknown>();
  const mounted=useRef(false);const focused=useRef(false);
  useLayoutEffect(()=>{mounted.current=true;return()=>{mounted.current=false;};},[]);
  useFocusEffect(useCallback(()=>{focused.current=true;return()=>{focused.current=false;};},[]));
  const [editorReady,setEditorReady]=useState(!edit);
  const [recovery,setRecovery]=useState<{owner:string;request:ItemCreationRequest|null}>();
  const [recoveryError,setRecoveryError]=useState<unknown>();const [recoveryAttempt,setRecoveryAttempt]=useState(0);const [startingNew,setStartingNew]=useState(false);
  const profile=useQuery({queryKey:['profile',session?.user.id],queryFn:()=>api.profile(session!.user.id),enabled:!!session});
  const consent=useQuery({queryKey:['consent',session?.user.id],queryFn:api.consentStatus,enabled:!!session});
  const returnTo=edit?`/items/new?edit=${edit}`:'/items/new';
  const existing=useQuery({queryKey:['edit-item',edit,session?.user.id],enabled:!!edit&&!!session,...itemEditorQueryPolicy,queryFn:()=>api.itemForEdit(edit!)});
  const queries = useQueryClient();
  const [photoError, setPhotoError] = useState<unknown>();
  const [uploading, setUploading] = useState(false);
  const form = useForm<ItemInput>({resolver: zodResolver(itemInput), defaultValues: {
    title: '', description: '', category: 'lightstick', concert_id: null,
    daily_price: 5000, deposit: 30000, photos: [], pickup_method: 'direct', pickup_area: '', pickup_note: '',
  }});
  const photos = form.watch('photos');
  const category = form.watch('category');
  useEffect(()=>{const item=freshItemForEditor(existing);if(item&&initialized.current!==item.id){try{const snapshot=captureItemEditorSnapshot(item);form.reset(snapshot.input);editorSnapshot.current=snapshot;initialized.current=item.id;setEditorReady(true);}catch(error){setReloadError(error);}}},[existing.data,existing.isSuccess,existing.isFetchedAfterMount,existing.isFetching,form]);
  const recoveryReady=!!session&&recovery?.owner===session.user.id;const saved=recoveryReady?recovery.request:null;
  useEffect(()=>{
    if(edit||!session)return;let active=true;setRecovery(undefined);setRecoveryError(undefined);
    void pendingItems.read(session.user.id).then(request=>{if(active){if(request)form.reset(request.input);setRecovery({owner:session.user.id,request});}}).catch(error=>{if(active)setRecoveryError(error);});
    return()=>{active=false;};
  },[edit,session?.user.id,recoveryAttempt,form]);
  const create = useMutation({mutationFn:async(input:ItemInput)=>{
    if(!mounted.current||!ready||!session||uploading||!edit&&!recoveryReady)throw new ApiRequestError({code:'AUTH_REQUIRED'});
    if(edit)return api.updateItem(edit,input,editorSnapshot.current?.version??'');
    const owner=session.user.id;const request=saved??{requestId:randomUUID(),input:itemInput.parse(input)};
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
    if(focused.current)router.replace(`/items/${item.id}`);
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
  async function addPhoto() {
    if (!session || !mounted.current || uploading || create.isPending || saved || photos.length >= 5) return;
    setPhotoError(undefined); setUploading(true);
    try {
      const result = await ImagePicker.launchImageLibraryAsync({mediaTypes: ['images'], quality: 0.8, base64: true});
      if (result.canceled||!mounted.current) return;
      const asset = result.assets[0];
      if (!asset.base64) throw new Error('사진을 읽지 못했습니다.');
      const bytes = Uint8Array.from(atob(asset.base64), c => c.charCodeAt(0));
      if (bytes.byteLength > 5 * 1024 * 1024) throw new Error('5MB 이하 사진을 선택해 주세요.');
      const mime = asset.mimeType ?? 'image/jpeg';
      if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) throw new Error('JPG, PNG, WebP 사진을 선택해 주세요.');
      const path = `${session.user.id}/${Date.now()}-${Math.random().toString(36).slice(2)}.${mime.split('/')[1]}`;
      const uploaded = await client.storage.from('product-photos').upload(path, bytes.buffer, {contentType: mime});
      if (uploaded.error) throw uploaded.error;
      const url = client.storage.from('product-photos').getPublicUrl(path).data.publicUrl;
      if(mounted.current)form.setValue('photos', [...photos, url], {shouldValidate: true});
    } catch (error) {if(mounted.current)setPhotoError(error);} finally {if(mounted.current)setUploading(false);}
  }
  if(!ready)return <View style={s.content}><Text style={s.body}>계정을 확인하고 있습니다.</Text></View>;
  if (!session) return <View style={s.content}><EmptyState title="내 물품을 빌려주세요" body="사진, 가격, 만남 장소를 등록하고 예약 요청을 받아보세요. 로그인 후 등록할 수 있습니다." action="로그인하고 등록하기" onAction={() => void beginSignIn(returnTo)}/></View>;
  if(!edit&&!recoveryReady)return <View style={s.content}><Text style={s.body}>이전에 저장한 물품 등록 요청을 확인하고 있습니다.</Text><ErrorText error={recoveryError} onRetry={()=>setRecoveryAttempt(value=>value+1)}/><Button secondary label="내 물품에서 등록 결과 확인" onPress={()=>router.push('/items/mine')}/></View>;
  if(saved)return <View style={s.content}><Text style={s.title}>{saved.completedItemId?'등록한 물품이 있습니다':'이전 물품 등록 결과를 확인해 주세요'}</Text><Text style={s.heading}>{saved.input.title}</Text><Text style={s.body}>입력한 내용과 사진을 보관했습니다. 같은 요청으로 확인해 중복 등록을 막습니다.</Text>{saved.completedItemId?<><Button label="등록한 물품 보기" onPress={()=>router.replace(`/items/${saved.completedItemId}`)}/><Button label="새 물품 등록" secondary disabled={startingNew||create.isPending} onPress={()=>void startNew()}/></>:<Button label={create.isPending?'등록 결과 확인 중…':'등록 결과 다시 확인'} disabled={create.isPending} onPress={()=>create.mutate(saved.input)}/>}<ErrorText error={recoveryError??create.error}/><Button secondary label="내 물품 관리" onPress={()=>router.push('/items/mine')}/></View>;
  if(profile.isPending||consent.isPending)return <View style={s.content}><Text style={s.body}>거래 이용 정보를 확인하고 있습니다.</Text></View>;
  if(profile.isError||consent.isError)return <View style={s.content}><ErrorText error={profile.error??consent.error} onRetry={()=>{void profile.refetch();void consent.refetch();}}/></View>;
  if(!profile.data||!consent.data?.accepted)return <View style={s.content}><EmptyState title="물품 등록을 준비해 주세요" body="프로필과 거래 이용 동의를 완료하면 등록 화면으로 돌아옵니다." action="계정 설정하고 계속하기" onAction={()=>void beginSignIn(returnTo)}/></View>;
  if(reloading||edit&&!editorReady)return <View style={s.content}><Text style={s.body}>최신 물품 정보를 확인하고 있습니다.</Text><ErrorText error={reloadError??existing.error} onRetry={reloading?undefined:()=>void reloadLatest()}/></View>;
  return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
    <Text style={s.title}>{edit?'물품 정보 수정':'내 물품 빌려주기'}</Text><Text style={s.muted}>등록한 물품과 대여 조건은 탐색 화면에 공개됩니다. 모든 금액은 원 기준입니다.</Text>
    <Section title="1. 물품 사진" description="첫 사진이 목록에 표시됩니다. 사진은 1~5장 올려주세요.">
    <Text style={s.muted}>상품 사진은 누구나 볼 수 있습니다. 개인정보나 반납 증빙은 올리지 마세요.</Text>
    <ScrollView horizontal contentContainerStyle={{gap: 12}}>{photos.map((uri,index) => <View key={uri} style={{gap:8}}><Image source={{uri}} accessibilityLabel={`상품 사진 ${index+1}`} style={{width: 100, height: 100, borderRadius: 12}}/><Button label={`사진 ${index+1} 제거`} secondary disabled={create.isPending||uploading} onPress={()=>form.setValue('photos',photos.filter(p=>p!==uri),{shouldValidate:true})}/>{index>0?<Button label="앞으로" secondary disabled={create.isPending||uploading} onPress={()=>{const next=[...photos];[next[index-1],next[index]]=[next[index],next[index-1]];form.setValue('photos',next);}}/>:null}</View>)}</ScrollView>
    <Button label={uploading ? '사진 업로드 중' : `사진 추가 (${photos.length}/5)`} onPress={() => {void addPhoto();}} disabled={uploading || create.isPending || photos.length >= 5} secondary/>
    <ErrorText error={photoError}/><ValidationText error={form.formState.errors.photos?.message}/>
    </Section><Section title="2. 공연과 대여 가능일" description="지정하지 않으면 날짜 제한 없이 표시됩니다."><ConcertSelect value={form.watch('concert_id')} onChange={value=>form.setValue('concert_id',value)}/>
    {(['available_from','available_to'] as const).map(name=><View key={name}><DateField dateOnly clearable label={name==='available_from'?'대여 가능 시작일':'대여 가능 마지막 날'} value={form.watch(name)??''} onChange={value=>form.setValue(name,value||null,{shouldValidate:true})}/><ValidationText error={form.formState.errors[name]?.message}/></View>)}
    </Section><Section title="3. 물품 소개"><Controller control={form.control} name="title" render={({field}) => <Field label="상품명" placeholder="예: 공식 응원봉 3세대 · 배터리 포함" value={field.value} onChangeText={field.onChange}/>}/>
    <ValidationText error={form.formState.errors.title?.message}/>
    <Text style={s.muted}>품목</Text><ScrollView horizontal contentContainerStyle={{gap: 8}}>{categories.map(c => <Button key={c} label={categoryLabels[c]} secondary={category !== c} onPress={() => form.setValue('category', c)}/>)}</ScrollView>
    <Controller control={form.control} name="description" render={({field}) => <Field label="상품 설명" placeholder="모델, 구성품, 사용 상태와 주의할 점을 알려주세요." multiline value={field.value} onChangeText={field.onChange}/>}/>
    <ValidationText error={form.formState.errors.description?.message}/>
    </Section><Section title="4. 만남 장소"><Controller control={form.control} name="pickup_area" render={({field}) => <Field label="공개할 만남 지역" value={field.value} onChangeText={field.onChange}/>}/>
    <Text style={s.muted}>공연장·역 이름처럼 대략적인 지역만 입력해 주세요. 상세 주소와 연락처는 공개하지 마세요.</Text>
    <ValidationText error={form.formState.errors.pickup_area?.message}/>
    <Controller control={form.control} name="pickup_note" render={({field}) => <Field label="상세 인수·반납 장소" value={field.value} onChangeText={field.onChange}/>}/>
    <Text style={s.muted}>예약을 수락한 거래 상대에게만 안내됩니다.</Text>
    <ValidationText error={form.formState.errors.pickup_note?.message}/>
    </Section><Section title="5. 대여료와 보증금" description="대여료는 24시간 단위로 계산됩니다. 보증금은 반납 확인 후 반환됩니다.">{(['daily_price', 'deposit'] as const).map(name => <View key={name} style={{gap: 8}}><Controller control={form.control} name={name} render={({field}) => <Field label={name === 'daily_price' ? '하루 대여료 (원)' : '보증금 (원)'} keyboardType="number-pad" value={String(field.value)} onChangeText={v => field.onChange(v === '' ? 0 : Number(v))}/>}/><ValidationText error={form.formState.errors[name]?.message}/></View>)}
    </Section><Text style={s.muted}>직접 인수·반납하는 물품입니다.</Text>
    <Button label={create.isPending ? '저장 중' : edit?'수정 저장':'물품 등록'} disabled={create.isPending || uploading} onPress={()=>{if(!create.isPending&&!uploading)void form.handleSubmit(value=>{if(mounted.current)create.mutate(value);})();}}/>
    <ErrorText error={create.error}/><ErrorText error={reloadError}/>
    {edit&&(create.error as {code?:string}|null)?.code==='PIV01'?<Button secondary disabled={uploading} label="입력한 내용을 버리고 최신 정보 불러오기" onPress={()=>void reloadLatest()}/>:null}
  </ScrollView>;
}
