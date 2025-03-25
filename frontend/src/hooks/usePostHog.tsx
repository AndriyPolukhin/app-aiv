// hooks/usePostHog.tsx
import { ANALYTICS_EVENTS } from '@/utils/enums'
import { determineUserType } from '@/utils/utils'
import posthog from 'posthog-js'
import { useEffect, useState } from 'react'
import { User } from '@/utils/types'

type PostHog = typeof posthog

interface AnalyticsConfig {
	apiKey: string
	options?: {
		api_host?: string
		loaded?: (posthog: PostHog) => void
	}
	user?: User
}

export const usePostHog = ({ apiKey, options = {}, user }: AnalyticsConfig) => {
	const [isInitialized, setIsInitialized] = useState(false)

	useEffect(() => {
		if (!isInitialized && typeof window !== 'undefined') {
			const userType = determineUserType()
			posthog.init(apiKey, {
				api_host: options.api_host || 'https://us.i.posthog.com',
				loaded: (ph) => {
					// Set the user_type property based on the
					ph.register({ user_type: userType })
					if (options.loaded) options.loaded(ph)
				},
				capture_pageview: true,
				capture_pageleave: true,
			})
			setIsInitialized(true)
		}
	}, [apiKey, isInitialized, options])

	useEffect(() => {
		if (user) {
			// Identify the user
			posthog.identify(user.email)
			// Set additional properties for the identified user
			posthog.people.set({
				email: user.email,
				name: `${user.first_name} ${user.last_name}`,
				provider_sso: user.provider_sso,
			})
		}
	}, [user?.email])

	const trackSignup = (
		userEmail: string,
		properties?: Record<string, any>,
	) => {
		posthog.identify(userEmail)
		posthog.capture(ANALYTICS_EVENTS.USER_SIGNUP, {
			distinct_id: userEmail,
			...properties,
		})
	}

	const trackSignin = (
		userEmail: string,
		properties?: Record<string, any>,
	) => {
		posthog.identify(userEmail)
		posthog.capture(ANALYTICS_EVENTS.USER_SIGNIN, {
			distinct_id: userEmail,
			...properties,
		})
	}

	const trackIntegrationConnected = (
		connectionId: string,
		provider: string,
		userEmail: string | undefined,
	) => {
		posthog.capture(ANALYTICS_EVENTS.INTEGRATION_CONNECTED, {
			distinct_id: userEmail,
			provider: provider,
			connection_id: connectionId,
			user_email: userEmail,
			status: 'success',
			label: 'integration_management',
			timestamp: new Date().toISOString(),
		})
	}

	const trackIntegrationDisconnected = (
		connectionId: string,
		provider: string,
		userEmail: string | null,
	) => {
		posthog.capture(ANALYTICS_EVENTS.INTEGRATION_DISCONNECTED, {
			distinct_id: userEmail,
			provider: provider,
			connection_id: connectionId,
			user_email: userEmail,
			status: 'success',
			label: 'integration_management',
			timestamp: new Date().toISOString(),
		})
	}

	return {
		isInitialized,
		trackSignup,
		trackSignin,
		trackIntegrationConnected,
		trackIntegrationDisconnected,
	}
}
