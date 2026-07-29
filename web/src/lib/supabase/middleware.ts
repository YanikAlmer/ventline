import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import type { Database } from "@/lib/database.types";

/**
 * Paths reachable without a session.
 *
 * `/r` is the customer magic link, and its absence here made the entire
 * feature unreachable by the only people it was built for: a customer with no
 * account followed their link and was bounced to a sign-in page they cannot
 * pass. Everything behind it was right — the hashed token, the definer
 * resolver, the rate limit, the signed URL — and the door was locked.
 *
 * It survived every test because the tests were run while signed in, which is
 * the one state in which the bug is invisible.
 *
 * The legal pages are public because App Store Connect fetches the privacy
 * policy URL unauthenticated, and because a policy you must log in to read is
 * not a published policy.
 */
const PUBLIC_PATHS = ["/login", "/auth", "/r", "/datenschutz", "/privacy"];

function isPublicPath(pathname: string) {
  return PUBLIC_PATHS.some(
    (p) => pathname === p || pathname.startsWith(`${p}/`)
  );
}

export async function updateSession(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  // Refresh the auth token. Do not run other code between client creation
  // and getUser() — the call also writes refreshed cookies via setAll above.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user && !isPublicPath(request.nextUrl.pathname)) {
    const url = request.nextUrl.clone();
    url.pathname = "/login";
    url.search = "";
    return NextResponse.redirect(url);
  }

  return supabaseResponse;
}
