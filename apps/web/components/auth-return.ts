// Keep post-auth navigation on known app routes. Query strings may contain a
// reservation draft, but never credentials or an arbitrary external redirect.
export function safeReturnTo(value: string | null | undefined, fallback = '/account'): string {
  if (!value || !value.startsWith('/') || value.startsWith('//') || /[\\\u0000-\u001f\u007f]/.test(value)) return fallback;
  try {
    const url = new URL(value, 'https://dolpin.invalid');
    if (url.origin !== 'https://dolpin.invalid' || !/^\/(?:items(?:\/[^/]+(?:\/reserve)?)?|rentals(?:\/[^/]+)?|account(?:\/payouts)?|notifications|support|operations)\/?$/.test(url.pathname)) return fallback;
    return /^\/account\/?$/.test(url.pathname) ? '/account' : `${url.pathname}${url.search}`;
  } catch {return fallback;}
}

export function accountHref(returnTo: string): string {
  const destination=safeReturnTo(returnTo);
  return destination==='/account'?'/account':`/account?returnTo=${encodeURIComponent(destination)}`;
}

export function authCallbackUrl(returnTo: string, recovery = false): string {
  const url = new URL('/auth/callback', window.location.origin);
  url.searchParams.set('returnTo', safeReturnTo(returnTo));
  if (recovery) url.searchParams.set('recovery', '1');
  return url.toString();
}
