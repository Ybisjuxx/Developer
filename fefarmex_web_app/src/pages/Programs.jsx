import React from 'react';
import './Courses.css'; // Reusing styles

const Programs = () => {
  return (
    <div className="page-wrapper animate-fade-in">
      <div className="page-header" style={{backgroundColor: 'var(--color-primary)'}}>
        <div className="container text-center">
          <h1 className="page-title text-white">Lista de Programas</h1>
          <p className="page-subtitle text-white">Únete a nuestros programas de entrenamiento y retos (Challenges) gratuitos.</p>
        </div>
      </div>

      <section className="section bg-light text-center">
        <div className="container" style={{maxWidth: '800px', margin: '0 auto'}}>
          <div className="course-card glass-panel" style={{textAlign: 'left'}}>
            <div className="course-image" style={{height: '300px'}}>
              <span className="status-badge bg-accent">GRATUITO</span>
              <img src="https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&q=80&w=1200" alt="Transformación Internacional" />
            </div>
            <div className="course-content" style={{padding: '3rem'}}>
              <h2 className="course-title" style={{fontSize: '2rem'}}>Transformación Internacional en Farmacia</h2>
              <p className="course-desc" style={{fontSize: '1.1rem'}}>
                Un programa diseñado para impulsar tus habilidades más allá de las fronteras. Aprende de líderes en la industria farmacéutica global, desarrolla habilidades directivas y prepárate para los retos del sector salud internacional.
              </p>
              <div className="mt-4">
                <button className="btn btn-primary btn-lg w-100">Unirse al Programa</button>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default Programs;
