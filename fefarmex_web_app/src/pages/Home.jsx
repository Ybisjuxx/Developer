import React from 'react';
import { ArrowRight, BookOpen, HeartPulse, Award } from 'lucide-react';
import './Home.css';
import { Link } from 'react-router-dom';

const Home = () => {
  return (
    <div className="home-page animate-fade-in">
      {/* Hero Section */}
      <section className="hero-section" style={{backgroundImage: `url('/hero_bg.png')`}}>
        <div className="hero-overlay"></div>
        <div className="container hero-content">
          <span className="hero-subtitle">¡BIENVENIDOS!</span>
          <h1 className="hero-title">"La revolución farmacéutica es ahora"</h1>
          <p className="hero-desc">¡Únete a la Federación Farmacéutica Mexicana y forma parte del cambio!</p>
          <div className="hero-actions">
            <a href="https://docs.google.com/forms/d/e/1FAIpQLSdiajNwmvtX5wXUmfe5W89lcJZKx4RruZxOq05GGXOYtPVLHg/viewform?usp=header" target="_blank" rel="noreferrer" className="btn btn-accent btn-lg">
              Afíliate Ahora <ArrowRight size={20} />
            </a>
            <Link to="/cursos" className="btn btn-outline-light btn-lg">Explorar Cursos</Link>
          </div>
        </div>
      </section>

      {/* Origen del Logo */}
      <section className="section bg-light">
        <div className="container">
          <div className="logo-origin-grid">
            <div className="logo-image-col">
              <div className="glass-panel logo-showcase">
                <img src="/logo.png" alt="FEFARMEX Logo" />
              </div>
            </div>
            <div className="logo-text-col">
              <h2 className="section-title" style={{textAlign: 'left', marginLeft: '0'}}>Origen de nuestra identidad</h2>
              <div className="feature-item">
                <div className="feature-icon"><HeartPulse /></div>
                <div>
                  <h3>La Copa y la Serpiente</h3>
                  <p>Símbolo internacional de la farmacia, la copa de Higía representa la salud y la medicina, mientras que la serpiente simboliza el renacimiento y el rejuvenecimiento.</p>
                </div>
              </div>
              <div className="feature-item">
                <div className="feature-icon"><Award /></div>
                <div>
                  <h3>La Serpiente Emplumada</h3>
                  <p>Kukulkán fusionado en nuestro diseño representa nuestra identidad mexicana profunda, conectando nuestras raíces culturales con la excelencia científica.</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Historia */}
      <section className="section">
        <div className="container">
          <h2 className="section-title">Nuestra Historia</h2>
          <div className="history-content glass-panel">
            <p className="lead-text">Fundada en Huejotzingo, Puebla en 2016.</p>
            <p>
              FEFARMEX nació de la visión de un grupo de estudiantes de la Benemérita Universidad Autónoma de Puebla (BUAP) de las carreras de Farmacia y Químico Farmacobiólogo. 
            </p>
            <p>
              Empezó como un proyecto para unificar a los estudiantes, pero rápidamente se transformó en una Federación representativa que busca impulsar la ciencia, la educación y el valor del profesional farmacéutico a nivel nacional e internacional.
            </p>
          </div>
        </div>
      </section>
      
      {/* IPSF Event */}
      <section className="section bg-primary text-white" style={{backgroundColor: 'var(--color-primary-dark)'}}>
        <div className="container text-center">
          <h2 className="section-title text-white">Próximo Gran Evento</h2>
          <div className="event-banner">
            <div className="event-banner-image">
              <img src="/evento.jpg" alt="19th PARS Puebla" className="event-banner-img" />
            </div>
            <div className="event-banner-content">
              <h3 className="event-title">19th PARS Puebla, México</h3>
              <p className="event-subtitle">Panamerican Regional Symposium - IPSF</p>
              {/* Cambia el href por el enlace real a tu formulario de registro o pago */}
              <a href="https://docs.google.com/forms/d/e/1FAIpQLSeVD8-sorX8UJFLdX_LLwp-nVBkzwDYVI-Dce0yZX6Ult2UnQ/viewform?usp=header" target="_blank" rel="noreferrer" className="btn btn-accent mt-4">
                Registrarse al Evento
              </a>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default Home;
