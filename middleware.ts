import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function middleware(request: NextRequest) {
  let response = NextResponse.next({ request });
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  // Preview mode allows the public overview/login UI to run without credentials.
  // Protected routes fail closed if Supabase is not configured.
  if (!url || !key) {
    if (request.nextUrl.pathname.startsWith("/dashboard")) {
      const target = new URL("/login", request.url);
      target.searchParams.set("next", request.nextUrl.pathname);
      return NextResponse.redirect(target);
    }
    return response;
  }

  const supabase = createServerClient(url, key, {
    cookies: {
      getAll() { return request.cookies.getAll(); },
      setAll(cookiesToSet) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookiesToSet.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });

  const { data: { user } } = await supabase.auth.getUser();
  const path = request.nextUrl.pathname;
  if (path.startsWith("/dashboard") && !user) {
    const target = new URL("/login", request.url);
    target.searchParams.set("next", path);
    return NextResponse.redirect(target);
  }
  if ((path === "/login") && user) return NextResponse.redirect(new URL("/dashboard", request.url));
  return response;
}

export const config = { matcher: ["/dashboard/:path*", "/login"] };
