// src/components/Navbar.js
import React from 'react'

const Navbar = () => {
	return (
		<nav className='navbar'>
			<div className='navbar-logo'>
				<h1>AI Impact Visualization</h1>
			</div>
			<div className='navbar-links'>
				<a href='#dashboard' className='active'>
					Dashboard
				</a>
				<a href='#reports'>Reports</a>
				<a href='#settings'>Settings</a>
			</div>
			<div className='navbar-user'>
				<span className='user-info'>Admin User</span>
				<button className='logout-button'>Logout</button>
			</div>
		</nav>
	)
}

export default Navbar
