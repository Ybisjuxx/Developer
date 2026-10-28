import React from 'react';
import { Lock, Mail } from 'lucide-react';
import './Auth.css';

const Auth = () => {
  return (
    <div className="auth-page animate-fade-in" style={{backgroundImage: `url('/hero_bg.png')`}}>
      <div className="auth-overlay"></div>
      
      <div className="container auth-container">
        <div className="auth-card glass-panel">
          <div className="text-center mb-4">
            <img src="/logo.png" alt="Logo" className="auth-logo" />
            <h2 className="auth-title">Bienvenido de nuevo</h2>
            <p className="auth-subtitle">Inicia sesión en tu cuenta de FEFARMEX</p>
          </div>

          <form className="auth-form" onSubmit={(e) => e.preventDefault()}>
            <div className="form-group">
              <label>Correo Electrónico</label>
              <div className="input-with-icon">
                <Mail className="input-icon" size={20} />
                <input type="email" placeholder="tucorreo@ejemplo.com" className="form-control" />
              </div>
            </div>
            
            <div className="form-group">
              <div className="label-flex">
                <label>Contraseña</label>
                <a href="#" className="forgot-link">¿Olvidaste tu contraseña?</a>
              </div>
              <div className="input-with-icon">
                <Lock className="input-icon" size={20} />
                <input type="password" placeholder="••••••••" className="form-control" />
              </div>
            </div>

            <button type="submit" className="btn btn-primary btn-lg w-100 mt-4">
              Iniciar Sesión
            </button>
          </form>

          <div className="auth-footer text-center mt-4">
            <p>¿Aún no tienes cuenta? <a href="#" className="register-link">Regístrate aquí</a></p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Auth;
