// app/dashboard/page.tsx
import { redirect } from 'next/navigation'
import { createServerSupabase } from '@/utils/supabase/clients'

export default async function Dashboard() {
  const supabase = createServerSupabase() // <-- No arguments needed
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return redirect('/login')
  }

  return <div>Welcome, {user.email}</div>
}

/* This file is adapted from code in the @supabase/ssr package under the MIT license: */