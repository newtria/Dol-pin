import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@dolpin/contracts';
import { ApiRequestError, errorMessage } from './errors.ts';

export type Payout = {
  id: string; reservation_id: string; lender_id: string; amount: number;
  fee_amount: number; net_amount: number; currency: 'KRW';
  status: 'pending' | 'processing' | 'paid' | 'failed';
  paid_at: string | null; created_at: string;
  claimed_by?: string | null; claimed_at?: string | null;
};
export type PayoutAccount = { bankName: string; accountNumber: string; holderName: string };
export type PayoutCursor = { createdAt: string; id: string };
export type PayoutClaim = { payout: Payout; account: PayoutAccount; claimToken: string };
export type PickupConfirmation = { status: string; borrowerConfirmed: boolean; lenderConfirmed: boolean };
export type Dispute = {
  id: string; reservation_id: string; reporter_id: string | null; operator_id?: string | null; reason: string;
  evidence_paths: string[]; created_at: string; resolved_at: string | null;
};
export type DisputeResolution = { refund_amount: number; reason: string; created_at: string | null };
export type OperatorReview = {
  id: string; reservation_id: string;
  kind: 'pickup_overdue' | 'return_overdue' | 'settlement_overdue' | 'dispute_unresolved' | 'untracked_payment' | 'legacy_finance';
  created_at: string; closed_at: string | null; closed_by: string | null; resolution_note: string | null;
};
export type RecoveryWork = {
  kind: 'money' | 'checkout'; key: string; reservation_id: string;
  attempt_count: number; failure_count: number; next_attempt_at: string;
  last_error_code: string | null; review_required_at: string | null; created_at: string;
};
export type FinanceReservation = {
  id: string; status: string; total_paid: number; deposit: number; rental_fee: number;
  borrower_id: string; lender_id: string; payment_action: string | null;
};
export type FinanceQueue = {
  payouts: Payout[]; disputes: Dispute[]; reviews: OperatorReview[];
  recovery: RecoveryWork[]; reservations: FinanceReservation[]; hasMore: boolean;
};
export type MessageCursor = { createdAt: string; id: string };
export type FinanceRentalDetail = {
  reservation: FinanceReservation & {
    item_id: string; rental_date: string; return_date: string; starts_at: string | null; ends_at: string | null;
    pickup_confirmed_at: string | null; return_confirmed_at: string | null; return_photo: string | null;
    payment_provider: string | null; created_at: string | null; terms_snapshot: Record<string, unknown> | null;
  };
  item: { id: string; title: string } | null;
  participants: { id: string; nickname: string | null }[];
  pickup: { borrowerConfirmed: boolean; lenderConfirmed: boolean };
  disputes: Dispute[];
  resolutions: DisputeResolution[];
  operations: {
    id: string; kind: 'refund' | 'settle' | 'dispute'; amount: number; total: number;
    status: 'pending' | 'complete'; created_at: string; dispatched_at: string | null;
    last_error_code: string | null; review_required_at: string | null;
  }[];
  payouts: Payout[];
  events: { id: number; actor_id: string | null; command: string; from_status: string | null; to_status: string; created_at: string }[];
  messages: { id: string; sender_id: string; message: string | null; created_at: string; read_at: string | null }[];
  messagesHasMore: boolean;
  legacyPayments: {
    payment_reference: string; amount: number; refunded: number; currency: string; status: string;
    reason_code: string; created_at: string; resolved_at: string | null;
  }[];
};

type FinanceFunctions = {
  own_rental_payouts: { Args: { p_before?: string; p_before_id?: string }; Returns: Payout[] };
  own_payout_account: { Args: Record<string, never>; Returns: PayoutAccount | null };
  save_payout_account: { Args: { p_bank_name: string; p_account_number: string; p_holder_name: string }; Returns: undefined };
  confirm_rental_pickup: { Args: { p_reservation_id: string }; Returns: PickupConfirmation };
  rental_pickup_status: { Args: { p_reservation_id: string }; Returns: PickupConfirmation };
  open_rental_dispute: { Args: { p_reservation_id: string; p_reason: string; p_evidence_paths: string[] }; Returns: Dispute };
  add_rental_dispute_evidence: { Args: { p_reservation_id: string; p_path: string }; Returns: undefined };
};
type FinanceDatabase = Omit<Database, 'public'> & {
  public: Omit<Database['public'], 'Functions' | 'Tables'> & {
    Functions: Database['public']['Functions'] & FinanceFunctions;
    Tables: Database['public']['Tables'] & {
      rental_disputes: { Row: Dispute; Insert: never; Update: never; Relationships: [] };
    };
  };
};
function value<T>(result: { data: T; error: { code?: string; message: string } | null }): T {
  if (result.error) throw new ApiRequestError({ code: result.error.code, error: errorMessage(result.error) });
  return result.data;
}

export function createFinanceApi(client: SupabaseClient<Database>) {
  const db = client as unknown as SupabaseClient<FinanceDatabase>;
  async function operator<T>(action: string, body: Record<string, unknown> = {}): Promise<T> {
    const { data, error } = await client.functions.invoke('finance-ops', { body: { ...body, action } });
    if (error || data?.error) {
      const context = (error as { context?: Response } | null)?.context;
      const detail = data?.error ? data : context ? await context.json().catch(() => null) : null;
      throw new ApiRequestError(detail ?? {});
    }
    return data as T;
  }
  return {
    async payouts(before?: PayoutCursor): Promise<Payout[]> {
      return value(await db.rpc('own_rental_payouts', before ? { p_before: before.createdAt, p_before_id: before.id } : {})) ?? [];
    },
    async payoutAccount(): Promise<PayoutAccount | null> {
      return value(await db.rpc('own_payout_account', {}));
    },
    async savePayoutAccount(account: PayoutAccount): Promise<void> {
      value(await db.rpc('save_payout_account', { p_bank_name: account.bankName, p_account_number: account.accountNumber, p_holder_name: account.holderName }));
    },
    async pickup(reservationId: string): Promise<PickupConfirmation> {
      const result = value(await db.rpc('confirm_rental_pickup', { p_reservation_id: reservationId }));
      if (!result) throw new ApiRequestError({});
      return result;
    },
    async pickupStatus(reservationId: string): Promise<PickupConfirmation> {
      const result = value(await db.rpc('rental_pickup_status', { p_reservation_id: reservationId }));
      if (!result) throw new ApiRequestError({});
      return result;
    },
    async disputes(reservationId: string): Promise<Dispute[]> {
      return value(await db.from('rental_disputes').select('*').eq('reservation_id', reservationId).order('created_at')) ?? [];
    },
    async disputeResolution(reservationId: string): Promise<DisputeResolution | null> {
      return value(await client.from('reservation_dispute_resolutions').select('refund_amount,reason,created_at')
        .eq('reservation_id', reservationId).order('created_at', { ascending: false }).limit(1).maybeSingle());
    },
    async openDispute(reservationId: string, reason: string, evidencePaths: string[] = []): Promise<Dispute> {
      const result = value(await db.rpc('open_rental_dispute', { p_reservation_id: reservationId, p_reason: reason, p_evidence_paths: evidencePaths }));
      if (!result) throw new ApiRequestError({});
      return result;
    },
    async addDisputeEvidence(reservationId: string, path: string): Promise<void> {
      value(await db.rpc('add_rental_dispute_evidence', { p_reservation_id: reservationId, p_path: path }));
    },
    async disputeEvidenceUrl(path: string): Promise<string> {
      const result = value(await client.storage.from('dispute-evidence').createSignedUrl(path, 300));
      if (!result) throw new ApiRequestError({});
      return result.signedUrl;
    },
    operationQueue(offset = 0): Promise<FinanceQueue> { return operator('queue', { offset }); },
    operationRental(reservationId: string, messageBefore?: MessageCursor): Promise<FinanceRentalDetail> {
      return operator('rental', { reservationId, ...(messageBefore ? { messageBefore } : {}) });
    },
    claimPayout(id: string): Promise<PayoutClaim> { return operator('claimPayout', { id }); },
    completePayout(id: string, claimToken: string, transferReference: string): Promise<Payout> {
      return operator('completePayout', { id, claimToken, transferReference });
    },
    failPayout(id: string, claimToken: string, reason: string): Promise<Payout> {
      return operator('failPayout', { id, claimToken, reason });
    },
    async retryPayout(id: string, reason: string, claimedAt: string | null = null): Promise<void> {
      await operator('retryPayout', { id, reason, claimedAt, verifiedNotSent: true });
    },
    reconcilePayout(id: string, claimedAt: string | null, outcome: 'paid' | 'not_sent', reason: string, transferReference?: string): Promise<Payout> {
      return operator('reconcilePayout', { id, claimedAt, outcome, reason, transferReference });
    },
    resolveDispute(reservationId: string, refundAmount: number, reason: string): Promise<{ status: string }> {
      return operator('resolveDispute', { reservationId, refundAmount, reason });
    },
    async retryRecovery(kind: 'money' | 'checkout', key: string): Promise<void> {
      await operator('retryRecovery', { kind, key });
    },
    async closeReview(id: string, note: string): Promise<void> {
      await operator('closeReview', { id, note });
    },
    async escalateReview(id: string, note: string): Promise<void> {
      await operator('escalateReview', { id, note });
    },
    async operatorEvidenceUrl(path: string): Promise<string> {
      return (await operator<{ url: string }>('evidenceUrl', { path })).url;
    },
    async operatorReturnPhotoUrl(reservationId: string): Promise<string> {
      return (await operator<{ url: string }>('returnPhotoUrl', { reservationId })).url;
    },
  };
}
