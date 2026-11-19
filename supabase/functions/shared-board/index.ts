// shared-board — public, read-only snapshot of a board shared by link.
// Anyone with a valid token can call it (no account). Private gallery images are
// returned as short-lived signed URLs.
//
// POST { token: string }  →  { access, board, owner_name, sections, cards[ + signed_url ] } | 404
import { adminClient, json, preflight } from "../_shared/http.ts";

const SIGNED_TTL_SECONDS = 60 * 60;

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let token = "";
  try {
    token = String((await req.json())?.token ?? "").trim();
  } catch {
    // fall through
  }
  if (!/^[a-f0-9]{32,128}$/i.test(token)) return json({ error: "invalid_token" }, 400);

  const db = adminClient();
  const { data, error } = await db.rpc("get_shared_board", { p_token: token });
  if (error) return json({ error: "server_error" }, 500);
  if (!data) return json({ error: "not_found" }, 404);

  const snapshot = data as {
    cards: Array<{ image_path?: string | null; signed_url?: string | null }>;
  };
  const paths = snapshot.cards.map((c) => c.image_path).filter((p): p is string => !!p);
  if (paths.length > 0) {
    const { data: signed } = await db.storage.from("card-images").createSignedUrls(paths, SIGNED_TTL_SECONDS);
    const byPath = new Map((signed ?? []).filter((s) => s.signedUrl).map((s) => [s.path, s.signedUrl]));
    for (const card of snapshot.cards) {
      if (card.image_path) card.signed_url = byPath.get(card.image_path) ?? null;
    }
  }

  return new Response(JSON.stringify(snapshot), {
    status: 200,
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      "Content-Type": "application/json",
      "Cache-Control": "private, max-age=60",
    },
  });
});
