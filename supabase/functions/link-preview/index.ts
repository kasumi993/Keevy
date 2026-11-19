// link-preview — Open Graph / oEmbed preview of a URL (title, image, domain).
// Signed-in users only (prevents use as an open proxy). Social images are never
// copied: the app stores the URL and displays it from the source.
//
// POST { url: string }  →  { url, finalUrl, domain, title, description, image, siteName, source }
import { json, preflight, userFromRequest } from "../_shared/http.ts";
import { extractMeta, isBlockedHost, sourceOf } from "./parse.ts";

const MAX_BYTES = 1_500_000;
const TIMEOUT_MS = 8_000;
const MAX_REDIRECTS = 5;
const UA = "Mozilla/5.0 (compatible; KeevyBot/1.0; +https://keevy.app) facebookexternalhit/1.1";

type Preview = {
  url: string;
  finalUrl: string;
  domain: string;
  title: string | null;
  description: string | null;
  image: string | null;
  siteName: string | null;
  source: string;
};

async function fetchWithLimits(url: string, accept = "text/html,application/xhtml+xml"): Promise<Response> {
  let current = url;
  for (let i = 0; i <= MAX_REDIRECTS; i++) {
    const target = new URL(current);
    if (!["http:", "https:"].includes(target.protocol) || isBlockedHost(target.hostname)) {
      throw new Error("blocked_url");
    }
    const res = await fetch(current, {
      redirect: "manual",
      headers: { "User-Agent": UA, "Accept": accept, "Accept-Language": "fr,en;q=0.8" },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
      current = new URL(res.headers.get("location")!, current).toString();
      await res.body?.cancel();
      continue;
    }
    // Expose the final URL to the caller.
    Object.defineProperty(res, "finalUrl", { value: current });
    return res;
  }
  throw new Error("too_many_redirects");
}

async function readText(res: Response): Promise<string> {
  const reader = res.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (total < MAX_BYTES) {
    const { done, value } = await reader.read();
    if (done || !value) break;
    chunks.push(value);
    total += value.length;
  }
  await reader.cancel().catch(() => {});
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const c of chunks) {
    merged.set(c, offset);
    offset += c.length;
  }
  return new TextDecoder("utf-8", { fatal: false }).decode(merged);
}

/** oEmbed endpoints that don't need an API key and return a thumbnail. */
function oembedEndpoint(url: string, source: string): string | null {
  const u = encodeURIComponent(url);
  switch (source) {
    case "tiktok":
      return `https://www.tiktok.com/oembed?url=${u}`;
    case "youtube":
      return `https://www.youtube.com/oembed?format=json&url=${u}`;
    case "pinterest":
      return `https://www.pinterest.com/oembed.json?url=${u}`;
    default:
      return null;
  }
}

async function tryOembed(url: string, source: string): Promise<Partial<Preview> | null> {
  const endpoint = oembedEndpoint(url, source);
  if (!endpoint) return null;
  try {
    const res = await fetch(endpoint, { signal: AbortSignal.timeout(TIMEOUT_MS), headers: { "User-Agent": UA } });
    if (!res.ok) return null;
    const data = await res.json();
    return {
      title: data.title ?? (data.author_name ? `@${data.author_name}` : null),
      image: data.thumbnail_url ?? null,
      siteName: data.provider_name ?? null,
    };
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const user = await userFromRequest(req);
  if (!user) return json({ error: "unauthorized" }, 401);

  let url: string;
  try {
    const body = await req.json();
    url = String(body?.url ?? "").trim();
    new URL(url);
  } catch {
    return json({ error: "invalid_url" }, 400);
  }

  const source = sourceOf(url);
  const base: Preview = {
    url,
    finalUrl: url,
    domain: new URL(url).hostname.replace(/^www\./, ""),
    title: null,
    description: null,
    image: null,
    siteName: null,
    source,
  };

  const oembed = await tryOembed(url, source);
  if (oembed?.image) return json({ ...base, ...oembed });

  try {
    const res = await fetchWithLimits(url);
    const finalUrl = (res as Response & { finalUrl?: string }).finalUrl ?? url;
    const type = res.headers.get("content-type") ?? "";
    if (type.startsWith("image/")) {
      await res.body?.cancel();
      return json({ ...base, finalUrl, image: finalUrl });
    }
    const html = await readText(res);
    const meta = extractMeta(html, finalUrl);
    return json({
      ...base,
      finalUrl,
      domain: new URL(finalUrl).hostname.replace(/^www\./, ""),
      source: sourceOf(finalUrl),
      ...meta,
      title: meta.title ?? oembed?.title ?? null,
      siteName: meta.siteName ?? oembed?.siteName ?? null,
    });
  } catch (e) {
    // Sites that block bots (Instagram often does): keep the link without preview.
    return json({ ...base, ...(oembed ?? {}), error: String((e as Error).message ?? e) });
  }
});
