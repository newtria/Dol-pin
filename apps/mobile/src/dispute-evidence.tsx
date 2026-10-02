import {Image,View} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import {randomUUID} from 'expo-crypto';
import {useMutation,useQuery,useQueryClient} from '@tanstack/react-query';
import {api,client} from './client';
import {useSession} from './session';
import {Button,ErrorText} from './ui';
export function DisputeEvidence({id,paths,canUpload}:{id:string;paths:string[];canUpload:boolean}){
 const {session}=useSession();const queries=useQueryClient();
 const upload=useMutation({mutationFn:async()=>{if(!session)throw {code:'AUTH_REQUIRED'};const picked=await ImagePicker.launchImageLibraryAsync({mediaTypes:['images'],quality:0.8,base64:true});if(picked.canceled)return;const asset=picked.assets[0];if(!asset.base64)throw new Error('사진을 읽지 못했습니다.');const bytes=Uint8Array.from(atob(asset.base64),c=>c.charCodeAt(0));const mime=asset.mimeType??'image/jpeg';if(bytes.byteLength>5*1024*1024||!['image/jpeg','image/png','image/webp'].includes(mime))throw {code:'UNSUPPORTED_MEDIA'};const path=`${id}/${session.user.id}/${randomUUID()}.${mime.split('/')[1]}`;const {error}=await client.storage.from('dispute-evidence').upload(path,bytes.buffer,{contentType:mime});if(error)throw error;await api.addDisputeEvidence(id,path);},onSuccess:()=>queries.invalidateQueries({queryKey:['disputes',id]})});
 return <View style={{gap:12}}>{paths.map(path=><EvidenceImage key={path} path={path}/>)}{canUpload?<Button label={`분쟁 증빙 추가 (${paths.length}/10)`} secondary disabled={upload.isPending||paths.length>=10} onPress={()=>upload.mutate()}/>:null}<ErrorText error={upload.error}/></View>;
}
function EvidenceImage({path}:{path:string}){const {session}=useSession();const url=useQuery({queryKey:['dispute-evidence',path,session?.user.id],queryFn:()=>api.disputeEvidenceUrl(path),staleTime:240000,gcTime:0});return <>{url.data?<Image source={{uri:url.data}} accessibilityLabel="분쟁 증빙" style={{width:'100%',height:240}} resizeMode="contain"/>:null}<ErrorText error={url.error}/></>;}
