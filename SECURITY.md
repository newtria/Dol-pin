# Security policy

dol-pin is a pre-launch MVP that handles real payment, KYC-style photo,
and concert-location data. Even at Lab status the surface is wide enough
that we want a clear disclosure channel.

## In scope

- Flutter app source in `lib/`
- Supabase Edge Functions in `supabase/functions/`
- Supabase migrations in `supabase/migrations/` (RLS policies, RPCs)
- CI configuration in `.github/workflows/`

## Out of scope

- The PortOne, Gemini, Supabase, and FCM services themselves — report
  those to their respective vendors.
- Issues that require physical device theft to exploit.
- Reports based on auto-generated scanner output with no demonstrated
  exploit path.

## How to report

Email **wantcongz@gmail.com** with:

- A short description of the issue and impact.
- Steps to reproduce (or a proof-of-concept).
- Affected commit hash and platform (iOS / Android / Edge Function).

Please do **not** open a public GitHub issue or PR for vulnerabilities
that allow account takeover, payment tampering, RLS bypass, or arbitrary
read of another user's photos / chats.

## Response

- Acknowledgement within 7 days.
- Triage decision within 14 days.
- For confirmed P0 issues we aim to ship a fix or mitigation within 30
  days; for P1 within 90 days. Lab-tier means we may revoke the
  affected feature or take the service down rather than ship a rushed
  patch.

## Coordinated disclosure

We will credit reporters in the release notes if they want it. We ask
that public write-ups wait until either a fix has shipped or 90 days
have passed since the initial report, whichever is earlier.

## Known limitations

- This is a single-maintainer project. There is no on-call rotation. A
  reply may take longer over weekends or during conference travel.
- Branch protection is not enforced at the GitHub repo level (free plan
  on a private repo) — CI is the only merge gate.
- Production deployment of payment, FCM, and Sentry is gated on
  pre-launch work tracked in `TODO.md`. Reports against unfinished
  features will be acknowledged but may be marked "known, deferred to
  pre-launch milestone."
