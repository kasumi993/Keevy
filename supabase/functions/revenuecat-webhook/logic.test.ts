import { deepStrictEqual as assertEquals } from "node:assert";
import { premiumUpdateFor, supabaseUserId } from "./logic.ts";

const uid = "3f1c2b9e-8f4d-4a6b-9c1e-2d3f4a5b6c7d";

Deno.test("uses the Supabase uuid among RevenueCat ids", () => {
  assertEquals(supabaseUserId({ type: "X", app_user_id: "$RCAnonymousID:abc", aliases: [uid] }), uid);
  assertEquals(supabaseUserId({ type: "X", app_user_id: "$RCAnonymousID:abc" }), null);
});

Deno.test("purchase grants premium until expiration", () => {
  const u = premiumUpdateFor({ type: "INITIAL_PURCHASE", app_user_id: uid, entitlement_ids: ["premium"], expiration_at_ms: 1_900_000_000_000 }, "premium");
  assertEquals(u, { userId: uid, isPremium: true, premiumUntil: new Date(1_900_000_000_000).toISOString() });
});

Deno.test("expiration removes premium, other entitlements are ignored", () => {
  assertEquals(premiumUpdateFor({ type: "EXPIRATION", app_user_id: uid }, "premium")?.isPremium, false);
  assertEquals(premiumUpdateFor({ type: "RENEWAL", app_user_id: uid, entitlement_ids: ["other"] }, "premium"), null);
  assertEquals(premiumUpdateFor({ type: "TEST", app_user_id: uid }, "premium"), null);
});
