type RpcResult<T> = {
  data: T | null;
  error: unknown;
};

type RpcClient = {
  rpc: <T>(fn: string, args: Record<string, unknown>) => Promise<RpcResult<T>>;
};

export interface ReservationPaymentActionResult {
  ok?: boolean;
  error?: string;
}

export const PAYMENT_ACTION_STALE_MS = 10 * 60_000;

function rpcClient(adminClient: unknown): RpcClient {
  return adminClient as RpcClient;
}

export function paymentActionIsStale(
  startedAt: string | null | undefined,
  now = Date.now(),
): boolean {
  const actionStartedAt = startedAt ? Date.parse(startedAt) : 0;
  return actionStartedAt === 0 ||
    now - actionStartedAt > PAYMENT_ACTION_STALE_MS;
}

export async function beginReservationPaymentAction(
  adminClient: unknown,
  params: {
    reservationId: string;
    action: string;
    paymentId: string;
    actorId: string | null;
  },
): Promise<RpcResult<ReservationPaymentActionResult>> {
  return await rpcClient(adminClient).rpc("begin_reservation_payment_action", {
    p_reservation_id: params.reservationId,
    p_action: params.action,
    p_payment_id: params.paymentId,
    p_actor_id: params.actorId,
  });
}

export async function clearReservationPaymentAction(
  adminClient: unknown,
  params: {
    reservationId: string;
    action: string;
  },
): Promise<RpcResult<ReservationPaymentActionResult>> {
  return await rpcClient(adminClient).rpc("clear_reservation_payment_action", {
    p_reservation_id: params.reservationId,
    p_action: params.action,
  });
}

export async function transitionReservationStatus(
  adminClient: unknown,
  params: {
    reservationId: string;
    target: string;
    actorKind: string;
    reason?: string;
  },
): Promise<RpcResult<ReservationPaymentActionResult>> {
  const rpcArgs: Record<string, unknown> = {
    p_reservation_id: params.reservationId,
    p_target: params.target,
    p_actor_kind: params.actorKind,
  };
  if (params.reason != null) {
    rpcArgs.p_reason = params.reason;
  }
  return await rpcClient(adminClient).rpc(
    "transition_reservation_status",
    rpcArgs,
  );
}
