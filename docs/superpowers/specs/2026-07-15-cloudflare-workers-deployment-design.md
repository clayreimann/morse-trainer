# Cloudflare Workers Deployment Design

**Goal:** Make the static Dah Vinci launch website a repository-owned Cloudflare Workers Static Assets deployment with reproducible local commands and automatic deployments from `main`.

## Decisions

- Use Cloudflare Workers Static Assets. Do not create a Cloudflare Pages project.
- Keep all deploy behavior in the repository so a fresh clone contains the complete deployment contract.
- Serve the existing `website/` directory directly; there is no site build step and no Worker runtime script.
- Use `dahvinci.madtown.cloud` as a Worker Custom Domain. Cloudflare owns DNS and certificate provisioning for the hostname.
- Keep the current pre-launch “Coming to the App Store” copy until the App Store listing is public.

## Repository structure

- `wrangler.jsonc` is the deployment source of truth. It names the Worker `dahvinci`, points static assets at `website/`, enables the existing `404.html`, serves `.html` files at extensionless URLs, and declares the custom domain.
- `package.json` exposes local preview, validation, and deployment scripts.
- `package-lock.json` pins the tested Wrangler dependency graph for local and Cloudflare builds.
- `.gitignore` excludes `node_modules/`, Wrangler state, and the local redesign PDF.
- `website/DEPLOY.md` documents the Workers workflow, first deployment, Git integration, validation, and rollback.

## Merge cleanup

- Remove the consumed root `IMPLEMENTATION.md` handoff.
- Keep `Morse redesign.pdf` untracked and explicitly ignored.
- Rewrite the App Store distribution guide as durable operator documentation: remove transient certificate observations, assistant-specific prose, and the incorrect `notarytool` upload suggestion.
- Remove the account-specific Team ID from the tracked export options. Local signing remains in the ignored `Signing.xcconfig`; exported archives use their existing signing team.
- Replace the public personal Gmail address with the repository issue tracker as the support and privacy contact.
- Update pull request 1 so its permanent merge record reflects the current app, website, test count, and verification status.

## Deployment flow

1. Install the locked Node dependencies with `npm ci` after the initial lockfile is created.
2. Validate the Worker configuration without publishing.
3. Preview the static site locally and verify `/`, `/privacy`, `/support`, and an unknown route.
4. Authenticate Wrangler to the intended Cloudflare account.
5. Deploy the Worker and static assets. The custom-domain declaration provisions `dahvinci.madtown.cloud` in the existing `madtown.cloud` Cloudflare zone.
6. Verify both the generated `workers.dev` hostname and custom domain before using the URLs in App Store Connect.
7. Connect the existing Worker to GitHub through Workers Builds. Production deploys come from `main`; non-production branches upload preview versions rather than replacing production.
8. Limit build watch paths to the website and deployment configuration so Swift-only commits do not redeploy the website.

## Failure handling and rollback

- Configuration validation and local preview happen before the first publish.
- A failed Wrangler or Workers Build command must stop the deployment with a nonzero status.
- The existing active Worker deployment remains available if a later build fails.
- Use Cloudflare version history to roll production back to the previous known-good version.
- Do not add Cloudflare API tokens to the repository. Local deployment uses Wrangler login; Workers Builds manages its Cloudflare credentials internally.

## Verification

- `npm ci` succeeds from a clean dependency state.
- Wrangler configuration validation succeeds.
- Local HTTP checks return `200` for `/`, `/privacy`, and `/support`, and `404` with the custom page for an unknown route.
- The first Cloudflare deployment completes successfully.
- The custom hostname resolves and serves the same content over HTTPS.
- `swift test` and the unsigned iOS simulator build continue to pass after repository cleanup.
- `git diff --check` reports no whitespace errors, and generated deployment state remains untracked.

## Non-goals

- No Pages project or Pages Functions.
- No server-side Worker code, API endpoints, analytics, or runtime bindings.
- No launch-day replacement of the App Store CTA before the listing URL exists.
