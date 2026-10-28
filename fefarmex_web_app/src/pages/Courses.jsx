import React from 'react';
import './Courses.css';

const coursesData = [
  {
    id: 1,
    title: 'Simposio Nacional',
    description: 'Participa en nuestro próximo simposio con expositores internacionales.',
    price: '$5,999 MXN',
    status: 'INSCRIPCIONES CERRADAS',
    image: '/SNIF.jpg',
    date: 'Próximamente'
  },
  {
    id: 2,
    title: 'Curso Digital en Farmacia',
    description: 'Actualízate con los temas más relevantes de nuestra profesión desde cualquier lugar.',
    price: '$249 MXN',
    status: 'PREGUNTA POR INFO',
    image: 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?auto=format&fit=crop&q=80&w=800',
    date: 'En actualización'
  },
  {
    id: 3,
    title: 'Curso de Farmacovigilancia',
    description: 'Fundamentos y regulaciones actuales para el monitoreo de medicamentos.',
    price: '$359 MXN',
    status: 'PRÓXIMAMENTE',
    image: '/COHEFA_CONF.JPG',
    date: 'En actualización'
  }
];

const Courses = () => {
  return (
    <div className="page-wrapper animate-fade-in">
      <div className="page-header bg-primary">
        <div className="container text-center">
          <h1 className="page-title text-white">Reserva Online</h1>
          <p className="page-subtitle text-white">Explora nuestro catálogo de cursos, simposios y eventos.</p>
        </div>
      </div>

      <section className="section bg-light">
        <div className="container">
          <div className="courses-grid">
            {coursesData.map(course => (
              <div key={course.id} className="course-card glass-panel">
                <div className="course-image">
                  <span className={`status-badge ${course.status === 'DISPONIBLE' ? 'bg-success' : 'bg-accent'}`}>
                    {course.status}
                  </span>
                  <img src={course.image} alt={course.title} />
                </div>
                <div className="course-content">
                  <div className="course-meta">
                    <span className="course-date">{course.date}</span>
                    <span className="course-price">{course.price}</span>
                  </div>
                  <h3 className="course-title">{course.title}</h3>
                  <p className="course-desc">{course.description}</p>
                  <button className="btn btn-primary w-100 mt-auto">Reservar Lugar</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </div>
  );
};

export default Courses;
