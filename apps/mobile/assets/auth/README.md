# Official sign-in artwork

Retrieved 2026-09-09. These provider-owned assets are used only for their respective authentication actions. Do not tint, redraw, replace logos with text characters, or distort them.

- Kakao: https://developers.kakao.com/tool/resource/static/img/button/login/full/ko/kakao_login_large_wide.png (600×90). Guide: https://developers.kakao.com/docs/ko/kakaologin/design-guide
- Naver: https://developers.naver.com/inc/devcenter/downloads/bi/NAVER_login_KR.zip — `NAVER_login_KR/NAVER_login_Dark_KR_green_wide_H56.png` (1472×224). Guide: https://developers.naver.com/docs/login/bi/bi.md. Current green: #03A94D.
- Google: https://developers.google.com/static/identity/images/signin-assets.zip — `iOS/PNG @3x/Light/Theme=Light, Show text=Yes, Shape=Square, Platform=iOS@3x.png` (564×132). Guide: https://developers.google.com/identity/branding-guidelines. The official logo and label render at their native 188×44 logical scale; the surrounding white container extends to the column width. Only blank edge/border pixels are occluded. No logo/text rescaling or tinting.
- Apple: https://appleid.cdn-apple.com/appleid/button?color=white&border=false&border_radius=8&width=320&height=52&type=sign-in&locale=ko_KR&scale=3 (960×156). Official REST button generator: https://developer.apple.com/documentation/signinwithapple/incorporating-sign-in-with-apple-into-other-platforms

`apps/web/public/auth/` contains the same bytes (Google's web filename omits @3x). All wrappers retain accessible button labels and the existing Supabase OAuth handlers. Pending requests disable repeat presses without recoloring the provider artwork.
