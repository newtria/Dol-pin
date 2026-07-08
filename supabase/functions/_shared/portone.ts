const PORTONE_API = "https://api.iamport.kr";
const PORTONE_TIMEOUT_MS = 15_000;

let cachedPortOneToken: { value: string; expiresAt: number } | null = null;

function portOneCredentials(): { impKey: string; impSecret: string } {
  return {
    impKey: Deno.env.get("PORTONE_IMP_KEY")!,
    impSecret: Deno.env.get("PORTONE_IMP_SECRET")!,
  };
}

export interface PortOnePayment {
  imp_uid: string;
  merchant_uid: string;
  amount: number;
  cancel_amount?: number;
  status: string;
  currency?: string;
  pg_provider?: string;
  pay_method?: string;
}

export async function getPortOneAccessToken(): Promise<string> {
  const now = Date.now();
  if (cachedPortOneToken && cachedPortOneToken.expiresAt - 60_000 > now) {
    return cachedPortOneToken.value;
  }

  const { impKey, impSecret } = portOneCredentials();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS);
  try {
    const res = await fetch(`${PORTONE_API}/users/getToken`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        imp_key: impKey,
        imp_secret: impSecret,
      }),
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error(`PortOne token HTTP ${res.status}`);

    const data = await res.json();
    if (data.code !== 0) {
      throw new Error(`PortOne token: ${data.message ?? "unknown"}`);
    }

    const token = data.response.access_token as string;
    const expiresAt = Number(data.response.expired_at) * 1000;
    cachedPortOneToken = { value: token, expiresAt };
    return token;
  } finally {
    clearTimeout(timer);
  }
}

export async function fetchPortOnePayment(
  impUid: string,
  token: string,
): Promise<PortOnePayment> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS);
  try {
    const res = await fetch(
      `${PORTONE_API}/payments/${encodeURIComponent(impUid)}`,
      {
        method: "GET",
        headers: { Authorization: token },
        signal: ctrl.signal,
      },
    );
    if (!res.ok) throw new Error(`PortOne payment HTTP ${res.status}`);

    const data = await res.json();
    if (data.code !== 0) {
      throw new Error(`PortOne payment: ${data.message ?? "unknown"}`);
    }

    return data.response as PortOnePayment;
  } finally {
    clearTimeout(timer);
  }
}

export async function portOneCancel(
  token: string,
  params: { imp_uid: string; amount?: number; reason: string },
): Promise<PortOnePayment> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), PORTONE_TIMEOUT_MS);
  try {
    const res = await fetch(`${PORTONE_API}/payments/cancel`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: token },
      body: JSON.stringify(params),
      signal: ctrl.signal,
    });
    if (!res.ok) throw new Error(`PortOne cancel HTTP ${res.status}`);

    const data = await res.json();
    if (data.code !== 0) {
      throw new Error(`PortOne cancel: ${data.message ?? "unknown"}`);
    }

    return data.response as PortOnePayment;
  } finally {
    clearTimeout(timer);
  }
}

export function extractReservationId(merchantUid: string): string | null {
  if (!merchantUid.startsWith("dolpin_")) return null;
  const parts = merchantUid.split("_");
  if (parts.length !== 3) return null;
  return parts[1];
}

export function normalizePortOneStatus(portOneStatus: string): string {
  switch (portOneStatus) {
    case "paid":
      return "success";
    case "ready":
      return "pending";
    case "failed":
    case "cancelled":
    default:
      return "failed";
  }
}
