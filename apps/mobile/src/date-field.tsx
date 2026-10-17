import {useEffect,useState} from 'react';
import {Pressable,ScrollView,Text,View} from 'react-native';
import {Button,s,colors} from './ui';
type BlockedPeriod={starts_at:string;ends_at:string};
/** Calendar arithmetic uses UTC; values are wall-clock dates in Korea. */
export function DateField({label,value,onChange,disabled=false,dateOnly=false,clearable=false,minDate,maxDate,blockedPeriods=[],periodEnd=false}:{label:string;value:string;onChange:(value:string)=>void;disabled?:boolean;dateOnly?:boolean;clearable?:boolean;minDate?:string;maxDate?:string;blockedPeriods?:readonly BlockedPeriod[];periodEnd?:boolean}) {
 const today=new Date(Date.now()+9*3600000).toISOString().slice(0,10);
 const [open,setOpen]=useState(false);const [month,setMonth]=useState((value||minDate||today).slice(0,7));
 useEffect(()=>{if(value)setMonth(value.slice(0,7));},[value.slice(0,7)]);
 const [year,monthNumber]=month.split('-').map(Number);
 const first=new Date(Date.UTC(year,monthNumber-1,1));const count=new Date(Date.UTC(year,monthNumber,0)).getUTCDate();
 const date=value.slice(0,10),time=value.slice(11)||'10:00';
 function move(amount:number){setMonth(new Date(Date.UTC(year,monthNumber-1+amount,1)).toISOString().slice(0,7));}
 function choose(next:string,selectedTime?:string){onChange(dateOnly?next:`${next}T${selectedTime??time}`);if(dateOnly)setOpen(false);}
 return <View style={{gap:10}}><Text style={s.label}>{label}</Text><Pressable accessibilityRole="button" accessibilityLabel={`${label}: ${value.replace('T',' ')||'날짜와 시간 선택'}`} accessibilityState={{expanded:open,disabled}} disabled={disabled} onPress={()=>setOpen(!open)} style={[s.input,s.row,{justifyContent:'space-between',opacity:disabled?0.5:1}]}><Text style={[s.body,{color:value?colors.text:colors.muted}]}>{value.replace('T',' ')||'날짜 선택'}</Text><Text style={{color:colors.primary}}>{open?'접기':'변경'}</Text></Pressable>
  {open?<View style={[s.card,{padding:8}]}><View style={[s.row,{justifyContent:'space-between'}]}><Pressable accessibilityRole="button" accessibilityLabel="이전 달" disabled={disabled} onPress={()=>move(-1)} style={{padding:12,minHeight:44}}><Text style={s.body}>‹</Text></Pressable><Text style={s.heading}>{year}년 {monthNumber}월</Text><Pressable accessibilityRole="button" accessibilityLabel="다음 달" disabled={disabled} onPress={()=>move(1)} style={{padding:12,minHeight:44}}><Text style={s.body}>›</Text></Pressable></View><View style={{flexDirection:'row',flexWrap:'wrap'}}>{['일','월','화','수','목','금','토'].map(day=><Text key={day} style={[s.muted,{width:'14.28%',textAlign:'center',marginBottom:8}]}>{day}</Text>)}{Array.from({length:first.getUTCDay()+count},(_,index)=>{
    const day=index-first.getUTCDay()+1;if(day<1)return <View key={index} style={{width:'14.28%',height:48}}/>;
    const next=`${month}-${String(day).padStart(2,'0')}`;
    const dayStart=Date.parse(`${next}T00:00:00+09:00`),dayEnd=dayStart+86400000;
    const booked=blockedPeriods.some(slot=>Date.parse(slot.starts_at)<dayEnd&&Date.parse(slot.ends_at)>dayStart);
    const intervals=blockedPeriods.map(slot=>({start:Date.parse(slot.starts_at),end:Date.parse(slot.ends_at)})).filter(slot=>slot.start<dayEnd&&slot.end>dayStart).sort((a,b)=>a.start-b.start);
    let covered=dayStart;let coversStart=false;
    for(const slot of intervals){if(slot.start>covered)break;if(covered===dayStart)coversStart=periodEnd?slot.start<dayStart:slot.start<=dayStart;covered=Math.max(covered,slot.end);}
    // A return at the exact start of another reservation remains valid.
    const full=coversStart&&covered>=dayEnd;
    const midnightOnly=periodEnd&&!coversStart&&covered>=dayEnd;
    const unavailable=disabled||!!(minDate&&next<minDate.slice(0,10))||!!(maxDate&&next>maxDate.slice(0,10))||full;
    const selected=date===next;
    return <Pressable key={next} accessibilityRole="button" accessibilityLabel={`${next}${midnightOnly?' 자정 반납만 가능':booked?' 예약된 시간 있음':''}`} accessibilityState={{selected,disabled:unavailable}} disabled={unavailable} onPress={()=>choose(next,midnightOnly?'00:00':undefined)} style={{width:'14.28%',minHeight:48,alignItems:'center',justifyContent:'center',borderRadius:12,backgroundColor:selected?colors.primary:'transparent',opacity:unavailable?0.3:1}}><Text style={[s.body,{color:selected?colors.onPrimary:colors.text}]}>{day}</Text>{booked?<View style={{width:4,height:4,borderRadius:2,backgroundColor:selected?colors.onPrimary:colors.primary}}/>:null}</Pressable>;
  })}</View>
  {blockedPeriods.length?<Text style={s.muted}>날짜 아래 점은 예약된 시간이 있다는 뜻입니다. 자정에만 반납할 수 있는 날짜는 00:00이 자동으로 선택됩니다.</Text>:null}
  {!dateOnly&&date?<><Text style={s.label}>시각 · 한국 시간</Text><ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{gap:6}}>{Array.from({length:24},(_,hour)=><Button key={hour} label={`${hour}시`} secondary={Number(time.slice(0,2))!==hour} disabled={disabled} onPress={()=>onChange(`${date}T${String(hour).padStart(2,'0')}:${time.slice(3)}`)}/>)}</ScrollView><View style={{flexDirection:'row',gap:6,flexWrap:'wrap'}}>{[0,15,30,45].map(minute=><Button key={minute} label={`${minute}분`} secondary={Number(time.slice(3))!==minute} disabled={disabled} onPress={()=>onChange(`${date}T${time.slice(0,2)}:${String(minute).padStart(2,'0')}`)}/>)}</View><Button label="이 날짜와 시간 선택" disabled={disabled} onPress={()=>setOpen(false)}/></>:null}</View>:null}
  {clearable&&value?<Button label={`${label} 해제`} secondary disabled={disabled} onPress={()=>onChange('')}/>:null}
 </View>;
}
