import { exec } from 'child_process'
import { Command } from 'commander'
import { createRequire } from 'module'

const require = createRequire(import.meta.url)
const packageJson = require('./package.json')

const program = new Command()

program
	.name('data-processor')
	.description('CLI for database processing operations')
	.version(packageJson.version)
	.option('--setup', 'Complete setup (create DB, functions, and seed data)')
	.option('--create-db', 'Create the database')
	.option('--create-fns', 'Create database functions')
	.option('--seed-db', 'Seed the database with initial data')
	.option('--drop-db', 'Drop the database')
	.option('--reset-db', 'Reset the database (drop, create, and seed)')
	.parse(process.argv)

const options = program.opts()

async function main() {
	try {
		if (options.setup) {
			await runCommand('npm run create-db')
			await runCommand('npm run create-fns')
			await runCommand('npm run seed-db')
		} else if (options['reset-db']) {
			await runCommand('npm run drop-db')
			await runCommand('npm run create-db')
			await runCommand('npm run create-fns')
			await runCommand('npm run seed-db')
		} else if (options['create-db']) {
			await runCommand('npm run create-db')
		} else if (options['create-fns']) {
			await runCommand('npm run create-fns')
		} else if (options['seed-db']) {
			await runCommand('npm run seed-db')
		} else if (options['drop-db']) {
			await runCommand('npm run drop-db')
		} else {
			program.help()
		}
	} catch (error) {
		console.error('Error:', error.message)
		process.exit(1)
	}
}

function runCommand(command) {
	return new Promise((resolve, reject) => {
		console.log(`\nRunning: ${command}`)
		const child = exec(command)

		child.stdout.pipe(process.stdout)
		child.stderr.pipe(process.stderr)

		child.on('close', (code) => {
			if (code !== 0) {
				return reject(
					new Error(`Command failed with exit code ${code}`),
				)
			}
			resolve()
		})
	})
}

main()
