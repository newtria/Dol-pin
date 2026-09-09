'use client';
const buttons=[
 {provider:'kakao',label:'카카오 로그인',width:600,height:90},
 {provider:'custom:naver',label:'네이버 로그인',width:1472,height:224},
 {provider:'google',label:'Google로 로그인',width:564,height:132},
 {provider:'apple',label:'Apple로 로그인',width:960,height:156},
] as const;
export function SocialButtons({onClick,disabled}:{onClick:(provider:typeof buttons[number]['provider'])=>void;disabled:boolean}) {
 return <div className="flex flex-col gap-3">{buttons.map(button=><button key={button.provider} type="button" aria-label={button.label} disabled={disabled} onClick={()=>onClick(button.provider)} className="flex min-h-12 w-full cursor-pointer items-center rounded-lg focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-white disabled:cursor-wait">
 {/* Provider-supplied images are intentionally not restyled or distorted. */}
 {button.provider==='google'?<span aria-hidden="true" className="block h-11 w-full overflow-hidden rounded border border-[#747775] bg-white"><span className="relative mx-auto block h-[42px] w-[180px] overflow-hidden"><img src="/auth/google.png" alt="" width={188} height={44} className="absolute -left-1 -top-px h-11 w-[188px] max-w-none"/></span></span>:<img src={`/auth/${button.provider.replace('custom:','')}.png`} alt="" width={button.width} height={button.height} className="h-auto w-full"/>}
 </button>)}</div>;
}
