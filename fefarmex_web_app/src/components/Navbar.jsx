import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { User, Menu, X } from 'lucide-react';
import './Navbar.css';

const Navbar = () => {
  const [isOpen, setIsOpen] = React.useState(false);
  const location = useLocation();

  const toggleMenu = () => setIsOpen(!isOpen);

  const isActive = (path) => location.pathname === path ? 'active' : '';

  return (
    <header className="navbar glass-panel">
      <div className="container nav-container">
        <Link to="/" className="brand">
          <img src="/logo.png" alt="FEFARMEX Logo" className="brand-logo" />
          <span className="brand-text">FEFARMEX</span>
        </Link>
        
        <button className="mobile-toggle" onClick={toggleMenu} aria-label="Toggle Menu">
          {isOpen ? <X size={24} /> : <Menu size={24} />}
        </button>

        <nav className={`nav-links ${isOpen ? 'open' : ''}`}>
          <Link to="/" className={`nav-link ${isActive('/')}`} onClick={() => setIsOpen(false)}>Inicio</Link>
          <Link to="/cursos" className={`nav-link ${isActive('/cursos')}`} onClick={() => setIsOpen(false)}>Reserva online</Link>
          <Link to="/programas" className={`nav-link ${isActive('/programas')}`} onClick={() => setIsOpen(false)}>Programas</Link>
          <Link to="/login" className="btn btn-outline login-btn" onClick={() => setIsOpen(false)}>
            <User size={18} />
            Iniciar sesión
          </Link>
        </nav>
      </div>
    </header>
  );
};

export default Navbar;
