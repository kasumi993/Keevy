// revenuecat-webhook — keeps profiles.is_premium in sync with RevenueCat.
// Configure in RevenueCat → Integrations → Webhooks:
//   URL:    https://<project>.supabase.co/functions/v1/revenuecat-webhook
//   Header: Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>
// The app identifies RevenueCat users with their Supabase user id.
import { adminClient, json } from "../_shared/http.ts";
import { premiumUpdateFor, type RevenueCatEvent } from "./logic.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const secret = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
  const auth = req.headers.get("Authorization") ?? "";
  if (!secret || auth.replace(/^Bearer\s+/i, "") !== secret) return json({ error: "unauthorized" }, 401);

  let event: RevenueCatEvent;
  try {
    event = (await req.json())?.event;
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (!event?.type) return json({ error: "invalid_body" }, 400);

  const entitlement = Deno.env.get("REVENUECAT_ENTITLEMENT") ?? "premium";
  const update = premiumUpdateFor(event, entitlement);
  if (!update) return json({ ok: true, ignored: event.type });

  const { error } = await adminClient()
    .from("profiles")
    .update({ is_premium: update.isPremium, premium_until: update.premiumUntil })
    .eq("id", update.userId);
  if (error) return json({ error: "db_error" }, 500);

  return json({ ok: true, user: update.userId, premium: update.isPremium });
});
