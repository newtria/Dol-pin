'use client';
const buttons=[
 {provider:'kakao',label:'카카오 로그인',width:600,height:90},
 {provider:'custom:naver',label:'네이버 로그인',width:1472,height:224},
 {provider:'google',label:'Google로 로그인',width:564,height:132},
 {provider:'apple',label:'Apple로 로그인',width:960,height:156},
] as const;
export function SocialButtons({onClick,disabled}:{onClick:(provider:typeof buttons[number]['provider'])=>void;disabled:boolean}) {
 return <div className="flex flex-col gap-3">{buttons.map(button=><button key={button.provider} type="button" aria-label={button.label} disabled={disabled} onClick={()=>onClick(button.provider)} style={{backgroundColor:button.provider==='kakao'?'#FEE500':button.provider==='custom:naver'?'#03A94D':'#FFFFFF',border:button.provider==='google'?'1px solid #747775':'none'}} className="flex h-[52px] w-full shrink-0 cursor-pointer items-center justify-center overflow-hidden rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white disabled:cursor-wait">
 {/* Provider-supplied images are intentionally not restyled or distorted. */}
 {button.provider==='google'?<span aria-hidden="true" className="relative block h-[42px] w-[180px] overflow-hidden"><img src="/auth/google.png" alt="" width={188} height={44} className="absolute -left-1 -top-px h-11 w-[188px] max-w-none"/></span>:<img src={`/auth/${button.provider.replace('custom:','')}.png`} alt="" width={button.width} height={button.height} className="h-[52px] w-full object-contain"/>}
 </button>)}</div>;
}
