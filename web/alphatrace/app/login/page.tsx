// app/login/page.tsx
'use client'
import { createBrowserSupabase } from '@/utils/supabase/clients'

export default function Login() {
  const supabase = createBrowserSupabase()
  const signIn = async () => {
    await supabase.auth.signInWithOAuth({
      provider: 'github',
      options: { redirectTo: `${window.location.origin}/` }
    })
  }
  return <button onClick={signIn}>Sign in with GitHub</button>
}
