// src/App.js
import React from 'react'
import Navbar from './components/Navbar'
import Dashboard from './components/Dashboard'
import { FilterProvider } from './contexts/FilterContext'
import './styles/global.css'

function App() {
	return (
		<div className='app'>
			<Navbar />
			<div className='app-container'>
				<FilterProvider>
					<Dashboard />
				</FilterProvider>
			</div>
			<footer className='app-footer'>
				<p>&copy; 2025 AI Impact Visualization Tool</p>
			</footer>
		</div>
	)
}

export default App
