// delete-account — deletes the caller's account, data and images (store requirement).
// POST (Authorization: Bearer <user access token>)  →  { ok: true }
import { adminClient, json, preflight, userFromRequest } from "../_shared/http.ts";

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const user = await userFromRequest(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  const db = adminClient();

  // 1. Images of every board the user owns (storage is not covered by the SQL cascade).
  const { data: boards } = await db.from("boards").select("id").eq("owner_id", user.id);
  const bucket = db.storage.from("card-images");
  for (const board of boards ?? []) {
    for (let page = 0; page < 50; page++) {
      const { data: files } = await bucket.list(board.id, { limit: 100 });
      if (!files || files.length === 0) break;
      await bucket.remove(files.map((f) => `${board.id}/${f.name}`));
      if (files.length < 100) break;
    }
  }

  // 2. The auth user: profiles → boards → sections/cards/tasks/shares/contacts cascade.
  const { error } = await db.auth.admin.deleteUser(user.id);
  if (error) return json({ error: "delete_failed" }, 500);

  return json({ ok: true });
});
