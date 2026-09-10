import { ApiError } from "./errors.ts";
import {
  extractReservationId,
  fetchPortOnePayment,
  getPortOneAccessToken,
  portOneCancel,
} from "./portone.ts";

export type Payment = {
  id: string;
  orderId: string;
  total: number;
  refunded: number;
  currency: string;
  status: "paid" | "unpaid" | "failed" | "cancelled";
};
export interface PaymentProvider {
  lookupOrder(orderId: string): Promise<Payment | null>;
  lookup(paymentId: string): Promise<Payment>;
  confirm(paymentId: string, orderId: string, amount: number): Promise<Payment>;
  cancel(
    paymentId: string,
    amount: number,
    total: number,
    operationId: string,
  ): Promise<Payment>;
}
export type ProviderFactory = (name: string) => PaymentProvider;

function tossPayment(p: Record<string, unknown>): Payment {
  if (
    typeof p.paymentKey !== "string" || typeof p.orderId !== "string" ||
    !Number.isSafeInteger(p.totalAmount) ||
    typeof p.currency !== "string"
  ) throw new Error("결제사 응답 형식이 올바르지 않습니다.");
  const total = p.totalAmount as number;
  const balance = typeof p.balanceAmount === "number" ? p.balanceAmount : total;
  if (!Number.isSafeInteger(balance) || balance < 0 || balance > total) {
    throw new Error("결제사 잔액이 일치하지 않습니다.");
  }
  return {
    id: p.paymentKey,
    orderId: p.orderId,
    total,
    refunded: total - balance,
    currency: p.currency,
    status: p.status === "DONE" || p.status === "PARTIAL_CANCELED"
      ? "paid"
      : p.status === "CANCELED"
      ? "cancelled"
      : p.status === "ABORTED" || p.status === "EXPIRED"
      ? "failed"
      : "unpaid",
  };
}
export function tossProvider(): PaymentProvider {
  const secret = Deno.env.get("TOSS_SECRET_KEY");
  if (!secret) throw new ApiError("SERVICE_UNAVAILABLE");
  async function request(
    path: string,
    body?: unknown,
    idempotency?: string,
  ): Promise<Payment | null> {
    const result = await fetch(
      `https://api.tosspayments.com/v1/payments${path}`,
      {
        method: body ? "POST" : "GET",
        signal: AbortSignal.timeout(15000),
        headers: {
          Authorization: `Basic ${btoa(secret + ":")}`,
          "Content-Type": "application/json",
          ...(idempotency ? { "Idempotency-Key": idempotency } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
      },
    );
    const data = await result.json();
    if (!body && result.status === 404) return null;
    if (!result.ok) {
      throw new Error(
        "결제사 처리 결과를 확인하지 못했습니다. 다시 확인해 주세요.",
      );
    }
    return tossPayment(data);
  }
  return {
    lookupOrder: (orderId) => request(`/orders/${encodeURIComponent(orderId)}`),
    async lookup(id) {
      const payment = await request(`/${encodeURIComponent(id)}`);
      if (!payment) throw new Error("결제를 찾지 못했습니다.");
      return payment;
    },
    async confirm(id, orderId, amount) {
      return (await request(
        "/confirm",
        { paymentKey: id, orderId, amount },
        orderId,
      ))!;
    },
    async cancel(id, amount, total, operationId) {
      return (await request(`/${encodeURIComponent(id)}/cancel`, {
        cancelReason: "돌핀 대여 거래 환불",
        cancelAmount: amount,
        refundableAmount: total,
      }, operationId))!;
    },
  };
}
export const paymentProvider: ProviderFactory = (name) => {
  if (name === "toss") return tossProvider();
  if (name !== "portone") throw new Error("지원하지 않는 결제사입니다.");
  const map = (
    p: Awaited<ReturnType<typeof fetchPortOnePayment>>,
  ): Payment => ({
    id: p.imp_uid,
    orderId: extractReservationId(p.merchant_uid) ?? "",
    total: p.amount,
    refunded: p.cancel_amount ?? 0,
    currency: p.currency ?? "",
    status: p.status === "paid"
      ? "paid"
      : p.status === "cancelled"
      ? "cancelled"
      : p.status === "failed"
      ? "failed"
      : "unpaid",
  });
  return {
    lookupOrder() {
      throw new Error("PortOne 주문 복구는 기존 경로를 사용해 주세요.");
    },
    async lookup(id) {
      return map(await fetchPortOnePayment(id, await getPortOneAccessToken()));
    },
    confirm() {
      throw new Error("PortOne 승인은 기존 경로를 사용해 주세요.");
    },
    async cancel(id, amount) {
      return map(
        await portOneCancel(await getPortOneAccessToken(), {
          imp_uid: id,
          amount,
          reason: "돌핀 대여 거래 환불",
        }),
      );
    },
  };
};
