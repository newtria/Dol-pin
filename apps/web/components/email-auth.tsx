'use client';

import {useRef, useState, type FormEvent} from 'react';
import {useMutation} from '@tanstack/react-query';
import {emailLoginInput, emailSignupInput} from '@dolpin/contracts/email-auth';
import {useApi} from '@/lib/providers';
import {Failure} from '@/lib/feedback';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Field, FieldError, FieldGroup, FieldLabel} from '@/components/ui/field';

type Mode = 'login' | 'signup';
type Credentials = {email: string; password: string; mode: Mode};

export function EmailAuth({disabled, onBusyChange}: {disabled: boolean; onBusyChange: (busy: boolean) => void}) {
  const {client} = useApi();
  const [mode, setMode] = useState<Mode>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [pendingEmail, setPendingEmail] = useState<string>();
  const [notice, setNotice] = useState('');
  const [resendAfter, setResendAfter] = useState(0);
  // A ref closes the double-submit window before React renders isPending.
  const submitting = useRef(false);
  const redirectTo = () => `${window.location.origin}/auth/callback`;
  function settled() {submitting.current = false; onBusyChange(false);}

  const auth = useMutation({
    mutationFn: async (input: Credentials) => {
      if (input.mode === 'login') {
        const {error} = await client.auth.signInWithPassword({email: input.email, password: input.password});
        if (error) throw error;
        return {confirmationRequired: false};
      }
      const {data, error} = await client.auth.signUp({email: input.email, password: input.password, options: {emailRedirectTo: redirectTo()}});
      if (error) throw error;
      return {confirmationRequired: !data.session};
    },
    onSuccess: (result, input) => {
      setPassword(''); setConfirmation('');
      if (result.confirmationRequired) {
        setPendingEmail(input.email);
        setNotice('확인 메일을 보냈습니다. 메일의 링크로 가입을 확인해 주세요. 이미 가입한 이메일이라면 로그인해 주세요.');
        setResendAfter(Date.now() + 60_000);
        setMode('login');
      }
    },
    onError: (error, input) => {
      if ('code' in error && error.code === 'email_not_confirmed') setPendingEmail(input.email);
    },
    onSettled: settled,
  });
  const resend = useMutation({
    mutationFn: async (address: string) => {
      const {error} = await client.auth.resend({type: 'signup', email: address, options: {emailRedirectTo: redirectTo()}});
      if (error) throw error;
    },
    onSuccess: () => {
      setNotice('확인 메일을 다시 보냈습니다. 받은편지함과 스팸함을 확인해 주세요.');
      setResendAfter(Date.now() + 60_000);
    },
    onSettled: settled,
  });
  const busy = disabled || auth.isPending || resend.isPending;

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || submitting.current) return;
    const parsed = (mode === 'signup' ? emailSignupInput : emailLoginInput).safeParse({email, password, confirmation});
    if (!parsed.success) {setErrors(Object.fromEntries(parsed.error.issues.map(issue => [String(issue.path[0]), issue.message]))); return;}
    setErrors({}); setNotice(''); resend.reset();
    submitting.current = true; onBusyChange(true);
    auth.mutate({...parsed.data, mode});
  }
  function resendConfirmation() {
    if (busy || submitting.current || !pendingEmail) return;
    if (Date.now() < resendAfter) {setNotice('확인 메일을 보낸 지 얼마 되지 않았습니다. 잠시 후 다시 시도해 주세요.'); return;}
    setNotice(''); auth.reset();
    submitting.current = true; onBusyChange(true);
    resend.mutate(pendingEmail);
  }
  function switchMode() {
    if (busy || submitting.current) return;
    setMode(mode === 'login' ? 'signup' : 'login'); setPassword(''); setConfirmation(''); setErrors({});
    setNotice(''); auth.reset(); resend.reset();
  }
  function changeEmail(value: string) {
    setEmail(value); setPendingEmail(undefined); setNotice(''); auth.reset(); resend.reset();
  }

  return <div className="flex flex-col gap-4">
    <h2 className="text-lg font-semibold">{mode === 'login' ? '이메일로 로그인' : '이메일 회원가입'}</h2>
    <form onSubmit={submit} noValidate><FieldGroup>
      <Field data-invalid={!!errors.email}><FieldLabel htmlFor="email">이메일</FieldLabel><Input id="email" name="email" type="email" autoComplete="email" autoCapitalize="none" spellCheck={false} placeholder="name@example.com" value={email} onChange={event => changeEmail(event.target.value)} disabled={busy} aria-invalid={!!errors.email} aria-describedby={errors.email ? 'email-error' : undefined}/><FieldError id="email-error">{errors.email}</FieldError></Field>
      <Field data-invalid={!!errors.password}><FieldLabel htmlFor="password">비밀번호</FieldLabel><Input id="password" name="password" type="password" autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} placeholder={mode === 'signup' ? '8자 이상 입력해 주세요' : '비밀번호를 입력해 주세요'} value={password} onChange={event => setPassword(event.target.value)} disabled={busy} aria-invalid={!!errors.password} aria-describedby={errors.password ? 'password-error' : undefined}/><FieldError id="password-error">{errors.password}</FieldError></Field>
      {mode === 'signup' ? <Field data-invalid={!!errors.confirmation}><FieldLabel htmlFor="confirmation">비밀번호 확인</FieldLabel><Input id="confirmation" name="confirmation" type="password" autoComplete="new-password" value={confirmation} onChange={event => setConfirmation(event.target.value)} disabled={busy} aria-invalid={!!errors.confirmation} aria-describedby={errors.confirmation ? 'confirmation-error' : undefined}/><FieldError id="confirmation-error">{errors.confirmation}</FieldError></Field> : null}
      <Button type="submit" disabled={busy}>{auth.isPending ? '처리 중' : mode === 'login' ? '이메일 로그인' : '가입하기'}</Button>
    </FieldGroup></form>
    <Failure error={auth.error ?? resend.error}/>
    {notice ? <p role="status" className="text-sm leading-6">{notice}</p> : null}
    {pendingEmail ? <Button type="button" variant="outline" disabled={busy} onClick={resendConfirmation}>{resend.isPending ? '메일 보내는 중' : '확인 메일 다시 받기'}</Button> : null}
    <Button type="button" variant="link" disabled={busy} onClick={switchMode}>{mode === 'login' ? '처음이신가요? 이메일로 가입하기' : '이미 계정이 있나요? 로그인하기'}</Button>
  </div>;
}
