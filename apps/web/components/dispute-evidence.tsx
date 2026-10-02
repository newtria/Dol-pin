'use client';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Input} from './ui/input';
export function DisputeEvidence({id,paths,canUpload}:{id:string;paths:string[];canUpload:boolean}){
 const {api,client,session}=useApi();const queries=useQueryClient();
 const upload=useMutation({mutationFn:async(file:File)=>{if(!session)throw {code:'AUTH_REQUIRED'};if(file.size>5*1024*1024||!['image/jpeg','image/png','image/webp'].includes(file.type))throw {code:'UNSUPPORTED_MEDIA'};const path=`${id}/${session.user.id}/${crypto.randomUUID()}.${file.type.split('/')[1]}`;const {error}=await client.storage.from('dispute-evidence').upload(path,file,{contentType:file.type});if(error)throw error;await api.addDisputeEvidence(id,path);},onSuccess:()=>queries.invalidateQueries({queryKey:['disputes',id]})});
 return <div className="flex flex-col gap-3">{paths.map(path=><EvidenceImage key={path} path={path}/>)}{canUpload?<label>분쟁 증빙 추가 ({paths.length}/10)<Input type="file" accept="image/jpeg,image/png,image/webp" disabled={upload.isPending||paths.length>=10} onChange={e=>{const file=e.target.files?.[0];if(file)upload.mutate(file);e.target.value='';}}/></label>:null}<Failure error={upload.error}/></div>;
}
function EvidenceImage({path}:{path:string}){const {api,session}=useApi();const url=useQuery({queryKey:['dispute-evidence',path,session?.user.id],queryFn:()=>api.disputeEvidenceUrl(path),staleTime:240000,gcTime:0});return <>{url.data?<img src={url.data} alt="분쟁 증빙" className="max-h-72 object-contain"/>:null}<Failure error={url.error}/></>;}
