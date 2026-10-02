'use client';
import {Suspense,useState,useEffect,useRef} from 'react';
import {ConcertSelect} from '@/components/concert-select';
import Link from 'next/link';
import {useRouter,useSearchParams} from 'next/navigation';
import {useForm} from 'react-hook-form';
import {zodResolver} from '@hookform/resolvers/zod';
import {useMutation,useQuery, useQueryClient} from '@tanstack/react-query';
import {itemInput, categories, categoryLabels, type ItemInput} from '@dolpin/contracts';
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
  const initialized=useRef('');
  const existing=useQuery({queryKey:['edit-item',edit,session?.user.id],enabled:!!edit&&!!session,queryFn:async()=>{const [item,note]=await Promise.all([api.item(edit!),api.ownItemPickupNote(edit!)]);if(item.lender_id!==session!.user.id)throw new Error('수정 권한이 없습니다.');return {...item,pickup_note:note};}});
  const form = useForm<ItemInput>({resolver: zodResolver(itemInput), defaultValues: {title: '', description: '', category: 'lightstick', concert_id: null, daily_price: 5000, deposit: 30000, photos: [], pickup_method: 'direct', pickup_area: '', pickup_note: ''}});
  const photos = form.watch('photos');
  useEffect(()=>{const item=existing.data;if(item&&initialized.current!==item.id){form.reset({...item,description:item.description??'',pickup_method:'direct',pickup_area:item.pickup_area??'',pickup_note:item.pickup_note??'',category:item.category as ItemInput['category']});initialized.current=item.id;}},[existing.data,form]);
  const create = useMutation({mutationFn:(input:ItemInput)=>edit?api.updateItem(edit,input):api.createItem(input), onSuccess: async item => {await Promise.all([queries.invalidateQueries({queryKey: ['items']}),queries.invalidateQueries({queryKey:['my-items']}),queries.invalidateQueries({queryKey:['item',item.id]})]);router.replace(`/items/${item.id}`);}});
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
  if(edit&&!existing.data)return <section><p>물품을 확인하고 있습니다.</p><Failure error={existing.error}/></section>;
  return <section className="mx-auto flex max-w-2xl flex-col gap-8"><h1 className="text-3xl font-bold">콘서트 물품 {edit?'수정':'등록'}</h1><form onSubmit={form.handleSubmit(value => create.mutate(value))}><FieldGroup>
    <Field data-invalid={!!form.formState.errors.photos}><FieldLabel htmlFor="photos">상품 사진 ({photos.length}/5)</FieldLabel><FieldDescription>상품 사진은 누구나 볼 수 있습니다. 개인정보나 반납 증빙은 올리지 마세요.</FieldDescription><Input id="photos" type="file" accept="image/jpeg,image/png,image/webp" disabled={uploading || create.isPending || photos.length >= 5} onChange={e => {void upload(e.target.files?.[0]);}}/><FieldError errors={[form.formState.errors.photos]}/></Field>
    <div className="flex flex-wrap gap-4">{photos.map((src,index) => <div key={src}><img src={src} alt="등록할 상품 사진" className="size-24 rounded-lg object-cover"/><Button type="button" variant="outline" disabled={create.isPending||uploading} onClick={()=>form.setValue('photos',photos.filter(p=>p!==src),{shouldValidate:true})}>사진 {index+1} 제거</Button>{index>0?<Button type="button" variant="outline" onClick={()=>{const next=[...photos];[next[index-1],next[index]]=[next[index],next[index-1]];form.setValue('photos',next);}}>앞으로</Button>:null}</div>)}</div><Failure error={uploadError}/>
    <ConcertSelect value={form.watch('concert_id')} onChange={value=>form.setValue('concert_id',value)}/>
    {(['available_from','available_to'] as const).map(name=><Field key={name}><FieldLabel htmlFor={name}>{name==='available_from'?'대여 가능 시작일':'대여 가능 마지막 날'}</FieldLabel><Input id={name} type="date" value={form.watch(name)??''} onChange={e=>form.setValue(name,e.target.value||null,{shouldValidate:true})}/><FieldDescription>비워 두면 날짜를 제한하지 않습니다.</FieldDescription><FieldError errors={[form.formState.errors[name]]}/></Field>)}
    <Field data-invalid={!!form.formState.errors.title}><FieldLabel htmlFor="title">상품명</FieldLabel><Input id="title" aria-invalid={!!form.formState.errors.title} {...form.register('title')}/><FieldError errors={[form.formState.errors.title]}/></Field>
    <Field><FieldLabel htmlFor="category">품목</FieldLabel><Select value={form.watch('category')} onValueChange={v => form.setValue('category', v as ItemInput['category'])}><SelectTrigger id="category"><SelectValue/></SelectTrigger><SelectContent><SelectGroup>{categories.map(c => <SelectItem key={c} value={c}>{categoryLabels[c]}</SelectItem>)}</SelectGroup></SelectContent></Select></Field>
    <Field data-invalid={!!form.formState.errors.description}><FieldLabel htmlFor="description">상품 설명</FieldLabel><Input id="description" aria-invalid={!!form.formState.errors.description} {...form.register('description')}/><FieldError errors={[form.formState.errors.description]}/></Field>
    <Field data-invalid={!!form.formState.errors.pickup_area}><FieldLabel htmlFor="pickup_area">공개할 만남 지역</FieldLabel><FieldDescription>공연장·역 이름처럼 대략적인 지역만 입력해 주세요. 상세 주소와 연락처는 공개하지 마세요.</FieldDescription><Input id="pickup_area" {...form.register('pickup_area')}/><FieldError errors={[form.formState.errors.pickup_area]}/></Field>
    <Field data-invalid={!!form.formState.errors.pickup_note}><FieldLabel htmlFor="pickup_note">상세 인수·반납 장소</FieldLabel><FieldDescription>예약을 수락한 거래 상대에게만 안내됩니다.</FieldDescription><Input id="pickup_note" {...form.register('pickup_note')}/><FieldError errors={[form.formState.errors.pickup_note]}/></Field>
    {(['daily_price','deposit'] as const).map(name => <Field key={name} data-invalid={!!form.formState.errors[name]}><FieldLabel htmlFor={name}>{name === 'daily_price' ? '하루 대여료 (원)' : '보증금 (원)'}</FieldLabel><Input id={name} type="number" aria-invalid={!!form.formState.errors[name]} {...form.register(name, {valueAsNumber: true})}/><FieldError errors={[form.formState.errors[name]]}/></Field>)}
    <p className="text-muted-foreground">직접 인수·반납하는 물품입니다. 이미 수락한 거래의 조건은 변경되지 않습니다.</p><Button disabled={uploading || create.isPending}>{uploading ? '사진 업로드 중' : create.isPending ? '저장 중' : edit?'수정 저장':'물품 등록'}</Button><Failure error={create.error}/>
  </FieldGroup></form></section>;
}
