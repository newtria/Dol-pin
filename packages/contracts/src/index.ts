import { z } from 'zod';
export type { Database } from './database';

export const categories = ['lightstick', 'phone', 'camera', 'slogan', 'costume', 'etc'] as const;
export const categoryLabels: Record<(typeof categories)[number], string> = {
  lightstick: '응원봉', phone: '휴대폰', camera: '카메라', slogan: '슬로건', costume: '의상', etc: '기타 콘서트 물품',
};
export const itemInput = z.object({
  title: z.string().trim().min(2, '상품명을 2자 이상 입력해 주세요').max(80),
  description: z.string().trim().max(2000),
  category: z.enum(categories),
  concert_id: z.uuid().nullable(),
  daily_price: z.number().int().min(100).max(1000000),
  deposit: z.number().int().min(0).max(3000000),
  photos: z.array(z.url()).min(1, '사진을 추가해 주세요').max(5),
  pickup_method: z.literal('direct'),
});
export type ItemInput = z.infer<typeof itemInput>;
export const phoneInput = z.object({phone: z.string().regex(/^\+82\d{9,10}$/, '+82로 시작하는 전화번호를 입력해 주세요')});
export const profileInput = z.object({nickname: z.string().trim().min(2).max(30)});
export const formatWon = (value: number) => `${new Intl.NumberFormat('ko-KR').format(value)}원`;
