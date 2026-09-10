import {z} from 'zod';

export const emailLoginInput = z.object({
  email: z.string().trim().email('이메일 주소를 확인해 주세요.'),
  password: z.string().min(1, '비밀번호를 입력해 주세요.'),
});
export const emailSignupInput = emailLoginInput.extend({
  password: z.string().min(8, '비밀번호를 8자 이상 입력해 주세요.').max(72, '비밀번호는 72자 이하로 입력해 주세요.'),
  confirmation: z.string(),
}).refine(input => input.password === input.confirmation, {
  path: ['confirmation'], message: '비밀번호가 일치하지 않습니다.',
});
