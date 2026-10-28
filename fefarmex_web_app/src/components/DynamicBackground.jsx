import React, { useEffect, useState } from 'react';
import './DynamicBackground.css';

const DynamicBackground = () => {
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 });
  const [clicks, setClicks] = useState({});

  useEffect(() => {
    const handleMouseMove = (e) => {
      const x = (e.clientX / window.innerWidth) * 2 - 1;
      const y = (e.clientY / window.innerHeight) * 2 - 1;
      setMousePos({ x, y });
    };

    window.addEventListener('mousemove', handleMouseMove);
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  const handleClick = (id) => {
    // Activa la animación 3D
    setClicks(prev => ({ ...prev, [id]: true }));
    
    // Desactiva la animación después de 800ms
    setTimeout(() => {
      setClicks(prev => ({ ...prev, [id]: false }));
    }, 800);
  };

  const elements = [
    { id: 'pill1', baseClass: 'pill', posClass: 'pos-1', animClass: 'float-down', spinClass: 'spin-3d-slow', factor: -20, rotate: 45 },
    { id: 'capsule1', baseClass: 'capsule', posClass: 'pos-2', animClass: 'float-up', spinClass: 'spin-3d-alt', factor: 30, rotate: -30 },
    { id: 'pill2', baseClass: 'pill alt', posClass: 'pos-3', animClass: 'float-up', spinClass: 'spin-3d', factor: -40, rotate: 15 },
    { id: 'capsule2', baseClass: 'capsule alt', posClass: 'pos-4', animClass: 'float-down', spinClass: 'spin-3d-slow', factor: 15, rotate: 60 },
    { id: 'cross1', baseClass: 'cross', posClass: 'pos-5', animClass: 'float-up', spinClass: 'spin-3d', factor: -10, rotate: 0, isSvg: true }
  ];

  return (
    <div className="dynamic-background">
      {elements.map((item) => (
        // Wrapper 1: Posición inicial
        <div key={item.id} className={`element-position ${item.posClass}`}>
          
          {/* Wrapper 2: Parallax del mouse */}
          <div 
            className="parallax-wrapper"
            style={{ transform: `translate(${mousePos.x * item.factor}px, ${mousePos.y * item.factor}px)` }}
          >
            
            {/* Wrapper 3: Flote en el eje Y continuo */}
            <div className={`float-wrapper ${item.animClass}`}>
              
              {/* Wrapper 4: Rotación estática base en eje Z */}
              <div style={{ transform: `rotate(${item.rotate}deg)` }}>
                
                {/* Wrapper 5: Rotación 3D en el espacio (spin infinito) */}
                <div className={item.spinClass}>
                  
                  {/* Elemento interactivo con volumen CSS 3D */}
                  <div 
                    className={`shape ${item.baseClass} ${clicks[item.id] ? 'bump-3d' : ''}`}
                    onClick={() => handleClick(item.id)}
                  >
                    {item.isSvg && (
                      <svg viewBox="0 0 24 24" width="60" height="60" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round" style={{filter: 'drop-shadow(2px 4px 6px rgba(0,0,0,0.5))'}}>
                        <line x1="12" y1="5" x2="12" y2="19"></line>
                        <line x1="5" y1="12" x2="19" y2="12"></line>
                      </svg>
                    )}
                  </div>
                
                </div>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};

export default DynamicBackground;
