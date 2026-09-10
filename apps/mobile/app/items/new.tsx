import {useState} from 'react';
import {Image, ScrollView, Text, View} from 'react-native';
import {router} from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import {Controller, useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation, useQueryClient} from '@tanstack/react-query';
import {categories, categoryLabels, itemInput, type ItemInput} from '@dolpin/contracts';
import {api, client} from '../../src/client';
import {useSession} from '../../src/session';
import {Button, ErrorText, Field, s} from '../../src/ui';

export default function NewItem() {
  const {session} = useSession();
  const queries = useQueryClient();
  const [photoError, setPhotoError] = useState<unknown>();
  const [uploading, setUploading] = useState(false);
  const form = useForm<ItemInput>({resolver: zodResolver(itemInput), defaultValues: {
    title: '', description: '', category: 'lightstick', concert_id: null,
    daily_price: 5000, deposit: 30000, photos: [], pickup_method: 'direct', pickup_note: '',
  }});
  const photos = form.watch('photos');
  const category = form.watch('category');
  const create = useMutation({mutationFn: api.createItem, onSuccess: async item => {
    await queries.invalidateQueries({queryKey: ['items']}); router.replace(`/items/${item.id}`);
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
  return <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
    <Text style={s.title}>콘서트 물품 등록</Text>
    <Text style={s.muted}>상품 사진은 누구나 볼 수 있습니다. 개인정보나 반납 증빙은 올리지 마세요.</Text>
    <ScrollView horizontal contentContainerStyle={{gap: 12}}>{photos.map(uri => <Image key={uri} source={{uri}} style={{width: 100, height: 100, borderRadius: 12}}/>)}</ScrollView>
    <Button label={uploading ? '사진 업로드 중' : `사진 추가 (${photos.length}/5)`} onPress={() => {void addPhoto();}} disabled={uploading || create.isPending || photos.length >= 5} secondary/>
    <ErrorText error={photoError ?? form.formState.errors.photos?.message}/>
    <Controller control={form.control} name="title" render={({field}) => <Field label="상품명" value={field.value} onChangeText={field.onChange}/>}/>
    <ErrorText error={form.formState.errors.title?.message}/>
    <Text style={s.muted}>품목</Text><ScrollView horizontal contentContainerStyle={{gap: 8}}>{categories.map(c => <Button key={c} label={categoryLabels[c]} secondary={category !== c} onPress={() => form.setValue('category', c)}/>)}</ScrollView>
    <Controller control={form.control} name="description" render={({field}) => <Field label="상품 설명" multiline value={field.value} onChangeText={field.onChange}/>}/>
    <ErrorText error={form.formState.errors.description?.message}/>
    <Controller control={form.control} name="pickup_note" render={({field}) => <Field label="인수·반납 장소" value={field.value} onChangeText={field.onChange}/>}/>
    <ErrorText error={form.formState.errors.pickup_note?.message}/>
    {(['daily_price', 'deposit'] as const).map(name => <View key={name} style={{gap: 8}}><Controller control={form.control} name={name} render={({field}) => <Field label={name === 'daily_price' ? '하루 대여료 (원)' : '보증금 (원)'} keyboardType="number-pad" value={String(field.value)} onChangeText={v => field.onChange(v === '' ? 0 : Number(v))}/>}/><ErrorText error={form.formState.errors[name]?.message}/></View>)}
    <Text style={s.muted}>직접 인수·반납하는 물품입니다.</Text>
    <Button label={create.isPending ? '등록 중' : '물품 등록'} disabled={create.isPending || uploading} onPress={form.handleSubmit(value => create.mutate(value))}/>
    <ErrorText error={create.error}/>
  </ScrollView>;
}
