import {checked,fixture,localSql} from './fixture.ts';
function assert(value:unknown,message:string):asserts value {if(!value)throw new Error(message);}

Deno.test('messages are participant scoped, idempotent, immutable and blocked at the database',async()=>{
 const f=await fixture();
 try{
  const rental=await f.rental();
  const request={p_reservation_id:rental.id,p_message:'거래 장소 확인 부탁드립니다.',p_request_id:crypto.randomUUID()};
  const first=checked(await f.borrower.client.rpc('send_rental_message',request));
  const retry=checked(await f.borrower.client.rpc('send_rental_message',request));
  assert(first.id===retry.id,'message retry duplicated');
  assert((await f.borrower.client.rpc('send_rental_message',{...request,p_message:'different'})).error,'idempotency identity changed');
  assert((await f.outsider.client.rpc('send_rental_message',{...request,p_request_id:crypto.randomUUID()})).error,'outsider sent message');
  assert(checked(await f.outsider.client.from('chat_messages').select('id').eq('id',first.id)).length===0,'outsider read message');
  assert((await f.borrower.client.from('chat_messages').update({message:'changed'}).eq('id',first.id)).error,'message content writable');
  checked(await f.lender.client.rpc('mark_rental_messages_read',{p_reservation_id:rental.id}));
  assert(checked(await f.borrower.client.from('chat_messages').select('read_at').eq('id',first.id).single()).read_at,'read receipt missing');
  checked(await f.lender.client.rpc('set_user_block',{p_user_id:f.borrower.id,p_blocked:true}));
  assert((await f.borrower.client.rpc('send_rental_message',{...request,p_request_id:crypto.randomUUID()})).error,'block not enforced');
  const notices=checked(await f.lender.client.from('notifications').select('id,body').eq('event_key',`message:${first.id}`));
  assert(notices.length===1,'notification duplicated');
  assert(!notices[0].body.includes(request.p_message),'push exposes message content');
 }finally{await f.cleanup();}
});

Deno.test('item commands enforce ownership, private listing, blocked reservations, and active accounts',async()=>{
 const f=await fixture();
 try{
  assert((await f.outsider.client.rpc('update_my_item',{p_item_id:f.item.id,p_input:{daily_price:100}})).error,'outsider edits item');
  assert((await f.lender.client.from('rental_items').update({daily_price:100}).eq('id',f.item.id)).error,'raw update bypass');
  checked(await f.lender.client.rpc('update_my_item',{p_item_id:f.item.id,p_input:{description:'새 설명',pickup_note:'새 상세 장소'}}));
  checked(await f.lender.client.rpc('set_my_item_status',{p_item_id:f.item.id,p_status:'hidden'}));
  assert(checked(await f.outsider.client.from('rental_items').select('id').eq('id',f.item.id)).length===0,'hidden listing exposed');
  assert(checked(await f.lender.client.rpc('my_items')).some((row:{id:string})=>row.id===f.item.id),'owner lost hidden item');
  checked(await f.lender.client.rpc('set_my_item_status',{p_item_id:f.item.id,p_status:'active'}));
  checked(await f.lender.client.rpc('set_user_block',{p_user_id:f.borrower.id,p_blocked:true}));
  const current=checked(await f.lender.client.from('rental_items').select('updated_at').eq('id',f.item.id).single());
  const request={p_item_id:f.item.id,p_starts_at:new Date(Date.now()+86400000).toISOString(),p_ends_at:new Date(Date.now()+90000000).toISOString(),p_item_version:current.updated_at,p_request_id:crypto.randomUUID()};
  assert((await f.borrower.client.rpc('request_rental',request)).error,'blocked reservation accepted');
  checked(await f.lender.client.rpc('set_user_block',{p_user_id:f.borrower.id,p_blocked:false}));
  await localSql(`UPDATE public.users SET suspended_at=now() WHERE id='${f.borrower.id}';`);
  assert((await f.borrower.client.rpc('request_rental',request)).error,'suspended account creates rental');
 }finally{await f.cleanup();}
});

Deno.test('account closure rejects open trades, anonymizes the profile, and blocks stale JWT requests',async()=>{
 const f=await fixture();
 try{
  await f.rental();
  assert((await f.admin.rpc('begin_account_closure',{p_user_id:f.borrower.id})).error?.code==='PCL01','open trade did not block closure');
  checked(await f.admin.rpc('begin_account_closure',{p_user_id:f.outsider.id}));
  checked(await f.admin.rpc('begin_account_closure',{p_user_id:f.outsider.id}));
  const profile=checked(await f.admin.from('users').select('nickname,phone,deleted_at').eq('id',f.outsider.id).single());
  assert(profile.deleted_at&&profile.phone===null&&profile.nickname==='탈퇴한 사용자','closure did not anonymize profile');
  assert((await f.outsider.client.rpc('get_chat_list',{p_user_id:f.outsider.id})).error,'stale JWT bypassed legacy definer guard');
  assert((await f.outsider.client.rpc('update_my_profile',{p_nickname:'reopen'})).error,'closed account reopened');
 }finally{await f.cleanup();}
});

Deno.test('push ownership, outbox leases and ambiguous delivery protect against duplicate or leaked pushes',async()=>{
 const f=await fixture();
 try{
  const token=`ExpoPushToken[${crypto.randomUUID().replaceAll('-','')}]`;
  checked(await f.lender.client.rpc('register_push_token',{p_token:token,p_enabled:true}));
  const rental=await f.rental();
  const lease=crypto.randomUUID();
  const delivery=checked(await f.admin.rpc('claim_notification_deliveries',{p_lease:lease})).find((row:{token:string})=>row.token===token);
  assert(delivery,'server event produced no push delivery');
  checked(await f.admin.rpc('finish_notification_delivery',{p_id:delivery.id,p_lease:crypto.randomUUID(),p_status:'sent'}));
  assert(checked(await f.admin.from('notification_deliveries').select('status').eq('id',delivery.id).single()).status==='sending','stale worker changed delivery');
  await localSql(`UPDATE public.notification_deliveries SET lease_until=now()-interval '1 second' WHERE id='${delivery.id}';`);
  checked(await f.admin.rpc('claim_notification_deliveries',{p_lease:crypto.randomUUID()}));
  assert(checked(await f.admin.from('notification_deliveries').select('status').eq('id',delivery.id).single()).status==='review','ambiguous send was replayed');
  checked(await f.outsider.client.rpc('register_push_token',{p_token:token,p_enabled:true}));
  assert(checked(await f.admin.from('notification_deliveries').select('id').eq('id',delivery.id)).length===0,'reassigned device retained prior user push');
  assert((await f.borrower.client.rpc('enqueue_notification',{p_user_id:f.outsider.id,p_event_key:'forged',p_kind:'message',p_body:'forged',p_reservation_id:rental.id})).error,'client forged push body');
 }finally{await f.cleanup();}
});

Deno.test('profile patch preserves omitted fields and permits explicit region clearing',async()=>{
 const f=await fixture();
 try{
  checked(await f.borrower.client.rpc('update_my_profile',{p_nickname:'새 이름',p_region:'서울',p_locale:'ja'}));
  const renamed=checked(await f.borrower.client.rpc('update_my_profile',{p_nickname:'다른 이름'}));
  assert(renamed.region==='서울'&&renamed.locale==='ja','nickname update erased profile preferences');
  const cleared=checked(await f.borrower.client.rpc('update_my_profile',{p_nickname:'다른 이름',p_region:null,p_update_region:true}));
  assert(cleared.region===null&&cleared.locale==='ja','explicit clear did not preserve locale');
 }finally{await f.cleanup();}
});

Deno.test('reports preserve transaction context and return an operator response to the reporter',async()=>{
 const f=await fixture();
 try{
  const rental=await f.rental();
  const input={p_user_id:f.lender.id,p_item_id:null,p_reason:'other',p_description:'약속 장소에 상대방이 도착하지 않았습니다.',p_reservation_id:rental.id};
  assert((await f.outsider.client.rpc('submit_report',input)).error,'outsider attached a private rental');
  checked(await f.borrower.client.rpc('submit_report',input));
  checked(await f.borrower.client.rpc('submit_report',input));
  const reports=checked(await f.borrower.client.from('reports').select('id,reservation_id').eq('reporter_id',f.borrower.id));
  assert(reports.length===1&&reports[0].reservation_id===rental.id,'report lost rental or duplicated');
  checked(await f.admin.auth.admin.updateUserById(f.outsider.id,{app_metadata:{dolpin_operator:true}}));
  checked(await f.admin.rpc('moderate_service',{p_actor:f.outsider.id,p_action:'resolved',p_target:reports[0].id,p_reason:'당사자에게 연락해 거래 약속을 확인했습니다.'}));
  const resolved=checked(await f.borrower.client.from('reports').select('status,resolution_note').eq('id',reports[0].id).single());
  assert(resolved.status==='resolved'&&resolved.resolution_note,'reporter cannot see the response');
  const notification=checked(await f.borrower.client.from('notifications').select('body').eq('kind','support'));
  assert(notification.length===1&&!notification[0].body.includes(resolved.resolution_note),'report response missing or exposed in push');
  await localSql(`UPDATE public.users SET suspended_at=now() WHERE id='${f.outsider.id}';`);
  assert((await f.admin.rpc('moderate_service',{p_actor:f.outsider.id,p_action:'item',p_target:f.item.id,p_value:true,p_reason:'검토 필요'})).error,'suspended operator retained moderation authority');
 }finally{await f.cleanup();}
});

Deno.test('general support preserves distinct requests and hidden listings can be released',async()=>{
 const f=await fixture();
 try{
  const request={p_user_id:null,p_item_id:null,p_reason:'other',p_description:'계정 설정 변경 방법이 궁금합니다.'};
  checked(await f.borrower.client.rpc('submit_report',request));
  checked(await f.borrower.client.rpc('submit_report',request));
  checked(await f.borrower.client.rpc('submit_report',{...request,p_description:'기기 알림을 받지 못하고 있습니다.'}));
  assert(checked(await f.borrower.client.from('reports').select('id').eq('reporter_id',f.borrower.id)).length===2,'support silently dropped distinct requests');
  checked(await f.admin.auth.admin.updateUserById(f.outsider.id,{app_metadata:{dolpin_operator:true}}));
  const moderation={p_actor:f.outsider.id,p_action:'item',p_target:f.item.id,p_reason:'신고 검토'};
  checked(await f.admin.rpc('moderate_service',{...moderation,p_value:true}));
  assert((await f.lender.client.rpc('set_my_item_status',{p_item_id:f.item.id,p_status:'active'})).error,'owner bypassed moderation');
  checked(await f.admin.rpc('moderate_service',{...moderation,p_value:false}));
  const hidden=checked(await f.lender.client.rpc('my_items')).find((item:{id:string})=>item.id===f.item.id);
  assert(hidden.status==='hidden'&&hidden.moderated_at===null,'release automatically published listing');
  checked(await f.lender.client.rpc('set_my_item_status',{p_item_id:f.item.id,p_status:'active'}));
 }finally{await f.cleanup();}
});
