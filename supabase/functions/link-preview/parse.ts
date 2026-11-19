// Pure helpers for link-preview (unit-tested in parse.test.ts).

export function sourceOf(url: string): string {
  let host = "";
  try {
    host = new URL(url).hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return "web";
  }
  const on = (d: string) => host === d || host.endsWith(`.${d}`);
  if (on("instagram.com") || on("instagr.am")) return "instagram";
  if (on("tiktok.com")) return "tiktok";
  if (on("pinterest.com") || on("pin.it") || /(^|\.)pinterest\.[a-z.]+$/.test(host)) return "pinterest";
  if (on("twitter.com") || on("x.com") || on("t.co")) return "twitter";
  if (on("youtube.com") || on("youtu.be")) return "youtube";
  if (on("facebook.com") || on("fb.watch") || on("fb.com")) return "facebook";
  return "web";
}

/** Rejects localhost, private/link-local IP literals and internal names (SSRF guard). */
export function isBlockedHost(hostname: string): boolean {
  const h = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (h === "localhost" || h.endsWith(".localhost") || h.endsWith(".local") || h.endsWith(".internal")) return true;
  if (h === "metadata.google.internal") return true;
  const v4 = h.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
  if (v4) {
    const [a, b] = [Number(v4[1]), Number(v4[2])];
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
    if (a === 192 && b === 168) return true;
    if (a === 100 && b >= 64 && b <= 127) return true;
    return false;
  }
  if (h.includes(":")) {
    // IPv6 literal: block loopback, link-local, unique-local, mapped IPv4.
    return h === "::1" || h === "::" || h.startsWith("fe80") || h.startsWith("fc") || h.startsWith("fd") ||
      h.startsWith("::ffff:");
  }
  return false;
}

function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&#x27;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/\s+/g, " ")
    .trim();
}

function metaContent(html: string, keys: string[]): string | null {
  for (const key of keys) {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const patterns = [
      new RegExp(`<meta[^>]+(?:property|name)=["']${escaped}["'][^>]*content=["']([^"']*)["']`, "i"),
      new RegExp(`<meta[^>]+content=["']([^"']*)["'][^>]*(?:property|name)=["']${escaped}["']`, "i"),
    ];
    for (const re of patterns) {
      const m = html.match(re);
      if (m && m[1].trim()) return decodeEntities(m[1]);
    }
  }
  return null;
}

function absolute(url: string | null, base: string): string | null {
  if (!url) return null;
  try {
    const u = new URL(url, base);
    return ["http:", "https:"].includes(u.protocol) ? u.toString() : null;
  } catch {
    return null;
  }
}

export function extractMeta(html: string, baseUrl: string): {
  title: string | null;
  description: string | null;
  image: string | null;
  siteName: string | null;
} {
  const head = html.slice(0, 400_000);
  const titleTag = head.match(/<title[^>]*>([^<]{1,500})<\/title>/i)?.[1];
  const title = metaContent(head, ["og:title", "twitter:title"]) ?? (titleTag ? decodeEntities(titleTag) : null);
  const description = metaContent(head, ["og:description", "twitter:description", "description"]);
  const image = absolute(
    metaContent(head, ["og:image:secure_url", "og:image", "og:image:url", "twitter:image", "twitter:image:src"]),
    baseUrl,
  );
  const siteName = metaContent(head, ["og:site_name", "application-name"]);
  return {
    title: title ? title.slice(0, 300) : null,
    description: description ? description.slice(0, 500) : null,
    image,
    siteName,
  };
}
