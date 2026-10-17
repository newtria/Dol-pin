'use client';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Input} from './ui/input';
export function DisputeEvidence({id,paths,canUpload}:{id:string;paths:string[];canUpload:boolean}){
 const {api,client,session}=useApi();const queries=useQueryClient();
 const upload=useMutation({mutationFn:async(file:File)=>{if(!session)throw {code:'AUTH_REQUIRED'};if(file.size>5*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type))throw {code:'UNSUPPORTED_MEDIA'};const path=`${id}/${session.user.id}/${crypto.randomUUID()}.${file.type.split('/')[1]}`;const {error}=await client.storage.from('dispute-evidence').upload(path,file,{contentType:file.type});if(error)throw error;await api.addDisputeEvidence(id,path);},onSuccess:()=>queries.invalidateQueries({queryKey:['disputes',id]})});
 return <div className="mt-3 flex flex-col gap-3">{paths.map(path=><EvidenceImage key={path} path={path}/>)}{canUpload?<label className="text-sm font-medium">분쟁 증빙 추가 ({paths.length}/10)<p className="my-2 text-xs font-normal leading-5 text-muted-foreground">JPG·PNG·WebP, 장당 5MB 이하. 거래 당사자와 운영 검토 담당자만 볼 수 있습니다.</p><Input type="file" accept="image/jpeg,image/png,image/webp" disabled={upload.isPending||paths.length>=10} onChange={e=>{const file=e.target.files?.[0];if(file)upload.mutate(file);e.target.value='';}}/></label>:null}{upload.isPending?<p role="status" className="text-sm">증빙 사진을 저장하고 있습니다.</p>:null}<Failure error={upload.error}/></div>;
}
function EvidenceImage({path}:{path:string}){const {api,session}=useApi();const url=useQuery({queryKey:['dispute-evidence',path,session?.user.id],queryFn:()=>api.disputeEvidenceUrl(path),staleTime:240000,gcTime:0});return <>{url.data?<img src={url.data} alt="분쟁 증빙" className="max-h-72 rounded-xl bg-muted object-contain"/>:null}<Failure error={url.error}/></>;}
