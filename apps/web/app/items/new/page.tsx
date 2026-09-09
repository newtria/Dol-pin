'use client';
import {useState} from 'react';
import Link from 'next/link';
import {useRouter} from 'next/navigation';
import {useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation, useQueryClient} from '@tanstack/react-query';
import {itemInput, categories, categoryLabels, type ItemInput} from '@dolpin/contracts';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field, FieldGroup, FieldLabel, FieldDescription, FieldError} from '@/components/ui/field';
import {Select, SelectTrigger, SelectValue, SelectContent, SelectGroup, SelectItem} from '@/components/ui/select';
export default function NewItem() {
  const {client, api, session, ready} = useApi(); const router = useRouter(); const queries = useQueryClient();
  const [uploading, setUploading] = useState(false); const [uploadError, setUploadError] = useState<unknown>();
  const form = useForm<ItemInput>({resolver: zodResolver(itemInput), defaultValues: {title: '', description: '', category: 'lightstick', concert_id: null, daily_price: 5000, deposit: 30000, photos: [], pickup_method: 'direct'}});
  const photos = form.watch('photos');
  const create = useMutation({mutationFn: api.createItem, onSuccess: async item => {await queries.invalidateQueries({queryKey: ['items']}); router.replace(`/items/${item.id}`);}});
  async function upload(file?: File) {
    if (!file || !session || photos.length >= 5) return;
    setUploading(true); setUploadError(undefined);
    try {
      if (file.size > 5 * 1024 * 1024 || !['image/jpeg','image/png','image/webp'].includes(file.type)) throw new Error('5MB 이하의 JPG, PNG, WebP 사진을 선택해 주세요.');
      const path = `${session.user.id}/${crypto.randomUUID()}.${file.type.split('/')[1]}`;
      const {error} = await client.storage.from('product-photos').upload(path, file, {contentType: file.type}); if (error) throw error;
      const url = client.storage.from('product-photos').getPublicUrl(path).data.publicUrl;
      form.setValue('photos', [...photos, url], {shouldValidate: true});
    } catch (error) {setUploadError(error);} finally {setUploading(false);}
  }
  if (!ready) return <p>계정을 확인하고 있습니다.</p>;
  if (!session) return <section className="flex flex-col items-start gap-6"><h1 className="text-2xl font-bold">로그인 후 물품을 등록해 주세요.</h1><Button asChild><Link href="/account">로그인</Link></Button></section>;
  return <section className="mx-auto flex max-w-2xl flex-col gap-8"><h1 className="text-3xl font-bold">콘서트 물품 등록</h1><form onSubmit={form.handleSubmit(value => create.mutate(value))}><FieldGroup>
    <Field data-invalid={!!form.formState.errors.photos}><FieldLabel htmlFor="photos">상품 사진 ({photos.length}/5)</FieldLabel><FieldDescription>상품 사진은 누구나 볼 수 있습니다. 개인정보나 반납 증빙은 올리지 마세요.</FieldDescription><Input id="photos" type="file" accept="image/jpeg,image/png,image/webp" disabled={uploading || create.isPending || photos.length >= 5} onChange={e => {void upload(e.target.files?.[0]);}}/><FieldError errors={[form.formState.errors.photos]}/></Field>
    <div className="flex gap-4">{photos.map(src => <img key={src} src={src} alt="등록할 상품 사진" className="size-24 rounded-lg object-cover"/>)}</div><Failure error={uploadError}/>
    <Field data-invalid={!!form.formState.errors.title}><FieldLabel htmlFor="title">상품명</FieldLabel><Input id="title" aria-invalid={!!form.formState.errors.title} {...form.register('title')}/><FieldError errors={[form.formState.errors.title]}/></Field>
    <Field><FieldLabel htmlFor="category">품목</FieldLabel><Select value={form.watch('category')} onValueChange={v => form.setValue('category', v as ItemInput['category'])}><SelectTrigger id="category"><SelectValue/></SelectTrigger><SelectContent><SelectGroup>{categories.map(c => <SelectItem key={c} value={c}>{categoryLabels[c]}</SelectItem>)}</SelectGroup></SelectContent></Select></Field>
    <Field data-invalid={!!form.formState.errors.description}><FieldLabel htmlFor="description">상품 설명 · 인수 장소</FieldLabel><Input id="description" aria-invalid={!!form.formState.errors.description} {...form.register('description')}/><FieldError errors={[form.formState.errors.description]}/></Field>
    {(['daily_price','deposit'] as const).map(name => <Field key={name} data-invalid={!!form.formState.errors[name]}><FieldLabel htmlFor={name}>{name === 'daily_price' ? '하루 대여료 (원)' : '보증금 (원)'}</FieldLabel><Input id={name} type="number" aria-invalid={!!form.formState.errors[name]} {...form.register(name, {valueAsNumber: true})}/><FieldError errors={[form.formState.errors[name]]}/></Field>)}
    <p className="text-muted-foreground">직접 인수·반납하는 물품입니다.</p><Button disabled={uploading || create.isPending}>{uploading ? '사진 업로드 중' : create.isPending ? '등록 중' : '물품 등록'}</Button><Failure error={create.error}/>
  </FieldGroup></form></section>;
}
