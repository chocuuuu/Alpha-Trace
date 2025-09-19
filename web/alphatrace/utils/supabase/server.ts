import { createServerClient } from '@supabase/ssr'

type Cookie = { name: string; value: string; options?: any }
type CookieAdapter = {
  getAll: () => { name: string; value: string }[]
  setAll: (cookiesToSet: Cookie[]) => void
}

export function createServerSupabase(cookiesAdapter: CookieAdapter) {
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
    {
      cookies: {
        getAll: cookiesAdapter.getAll,
        setAll: cookiesAdapter.setAll,
      },
    }
  )
}
