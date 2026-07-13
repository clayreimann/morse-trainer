# Deploying the Dah Vinci website

Static site, no build step. Everything Cloudflare needs to serve lives in this `website/` directory.

## 1. Direct upload via Wrangler

From the **repo root**:

```sh
wrangler pages deploy website --project-name dahvinci
```

The first run creates the `dahvinci` Cloudflare Pages project (you'll be prompted to confirm the project name/settings). Subsequent runs redeploy to it. No framework preset, no build command, no output-directory override needed — `website/` is served as-is.

## 2. Attach the custom domain

In the Cloudflare dashboard:

1. **Workers & Pages → dahvinci → Custom domains → Set up a custom domain**
2. Enter `dahvinci.madtown.cloud` and confirm.

This requires the `madtown.cloud` zone to already be on this Cloudflare account. Once added, Cloudflare provisions the DNS record and TLS certificate automatically — no manual DNS edits needed.

## 3. Clean URLs

Cloudflare Pages serves `.html` files at extensionless paths automatically, so:

- `/privacy` → `privacy.html`
- `/support` → `support.html`

`404.html` is served automatically for unmatched routes. No `_redirects` or `_headers` file is required for this site.

## Redeploying

Re-run the same `wrangler pages deploy` command any time the contents of `website/` change.
