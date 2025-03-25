export interface User {
	email: string
	email_verified: boolean | null
	on_boarding_complete: boolean | null
	company?: string | null
	provider_sso?: string | null
	job_role_fields?: { [key: string]: string } | null
	first_name?: string | null
	last_name?: string | null
	avatar?: string | null
}
