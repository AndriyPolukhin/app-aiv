'use client'

import React, { createContext, useContext, type ReactNode } from 'react'
import type { User } from '@/utils/types'
import { useUser } from '@/hooks/useUser'

interface UserContextType {
	user: User | null
	loading: boolean
	error: string | null
	refetch: () => Promise<void>
}

const UserContext = createContext<UserContextType | undefined>(undefined)

export function UserProvider({ children }: { children: ReactNode }) {
	const { user, loading, error, refetch } = useUser()

	return (
		<UserContext.Provider value={{ user, loading, error, refetch }}>
			{children}
		</UserContext.Provider>
	)
}

export function useUserContext() {
	const context = useContext(UserContext)
	if (context === undefined) {
		throw new Error('useUserContext must be used within a UserProvider')
	}
	return context
}
