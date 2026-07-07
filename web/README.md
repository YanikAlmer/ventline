# Ventline Web

Next.js (App Router) dashboard for Ventline — job-site communication for
trades companies. Talks directly to the Supabase backend in `../supabase`
(all authorization is enforced by RLS/triggers in the database).

## Setup

1. Install dependencies:

   ```sh
   npm install
   ```

2. Configure environment variables. Copy the template and fill in the values
   from your Supabase project (Dashboard → Project Settings → API):

   ```sh
   cp .env.example .env.local
   ```

   | Variable | Description |
   | --- | --- |
   | `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL |
   | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Your Supabase anon (public) key |

## Development

```sh
npm run dev
```

Opens on http://localhost:3000. Sign up with a company name (you become the
owner) or with an invite code minted from the People page.

## Build & lint

```sh
npm run build   # production build
npm run lint    # eslint
npx tsc --noEmit
```

## Structure

- `src/middleware.ts` — Supabase session refresh + auth redirects
- `src/lib/supabase/` — typed browser/server/middleware clients
- `src/lib/` — `database.types.ts` (generated, do not edit), queries,
  formatting, storage and image helpers
- `src/app/(auth)/login` — sign in / sign up
- `src/app/onboarding` — create company / redeem invite for profile-less users
- `src/app/(app)/` — main dashboard (overview, project, task + chat, people,
  settings)
- `src/app/portal/` — read-only customer portal
- `src/components/` — UI components grouped by feature
