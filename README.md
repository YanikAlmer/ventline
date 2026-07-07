# Ventline

Job-site communication for trades companies (HVAC, electrical, plumbing, roofing, builders). One organized channel between field workers, site managers, and owners — instead of scattered WhatsApp threads.

**Projects → Tasks → task-scoped chat** with photos, photo markup, and voice messages, plus an at-a-glance overview of every project for managers and owners.

## Apps

| Directory | What | Stack |
|---|---|---|
| `ios/` | Primary app for the field (workers + managers) | Swift / SwiftUI, iOS 17+, XcodeGen |
| `web/` | Dashboard for managers/owners (workers can use it too) + read-only customer portal | Next.js 16, TypeScript, Tailwind 4 |
| `supabase/` | Backend: Postgres schema, RLS, storage, auth | Supabase (migrations in-repo) |

## Roles

- **Owner** — everything in the company
- **Manager** — all projects, manage people and invites
- **Foreman (site manager)** — their projects: assign tasks, approve completions
- **Worker** — assigned tasks, chat, photos/voice
- **Customer** — read-only portal: only tasks and photos explicitly shared with them, only for their own project

## Quickstart

1. **Supabase** — create a project at [supabase.com](https://supabase.com), then:
   ```sh
   npm install
   npx supabase link --project-ref <your-project-ref>
   npx supabase db push
   ```
   Details: [docs/supabase-setup.md](docs/supabase-setup.md)

2. **Web** — `cd web && cp .env.example .env.local` (fill in project URL + anon key), `npm install && npm run dev`.

3. **iOS** — on a Mac: `brew install xcodegen`, then `cd ios && xcodegen generate`, fill `Config/Secrets.xcconfig`, open `Ventline.xcodeproj`. Details: [docs/ios-setup.md](docs/ios-setup.md)

## Development

```sh
npm run db:validate   # apply all migrations + RLS tests against a local scratch Postgres
npm run db:types      # regenerate TypeScript + Swift models from the schema
```

Docs: [architecture](docs/architecture.md) · [schema & permissions](docs/schema.md)
