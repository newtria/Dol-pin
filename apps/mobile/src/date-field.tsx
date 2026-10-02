import {useState} from 'react';
import {Pressable,ScrollView,Text,View} from 'react-native';
import {Button,s,colors} from './ui';
/** Calendar arithmetic uses UTC; values are wall-clock dates in Korea. */
export function DateField({label,value,onChange,disabled=false,dateOnly=false,clearable=false}:{label:string;value:string;onChange:(value:string)=>void;disabled?:boolean;dateOnly?:boolean;clearable?:boolean}) {
 const today=new Date(Date.now()+9*3600000).toISOString().slice(0,10);
 const [open,setOpen]=useState(false);const [month,setMonth]=useState((value||today).slice(0,7));
 const [year,monthNumber]=month.split('-').map(Number);
 const first=new Date(Date.UTC(year,monthNumber-1,1));const count=new Date(Date.UTC(year,monthNumber,0)).getUTCDate();
 const date=value.slice(0,10),time=value.slice(11)||'10:00';
 function move(amount:number){setMonth(new Date(Date.UTC(year,monthNumber-1+amount,1)).toISOString().slice(0,7));}
 function choose(day:number){const next=`${month}-${String(day).padStart(2,'0')}`;onChange(dateOnly?next:`${next}T${time}`);if(dateOnly)setOpen(false);}
 return <View style={{gap:10}}><Text style={s.muted}>{label}</Text><Button secondary label={value.replace('T',' ')||'날짜 선택'} disabled={disabled} onPress={()=>setOpen(!open)}/>
  {open?<><View style={s.row}><Button label="이전 달" secondary onPress={()=>move(-1)}/><Text style={s.body}>{year}년 {monthNumber}월</Text><Button label="다음 달" secondary onPress={()=>move(1)}/></View><View style={{flexDirection:'row',flexWrap:'wrap'}}>{['일','월','화','수','목','금','토'].map(day=><Text key={day} style={[s.muted,{width:'14.28%',textAlign:'center'}]}>{day}</Text>)}{Array.from({length:first.getUTCDay()+count},(_,index)=>{const day=index-first.getUTCDay()+1;return day<1?<View key={index} style={{width:'14.28%',height:44}}/>:<Pressable key={index} accessibilityRole="button" accessibilityLabel={`${month}-${String(day).padStart(2,'0')}`} disabled={disabled} onPress={()=>choose(day)} style={{width:'14.28%',height:44,alignItems:'center',justifyContent:'center',backgroundColor:date===`${month}-${String(day).padStart(2,'0')}`?colors.primary:'transparent'}}><Text style={s.body}>{day}</Text></Pressable>;})}</View>
  {!dateOnly&&date?<><Text style={s.muted}>시각 (한국 시간)</Text><ScrollView horizontal contentContainerStyle={{gap:6}}>{Array.from({length:24},(_,hour)=><Button key={hour} label={`${hour}시`} secondary={Number(time.slice(0,2))!==hour} disabled={disabled} onPress={()=>onChange(`${date}T${String(hour).padStart(2,'0')}:${time.slice(3)}`)}/>)}</ScrollView><ScrollView horizontal contentContainerStyle={{gap:6}}>{[0,15,30,45].map(minute=><Button key={minute} label={`${minute}분`} secondary={Number(time.slice(3))!==minute} disabled={disabled} onPress={()=>onChange(`${date}T${time.slice(0,2)}:${String(minute).padStart(2,'0')}`)}/>)}</ScrollView><Button label="선택 완료" onPress={()=>setOpen(false)}/></>:null}</>:null}
  {clearable&&value?<Button label={`${label} 제한 해제`} secondary disabled={disabled} onPress={()=>onChange('')}/>:null}
 </View>;
}
