# iOS app setup (Mac required)

The Xcode project is generated from `ios/project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` itself
is never committed.

## Prerequisites

- Xcode 16.3 or newer (Swift 6.1+ toolchain — required by supabase-swift 2.50)
- Homebrew

## Build steps

```sh
brew install xcodegen

cd ios
cp Ventline/Config/Secrets.example.xcconfig Ventline/Config/Secrets.xcconfig
# edit Secrets.xcconfig: set SUPABASE_URL and SUPABASE_ANON_KEY
#   (Supabase Dashboard -> Project Settings -> API)

xcodegen generate
open Ventline.xcodeproj
```

In Xcode: select the `Ventline` scheme, pick your team under
Signing & Capabilities (bundle id `com.ventline.app` — change it in
`project.yml` if it collides), then Run.

## First-build triage

This project was authored without a Mac in the loop, so the very first build
may surface small issues. Where to look:

| Symptom | Fix |
|---|---|
| SPM cannot resolve `supabase-swift` | Xcode → File → Packages → Reset Package Caches; check network/proxy |
| `Missing Supabase credentials` crash on launch | `Secrets.xcconfig` missing or still has placeholder values; re-run `xcodegen generate` after creating it |
| Concurrency / actor-isolation errors | The target builds in Swift language mode 5 (see `SWIFT_VERSION` in project.yml). If your Xcode defaults differ, ensure the setting survived generation |
| Type mismatches in `GeneratedModels.swift` usage | Regenerate types (`npm run db:types` at repo root) so models match the schema |
| Signing errors | Set your development team on the target; change the bundle identifier |

If an API call site fails to compile against a newer supabase-swift, pin the
package back to **exactly 2.50.0** (project.yml → `exactVersion`) — the code
was written and verified against that tag's source.

## Structure

```
ios/Ventline/
├── App/         entry point, root navigation, session state
├── Core/
│   ├── Supabase/     shared client + model typealiases
│   ├── Models/       GeneratedModels.swift (generated — do not edit), display helpers
│   ├── Repositories/ all data access (projects, tasks, messages, people)
│   └── Support/      media upload, signed-URL cache, image downscaling
├── Features/
│   ├── Auth/         sign in / sign up / onboarding
│   ├── Projects/     overview cards, project detail, team sheet
│   ├── Tasks/        my tasks, task detail + status flow, new task
│   ├── Chat/         thread UI, composer, voice recorder, audio player
│   ├── Markup/       PencilKit photo annotation
│   ├── People/       roster, roles, invite codes
│   ├── Customer/     read-only customer portal
│   └── Settings/
└── Config/      xcconfig files (secrets are gitignored)
```

## Conventions

- All data access goes through `Core/Repositories`; views never call
  PostgREST directly (exception: the customer portal's message feed).
- Authorization lives in the database (RLS + triggers). The UI hides
  buttons users can't use, but the server is the enforcement point.
- Timestamps travel as ISO-8601 strings and are parsed via `Timestamps`.
- Photo markup stores strokes in image-pixel space (see
  `PhotoMarkupView.swift`) so annotations re-open correctly at any display
  size, plus a flattened JPEG for web display.
