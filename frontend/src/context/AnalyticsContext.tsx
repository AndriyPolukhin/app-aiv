// context/AnalyticsContext.tsx
import { createContext, useContext, ReactNode } from 'react'
import { usePostHog } from '../hooks/usePostHog'
import { useUserContext } from '@/context/UserContext'

const AnalyticsContext = createContext<
	ReturnType<typeof usePostHog> | undefined
>(undefined)

export function AnalyticsProvider({ children }: { children: ReactNode }) {
	const { user } = useUserContext()
	const analytics = usePostHog({
		apiKey: process.env.NEXT_PUBLIC_POSTHOG_KEY!,
		options: {
			api_host: process.env.NEXT_PUBLIC_POSTHOG_HOST,
		},
		user: user || undefined,
	})

	return (
		<AnalyticsContext.Provider value={analytics}>
			{children}
		</AnalyticsContext.Provider>
	)
}

export const useAnalytics = () => {
	const context = useContext(AnalyticsContext)
	if (context === undefined) {
		throw new Error('useAnalytics must be used within an AnalyticsProvider')
	}
	return context
}
