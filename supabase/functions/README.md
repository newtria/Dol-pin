# supabase/functions

Deno-based Edge Functions for dol-pin. All functions share auth + CORS +
quota helpers in `_shared/` and pinned imports in `deno.json`.

## Bumping dependencies

Dependabot does not support Deno, so `deno.json` is the manual choke
point. After editing an import map entry:

```
deno cache --reload --config deno.json supabase/functions/**/*.ts
git add deno.lock
```

## Required Function secrets

Per `supabase secrets set <KEY>=<VALUE>`:

- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` — provided by the platform.
- `ALLOWED_ORIGINS` — comma-separated CORS allowlist (optional; falls
  back to `*` when unset).
- `GEMINI_API_KEY`, `GEMINI_DAILY_QUOTA` — for `gemini-analyze`.
- `PORTONE_IMP_KEY`, `PORTONE_IMP_SECRET` — for `verify-payment` and
  `refund-payment`.
- `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON` — for `push-notification`.
