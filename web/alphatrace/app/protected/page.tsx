import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import { InfoIcon } from 'lucide-react'
import { FetchDataSteps } from '@/components/tutorial/fetch-data-steps'

export default async function ProtectedPage() {
  // createClient() should return a server-side Supabase client with a valid cookie adapter
  // See notes below to ensure '@/lib/supabase/server' is up to date with getAll/setAll.
  const supabase = await createClient()

  // Gate with getUser() instead of getClaims()
  const { data: { user }, error } = await supabase.auth.getUser()
  if (error || !user) {
    redirect('/auth/login')
  }

  // Optionally fetch claims if you want to show them, but don't use as the gate
  const { data: claimsData } = await supabase.auth.getClaims().catch(() => ({ data: undefined }))

  return (
    <div className="flex-1 w-full flex flex-col gap-12">
      <div className="w-full">
        <div className="bg-accent text-sm p-3 px-5 rounded-md text-foreground flex gap-3 items-center">
          <InfoIcon size={16} strokeWidth={2} />
          This is a protected page that you can only see as an authenticated user
        </div>
      </div>

      <div className="flex flex-col gap-2 items-start">
        <h2 className="font-bold text-2xl mb-4">Your user details</h2>
        <pre className="text-xs font-mono p-3 rounded border max-h-32 overflow-auto">
          {JSON.stringify(
            {
              id: user.id,
              email: user.email,
              app_metadata: user.app_metadata,
              user_metadata: user.user_metadata,
            },
            null,
            2
          )}
        </pre>
      </div>

      {claimsData?.claims && (
        <div className="flex flex-col gap-2 items-start">
          <h2 className="font-bold text-2xl mb-4">Token claims (optional)</h2>
          <pre className="text-xs font-mono p-3 rounded border max-h-32 overflow-auto">
            {JSON.stringify(claimsData.claims, null, 2)}
          </pre>
        </div>
      )}

      <div>
        <h2 className="font-bold text-2xl mb-4">Next steps</h2>
        <FetchDataSteps />
      </div>
    </div>
  )
}
