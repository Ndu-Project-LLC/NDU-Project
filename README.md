# FlutterFlow AI Workspace

This workspace is scaffolded for the FlutterFlow AI DSL.

## Lightweight web build (run anytime)

Builds a small, fast-loading web bundle to `build/web-lite/` and can serve it locally instantly — no Firebase CLI or deployment needed.

```bash
./scripts/build_web_lite.sh               # build + size report
./scripts/build_web_lite.sh --serve       # build, then serve at http://localhost:8080
                                          # (next free port if 8080 is taken)
./scripts/build_web_lite.sh --serve 3000  # build, then serve on a custom port
./scripts/build_web_lite.sh --serve-only  # serve the existing build, no rebuild
```

What it does differently from the standard pipeline (`deploy.sh` → `build/web/`):

- `--release` with `--tree-shake-icons` (icons shrink ~92%; production builds disable this)
- `--pwa-strategy=none` — no service worker or offline cache bloat
- Prunes engine payloads a dart2js build never downloads: `skwasm*`/`wimp*` (dart2wasm only), `experimental_webparagraph`, `*.js.symbols` (~22 MB off the bundle)
- Stamps the build version (same cache-busting pipeline as production) and prints a size report with gzipped wire sizes

The production pipeline is untouched: `./deploy.sh` and `scripts/deploy_staging.sh` still build to `build/web/`. For a plain serve-anytime run without building, `python3 scripts/serve_lite.py build/web-lite 8080` works on its own.

### If localhost does not load

- **Port 8080 is contended.** The web preview, the local LLM gate
  (`llm-server/start-local.sh`) and `scripts/serve_flutter_web_fast.py` all
  used to default to it; the one that lost the bind printed
  "Serving … at :8080" and *then* died with an `OSError` traceback, so what the
  browser showed was a different service. `scripts/serve_lite.py` now probes
  the port first, names the process holding it, serves on the next free port,
  and prints the URL it actually bound. The local LLM gate defaults to **8088**.
  Pass `--strict` (or set `NDU_STRICT_PORT=1`) to make a busy port an error
  instead of a port change — CI does this.
- **`flutter run -d chrome` needs a real Chromium.** `CHROME_EXECUTABLE` must
  point at a binary that answers `--version` immediately. Arc.app does not — it
  never returns, so `flutter devices` hangs and no web device is ever listed.
  The `~/.local/bin/ndu-web-chrome` wrapper resolves the newest available
  Chromium build instead. Without a working browser, `flutter devices` shows no
  Chrome and the dev server never opens a port.
- **No browser required:** `flutter run -d web-server --web-port=8080` serves
  the app for any browser, and the static preview above needs none at all.

## Local (no-AI) generation mode

The app can run every KAZ AI surface **without any AI provider** — no proxy, no key, no network. Content is generated at the code level by a deterministic engine that returns the same shape of output the model would, so screens stay fully functional for demos, offline use, CI, and E2E runs.

```bash
# Build + serve a web bundle whose AI runs entirely in code
./scripts/build_web_lite.sh --serve --local-ai

# Or enable it for any flutter run/build
flutter run -d chrome --dart-define=AI_MODE=local
flutter build web --dart-define=AI_MODE=local
```

- `AI_MODE=live` (default) — normal behaviour: requests go to the server-side proxy.
- `AI_MODE=local` (aliases: `no-ai`, `offline`) — every AI call is answered locally:
  - `lib/services/ai/local_ai_client.dart` intercepts the AI HTTP client and short-circuits each completion.
  - `lib/services/ai/local_ai_engine.dart` reads the request's prompt, finds the JSON shape the caller is parsing for, and fills it with deterministic, on-topic content (or prose when the caller wants text).
  - `lib/services/ai/ai_mode.dart` exposes the switch.
- Local mode also lifts the Firebase sign-in requirement for AI calls, so content generation works without an authenticated session.
- Responses are flagged with `ndu_local_generation: true` for diagnostics.
- An amber `LocalAiBanner` sits above every screen so locally generated content is never mistaken for live model output (dismissible for the session).

### Verifying local generation end to end

Two layers prove the app generates content by itself with no provider:

```bash
# 1. Service level — drives the real AI service with the network forcibly
#    unavailable and asserts every surface still returns usable content.
flutter test test/services/local_ai_engine_test.dart \
             test/services/local_ai_client_test.dart \
             test/services/local_ai_e2e_test.dart

# 2. Bundle level — boots the built web bundle in headless Chromium and
#    asserts the app mounts, loads main.dart.js + canvaskit.wasm, logs no
#    console errors, and never contacts the AI proxy.
./scripts/build_web_lite.sh --local-ai --no-stamp
python3 scripts/serve_lite.py build/web-lite 8099 &
node scripts/e2e_local_ai_web.mjs --url http://127.0.0.1:8099
```

`scripts/e2e_local_ai_web.mjs` needs no npm install: it drives the Chrome DevTools Protocol over Node's built-in WebSocket and reuses the Chromium that Playwright downloaded (override the binary with `CHROME_BIN`). CI runs both layers on every push and PR via `.github/workflows/local-ai-e2e.yml`.

`NDU_E2E_DUMP_TEXT=1` dumps the app's accessibility text and DOM for debugging, and `--strict-console` turns console errors into failures.

## Quickstart

```bash
dart pub get
dart test
flutterflow ai validate dsl/create.dart
flutterflow ai run dsl/create.dart --project-name "My App" --commit-message "Initial app"
```

Treat `flutterflow ai validate` as a real preflight check. If it reports wiring or validation failures, fix them before attempting `flutterflow ai run`.

If a new-project `flutterflow ai run` fails before a successful push, FlutterFlow AI will not bind that project into `.flutterflow/workspace.json`. It also does not delete remote projects automatically, so use `--find-or-create` on a retry when you want to reuse a project that may already exist.

For an existing project:

```bash
flutterflow ai inspect <project-id> --page HomePage
flutterflow ai validate dsl/edit.dart --project-id <project-id>
flutterflow ai run dsl/edit.dart --project-id <project-id> --commit-message "Update existing app"
```

## Files

- `dsl/create.dart`: starter create DSL file
- `dsl/edit.dart`: starter edit flow
- `test/app_test.dart`: starter compile test
- `references/`: working DSL examples copied locally into the workspace
- `patterns/`: edit helper patterns
- `PROJECT_CONTEXT.md`: project summary for bound edit workspaces
- `context/`: expanded project details written by FlutterFlow AI context generation
- `generated_code/`: local Flutter export snapshot when `flutterflow_cli` is available during `flutterflow ai init --project <id>`
- `.flutterflow/` (SDK-managed: run artifacts, plus router-managed config): local runtime artifacts such as history, traces, and support outputs

## Edit Context

- `flutterflow ai init --project <id>` writes `PROJECT_CONTEXT.md` when credentials are available.
- After the first successful push from a new unbound workspace, FlutterFlow AI also exports `generated_code/` when `flutterflow` CLI is available.
- Treat `generated_code/` as read-only reference context. Use it to inspect generated structure and map generated files back to FlutterFlow entities.
- Do not edit files in `generated_code/` directly. Apply changes in FlutterFlow AI-managed source such as `dsl/edit.dart`, then push with `flutterflow ai run`.
- If a task starts from a generated Dart file, use that file to identify the relevant page, component, or resource, then make the change through FlutterFlow AI instead of patching generated output.
- After a successful FlutterFlow AI push, `generated_code/` is marked stale instead of silently treated as current.
- Run `flutterflow ai codegen status` to see whether the snapshot is fresh or stale and which entities/files are likely affected.
- Run `flutterflow ai codegen refresh` to regenerate `generated_code/` for the bound project when you need a fresh snapshot.
- Run `flutterflow ai refresh-context <project-id>` after meaningful remote changes.
- Run `flutterflow ai context-check` if you are not sure whether local context is current.
- Use `flutterflow ai inspect` and `flutterflow ai resources` for exact current page, component, and resource details.
- Use `flutterflow ai inspect --dsl-json`, `--tree`, `--outline`, `--debug`, or `--deep` when you need a specific inspection mode rather than the default whole-project summary.
- Use `flutterflow ai inspect --selector-path <path>` or `--selector-key <key>` (with `--page` or `--component`) to target a single widget directly.

## FlutterFlow AI Selector Workflow

When the user pastes a `FlutterFlow AI Selector v1` block:

```
FlutterFlow AI Selector v1
project_id: abc123
scope_kind: page
scope_name: HomePage
selector_path: HomePage.body[0].children[1]
node_key: xyz789
node_name: MyButton
node_type: Button
```

1. Run: `flutterflow ai inspect abc123 --page HomePage --selector-path "HomePage.body[0].children[1]" --dsl-json`
2. Verify the returned widget matches expectations.
3. Patch with `findByPath(...)` in `dsl/edit.dart`:
   ```dart
   app.editPage('HomePage', (page) {
     page.findByPath('HomePage.body[0].children[1]').update((patch) {
       // modify properties
     });
   });
   ```
4. Run `dart test`, `flutterflow ai validate`, `flutterflow ai run`.

## Guardrails

- When a page or component contains multiple backend actions with outputs, set `outputAs:` explicitly on each one. This is especially important for multiple `ApiCall(...)` actions on the same page or trigger.
- Prefer updating an existing edit trigger chain instead of adding a second API call to the same trigger unless both outputs are deliberately named.
- Size loading indicators explicitly. Use `ProgressBar.circular(size: 40, thickness: 4)` rather than the unsized default.
- Avoid `shrinkWrap: true` on dynamic `ListView(...)` widgets unless the list truly must live inside another scrollable. Prefer giving the list bounded space and leaving shrink wrap off.

## Runtime Artifacts

- `.flutterflow/runs.jsonl`: local run history
- `.flutterflow/history/<run-id>/`: archived source files and plan
- `.flutterflow/traces/<run-id>.json`: canonical run trace
- `flutterflow ai history`, `flutterflow ai trace latest`, and `flutterflow ai support inspect <run-id>` are the main debugging entry points

## Source Tracking

FlutterFlow AI keeps the source that produced each run for auditability and replay.

- By default, `flutterflow ai run dsl/create.dart` or `flutterflow ai run dsl/edit.dart` tracks the executed DSL script.
- `flutterflow ai support bundle`, `flutterflow ai support replay`, and `flutterflow ai support case` build shareable or reproducible artifacts from traced runs.

## References

Start with a reference app before writing new DSL:

- For the broader DSL API surface, run `flutterflow ai docs api-surface`.
- For the widget/action authoring catalog, run `flutterflow ai docs ui`.
- `references/shopflow_dsl.dart`
- `references/taskboard_dsl.dart`
- `references/auth_shell_dsl.dart`
- `references/supabase_crud_auth_shell_dsl.dart`
- `references/social_feed_data_dsl.dart`
- `references/workflow_forms_dsl.dart`
- `references/commerce_shell_dsl.dart`
- `references/content_companion_dsl.dart`
- `references/resource_library_dsl.dart`
- `references/postgres_compile_only_dsl.dart`
- `references/action_block_showcase_dsl.dart`
- `references/app_event_showcase_dsl.dart`
- `references/genui_catalog_assistant_dsl.dart`
- `references/multi_api_call_dsl.dart`
- `references/local_state_crud_dsl.dart`
- `references/styled_profile_dsl.dart`
- `references/media_browser_dsl.dart`
- `references/asset_and_reference_surface_dsl.dart`
