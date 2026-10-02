import {useState,useEffect,useRef} from 'react';
import {DateField} from '../../src/date-field';
import {ConcertSelect} from '../../src/concert-select';
import {Image, ScrollView, Text, View} from 'react-native';
import {router,useLocalSearchParams} from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery, useQueryClient} from '@tanstack/react-query';
import {categories, categoryLabels, itemInput, type ItemInput} from '@dolpin/contracts';
import {api, client} from '../../src/client';
import {useSession} from '../../src/session';
import {Button,ValidationText, ErrorText, Field, s} from '../../src/ui';

export default function NewItem() {
  const {session}=useSession();const {edit}=useLocalSearchParams<{edit?:string}>();
  return <ItemEditor key={`${session?.user.id??'signed-out'}:${edit??'new'}`}/>;
}
function ItemEditor(){
  const {session} = useSession();
  const {edit}=useLocalSearchParams<{edit?:string}>();const initialized=useRef('');
  const existing=useQuery({queryKey:['edit-item',edit,session?.user.id],enabled:!!edit&&!!session,queryFn:async()=>{const [item,note]=await Promise.all([api.item(edit!),api.ownItemPickupNote(edit!)]);if(item.lender_id!==session!.user.id)throw new Error('수정 권한이 없습니다.');return {...item,pickup_note:note};}});
  const queries = useQueryClient();
  const [photoError, setPhotoError] = useState<unknown>();
  const [uploading, setUploading] = useState(false);
  const form = useForm<ItemInput>({resolver: zodResolver(itemInput), defaultValues: {
    title: '', description: '', category: 'lightstick', concert_id: null,
    daily_price: 5000, deposit: 30000, photos: [], pickup_method: 'direct', pickup_area: '', pickup_note: '',
  }});
  const photos = form.watch('photos');
  const category = form.watch('category');
  useEffect(()=>{const item=existing.data;if(item&&initialized.current!==item.id){form.reset({...item,description:item.description??'',pickup_method:'direct',pickup_area:item.pickup_area??'',pickup_note:item.pickup_note??'',category:item.category as ItemInput['category']});initialized.current=item.id;}},[existing.data,form]);
  const create = useMutation({mutationFn:(input:ItemInput)=>edit?api.updateItem(edit,input):api.createItem(input), onSuccess: async item => {
    await Promise.all([queries.invalidateQueries({queryKey:['items']}),queries.invalidateQueries({queryKey:['my-items']}),queries.invalidateQueries({queryKey:['item',item.id]})]); router.replace(`/items/${item.id}`);
  }});
  async function addPhoto() {
    if (!session || photos.length >= 5) return;
    setPhotoError(undefined); setUploading(true);
    try {
      const result = await ImagePicker.launchImageLibraryAsync({mediaTypes: ['images'], quality: 0.8, base64: true});
      if (result.canceled) return;
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
      form.setValue('photos', [...photos, url], {shouldValidate: true});
    } catch (error) {setPhotoError(error);} finally {setUploading(false);}
  }
  if (!session) return <View style={s.content}><Text style={s.heading}>로그인 후 물품을 등록해 주세요.</Text><Button label="로그인" onPress={() => router.push('/account')}/></View>;
  if(edit&&!existing.data)return <View style={s.content}><Text style={s.body}>물품을 확인하고 있습니다.</Text><ErrorText error={existing.error}/></View>;
  return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
    <Text style={s.title}>콘서트 물품 {edit?'수정':'등록'}</Text>
    <Text style={s.muted}>상품 사진은 누구나 볼 수 있습니다. 개인정보나 반납 증빙은 올리지 마세요.</Text>
    <ScrollView horizontal contentContainerStyle={{gap: 12}}>{photos.map((uri,index) => <View key={uri} style={{gap:8}}><Image source={{uri}} style={{width: 100, height: 100, borderRadius: 12}}/><Button label={`사진 ${index+1} 제거`} secondary disabled={create.isPending||uploading} onPress={()=>form.setValue('photos',photos.filter(p=>p!==uri),{shouldValidate:true})}/>{index>0?<Button label="앞으로" secondary onPress={()=>{const next=[...photos];[next[index-1],next[index]]=[next[index],next[index-1]];form.setValue('photos',next);}}/>:null}</View>)}</ScrollView>
    <Button label={uploading ? '사진 업로드 중' : `사진 추가 (${photos.length}/5)`} onPress={() => {void addPhoto();}} disabled={uploading || create.isPending || photos.length >= 5} secondary/>
    <ErrorText error={photoError}/><ValidationText error={form.formState.errors.photos?.message}/>
    <ConcertSelect value={form.watch('concert_id')} onChange={value=>form.setValue('concert_id',value)}/>
    {(['available_from','available_to'] as const).map(name=><View key={name}><DateField dateOnly clearable label={name==='available_from'?'대여 가능 시작일':'대여 가능 마지막 날'} value={form.watch(name)??''} onChange={value=>form.setValue(name,value||null,{shouldValidate:true})}/><ValidationText error={form.formState.errors[name]?.message}/></View>)}
    <Controller control={form.control} name="title" render={({field}) => <Field label="상품명" value={field.value} onChangeText={field.onChange}/>}/>
    <ValidationText error={form.formState.errors.title?.message}/>
    <Text style={s.muted}>품목</Text><ScrollView horizontal contentContainerStyle={{gap: 8}}>{categories.map(c => <Button key={c} label={categoryLabels[c]} secondary={category !== c} onPress={() => form.setValue('category', c)}/>)}</ScrollView>
    <Controller control={form.control} name="description" render={({field}) => <Field label="상품 설명" multiline value={field.value} onChangeText={field.onChange}/>}/>
    <ValidationText error={form.formState.errors.description?.message}/>
    <Controller control={form.control} name="pickup_area" render={({field}) => <Field label="공개할 만남 지역" value={field.value} onChangeText={field.onChange}/>}/>
    <Text style={s.muted}>공연장·역 이름처럼 대략적인 지역만 입력해 주세요. 상세 주소와 연락처는 공개하지 마세요.</Text>
    <ValidationText error={form.formState.errors.pickup_area?.message}/>
    <Controller control={form.control} name="pickup_note" render={({field}) => <Field label="상세 인수·반납 장소" value={field.value} onChangeText={field.onChange}/>}/>
    <Text style={s.muted}>예약을 수락한 거래 상대에게만 안내됩니다.</Text>
    <ValidationText error={form.formState.errors.pickup_note?.message}/>
    {(['daily_price', 'deposit'] as const).map(name => <View key={name} style={{gap: 8}}><Controller control={form.control} name={name} render={({field}) => <Field label={name === 'daily_price' ? '하루 대여료 (원)' : '보증금 (원)'} keyboardType="number-pad" value={String(field.value)} onChangeText={v => field.onChange(v === '' ? 0 : Number(v))}/>}/><ValidationText error={form.formState.errors[name]?.message}/></View>)}
    <Text style={s.muted}>직접 인수·반납하는 물품입니다.</Text>
    <Button label={create.isPending ? '저장 중' : edit?'수정 저장':'물품 등록'} disabled={create.isPending || uploading} onPress={form.handleSubmit(value => create.mutate(value))}/>
    <ErrorText error={create.error}/>
  </ScrollView>;
}
