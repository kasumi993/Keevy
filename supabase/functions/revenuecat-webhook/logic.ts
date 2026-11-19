// Pure logic of the RevenueCat webhook (unit-tested in logic.test.ts).

export type RevenueCatEvent = {
  type: string;
  app_user_id?: string;
  original_app_user_id?: string;
  aliases?: string[];
  entitlement_ids?: string[] | null;
  entitlement_id?: string | null;
  expiration_at_ms?: number | null;
};

export type PremiumUpdate = { userId: string; isPremium: boolean; premiumUntil: string | null };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const GRANTING = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "TEMPORARY_ENTITLEMENT_GRANT",
]);

/** Our app user id is the Supabase user id; anonymous RevenueCat ids are ignored. */
export function supabaseUserId(event: RevenueCatEvent): string | null {
  const candidates = [event.app_user_id, event.original_app_user_id, ...(event.aliases ?? [])];
  return candidates.find((id): id is string => !!id && UUID.test(id)) ?? null;
}

export function premiumUpdateFor(event: RevenueCatEvent, entitlement: string): PremiumUpdate | null {
  const userId = supabaseUserId(event);
  if (!userId) return null;

  const ids = event.entitlement_ids ?? (event.entitlement_id ? [event.entitlement_id] : null);
  if (ids && ids.length > 0 && !ids.includes(entitlement)) return null;

  const until = event.expiration_at_ms ? new Date(event.expiration_at_ms).toISOString() : null;

  if (GRANTING.has(event.type)) return { userId, isPremium: true, premiumUntil: until };
  // Cancellation keeps access until the end of the paid period (premium_until).
  if (event.type === "CANCELLATION") return { userId, isPremium: true, premiumUntil: until };
  if (event.type === "EXPIRATION") return { userId, isPremium: false, premiumUntil: until };
  if (event.type === "BILLING_ISSUE") return null; // grace period handled by RevenueCat
  return null;
}
