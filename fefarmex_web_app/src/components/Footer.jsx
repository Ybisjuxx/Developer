import React from 'react';
import { Mail, Phone, MapPin, LayoutTemplate, Globe, Link as LinkIcon } from 'lucide-react';
import './Footer.css';

const Footer = () => {
  return (
    <footer className="footer bg-primary-dark">
      <div className="container footer-container">
        <div className="footer-col about">
          <div className="footer-brand">
            <img src="/logo.png" alt="FEFARMEX" className="footer-logo" />
            <h3 className="footer-title">FEFARMEX</h3>
          </div>
          <p className="footer-desc">
            La Federación Farmacéutica Mexicana, uniendo y transformando a los profesionales de la farmacia en México.
          </p>
          <div className="social-links">
            <a href="#" className="social-link" aria-label="Facebook"><Globe size={20} /></a>
            <a href="#" className="social-link" aria-label="Instagram"><LinkIcon size={20} /></a>
            <a href="#" className="social-link" aria-label="Wix Site"><LayoutTemplate size={20} /></a>
          </div>
        </div>

        <div className="footer-col links">
          <h4 className="footer-heading">Navegación</h4>
          <ul>
            <li><a href="/">Inicio</a></li>
            <li><a href="/cursos">Reserva online</a></li>
            <li><a href="/programas">Lista de programas</a></li>
            <li><a href="/login">Iniciar sesión</a></li>
          </ul>
        </div>

        <div className="footer-col contact">
          <h4 className="footer-heading">Contacto</h4>
          <ul className="contact-info">
            <li>
              <MapPin size={18} className="contact-icon" />
              <span>Prolongación 24 Sur S/N Ciudad Universitaria, San Manuel 72570,<br/>Puebla, Puebla, México.</span>
            </li>
            <li>
              <Phone size={18} className="contact-icon" />
              <span>+52 55 77 44 64 25</span>
            </li>
            <li>
              <Mail size={18} className="contact-icon" />
              <a href="mailto:fefarmex@gmail.com">fefarmex@gmail.com</a>
            </li>
          </ul>
        </div>
      </div>
      
      <div className="footer-bottom">
        <p>&copy; {new Date().getFullYear()} FEFARMEX. Todos los derechos reservados.</p>
      </div>
    </footer>
  );
};

export default Footer;
