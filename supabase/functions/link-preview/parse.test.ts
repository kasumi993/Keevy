import { deepStrictEqual as assertEquals } from "node:assert";
import { extractMeta, isBlockedHost, sourceOf } from "./parse.ts";

Deno.test("sourceOf", () => {
  assertEquals(sourceOf("https://www.instagram.com/reel/abc"), "instagram");
  assertEquals(sourceOf("https://vm.tiktok.com/x"), "tiktok");
  assertEquals(sourceOf("https://fr.pinterest.com/pin/1"), "pinterest");
  assertEquals(sourceOf("https://notinstagram.com"), "web");
  assertEquals(sourceOf("nope"), "web");
});

Deno.test("isBlockedHost", () => {
  for (const h of ["localhost", "127.0.0.1", "10.1.2.3", "192.168.1.1", "172.20.0.1", "169.254.169.254", "[::1]", "printer.local"]) {
    assertEquals(isBlockedHost(h), true, h);
  }
  for (const h of ["instagram.com", "8.8.8.8", "172.32.0.1", "exemple.fr"]) {
    assertEquals(isBlockedHost(h), false, h);
  }
});

Deno.test("extractMeta reads Open Graph, falls back to <title>, resolves relative images", () => {
  const html = `<html><head>
    <title>Fallback &amp; title</title>
    <meta content="Robe bohème" property="og:title">
    <meta property="og:image" content="/img/robe.jpg">
    <meta name="description" content="Une robe &#39;légère&#39;">
    <meta property="og:site_name" content="Atelier">
  </head></html>`;
  const meta = extractMeta(html, "https://atelier.fr/robes/1");
  assertEquals(meta.title, "Robe bohème");
  assertEquals(meta.image, "https://atelier.fr/img/robe.jpg");
  assertEquals(meta.description, "Une robe 'légère'");
  assertEquals(meta.siteName, "Atelier");

  const bare = extractMeta("<title>Juste un titre</title>", "https://x.fr");
  assertEquals(bare.title, "Juste un titre");
  assertEquals(bare.image, null);
});
