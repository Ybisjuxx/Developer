// main.js

document.addEventListener('DOMContentLoaded', () => {

    // 1. Funcionalidad del Menú Hamburguesa (Mobile)
    const hamburger = document.getElementById('hamburger');
    const navLinks = document.getElementById('nav-links');
    const links = document.querySelectorAll('.nav-link');

    hamburger.addEventListener('click', () => {
        navLinks.classList.toggle('active');
        hamburger.classList.toggle('active');
    });

    // Cerrar menú al hacer clic en un enlace (Mobile)
    links.forEach(link => {
        link.addEventListener('click', () => {
            if (navLinks.classList.contains('active')) {
                navLinks.classList.remove('active');
                hamburger.classList.remove('active');
            }
        });
    });

    // 2. Transición del Navbar al hacer Scroll
    const navbar = document.getElementById('navbar');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            navbar.style.background = 'rgba(20, 20, 30, 0.95)';
            navbar.style.boxShadow = '0 4px 30px rgba(0, 0, 0, 0.5)';
        } else {
            navbar.style.background = 'rgba(20, 20, 30, 0.7)';
            navbar.style.boxShadow = 'none';
        }
    });

    // 3. Smooth Scroll general para enlaces con ancla (#)
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const targetId = this.getAttribute('href');
            if(targetId === '#') return;
            
            const targetElement = document.querySelector(targetId);
            if(targetElement) {
                // Offset de 80px para compensar el navbar sticky
                const offsetTop = targetElement.getBoundingClientRect().top + window.scrollY - 80;
                window.scrollTo({
                    top: offsetTop,
                    behavior: 'smooth'
                });
            }
        });
    });

    // 4. Animaciones de Reveal al hacer Scroll (Intersection Observer)
    const reveals = document.querySelectorAll('.reveal');

    const revealOptions = {
        threshold: 0.15,
        rootMargin: "0px 0px -50px 0px"
    };

    const revealOnScroll = new IntersectionObserver(function(entries, observer) {
        entries.forEach(entry => {
            if (!entry.isIntersecting) {
                return;
            } else {
                entry.target.classList.add('active');
                observer.unobserve(entry.target);
            }
        });
    }, revealOptions);

    reveals.forEach(reveal => {
        revealOnScroll.observe(reveal);
    });

    // 5. Agendador Gratuito por WhatsApp (con restricciones de fecha)
    const waForm = document.getElementById('whatsapp-scheduler');
    if (waForm) {
        const fechaInput = document.getElementById('wa-fecha');
        const horarioSelect = document.getElementById('wa-horario');

        // Escuchar cuando eligen una fecha
        fechaInput.addEventListener('change', function() {
            if (!this.value) {
                horarioSelect.innerHTML = '<option value="">(Elige una fecha a la izquierda primero)</option>';
                return;
            }
            
            // Parsear la fecha evitando problemas de zona horaria local
            const [year, month, day] = this.value.split('-');
            const dateVal = new Date(year, month - 1, day);
            const dayOfWeek = dateVal.getDay(); // 0=Domingo, 1=Lunes... 6=Sábado
            
            horarioSelect.innerHTML = '<option value="">¿En qué horario?</option>';
            
            if (dayOfWeek >= 1 && dayOfWeek <= 5) {
                // Lunes a Viernes (5pm a 9pm)
                horarioSelect.innerHTML += '<option value="(L-V) 5:00 PM">5:00 PM</option>';
                horarioSelect.innerHTML += '<option value="(L-V) 6:00 PM">6:00 PM</option>';
                horarioSelect.innerHTML += '<option value="(L-V) 7:00 PM">7:00 PM</option>';
                horarioSelect.innerHTML += '<option value="(L-V) 8:00 PM">8:00 PM</option>';
            } else if (dayOfWeek === 6) {
                // Sábado (11am a 4pm)
                horarioSelect.innerHTML += '<option value="(Sáb) 11:00 AM">11:00 AM</option>';
                horarioSelect.innerHTML += '<option value="(Sáb) 12:00 PM">12:00 PM</option>';
                horarioSelect.innerHTML += '<option value="(Sáb) 1:00 PM">1:00 PM</option>';
                horarioSelect.innerHTML += '<option value="(Sáb) 2:00 PM">2:00 PM</option>';
                horarioSelect.innerHTML += '<option value="(Sáb) 3:00 PM">3:00 PM</option>';
            } else if (dayOfWeek === 0) {
                // Domingo (11am a 4pm con cargo extra)
                horarioSelect.innerHTML += '<option value="(Dom) 11:00 AM (+ Costo extra $250)">11:00 AM (Aplica extra de $250)</option>';
                horarioSelect.innerHTML += '<option value="(Dom) 12:00 PM (+ Costo extra $250)">12:00 PM (Aplica extra de $250)</option>';
                horarioSelect.innerHTML += '<option value="(Dom) 1:00 PM (+ Costo extra $250)">1:00 PM (Aplica extra de $250)</option>';
                horarioSelect.innerHTML += '<option value="(Dom) 2:00 PM (+ Costo extra $250)">2:00 PM (Aplica extra de $250)</option>';
                horarioSelect.innerHTML += '<option value="(Dom) 3:00 PM (+ Costo extra $250)">3:00 PM (Aplica extra de $250)</option>';
            }
        });

        // Al enviar
        waForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const nombre = document.getElementById('wa-nombre').value;
            const correo = document.getElementById('wa-correo').value;
            const ubicacion = document.getElementById('wa-ubicacion').value;
            const servicio = document.getElementById('wa-servicio').value;
            const fecha = document.getElementById('wa-fecha').value;
            const horario = document.getElementById('wa-horario').value;
            
            const telefono = "525577446425"; 
            
            // IMPORTANTE: URL DEL WEB APP DE GOOGLE SHEETS
            // Reemplaza "TU_URL_DE_GOOGLE_AQUI" con el enlace que Google te dé al publicar el script
            const googleAppUrl = "TU_URL_DE_GOOGLE_AQUI"; 
            
            // Botón interactivo
            const btn = waForm.querySelector('.btn-enviar');
            const originalText = btn.innerText;
            btn.innerText = "Preparando cita...";

            // Armar paquete de datos para Sheets
            const formData = new FormData();
            formData.append("Nombre", nombre);
            formData.append("Correo", correo);
            formData.append("Ubicacion", ubicacion);
            formData.append("Servicio", servicio);
            formData.append("Fecha", fecha);
            formData.append("Horario", horario);

            // Armar mensaje nativo de WhatsApp
            const mensaje = `¡Hola Emmanuel! 👋%0A%0ASoy *${nombre}* (de *${ubicacion}*). Me gustaría agendar una asesoría contigo sobre *${servicio}*.%0A%0AMe gustaría apartar el día *${fecha}* a las *${horario}*.%0A%0AMi correo es: ${correo}%0A%0A¿Tendrás disponibilidad?`;
            const waUrl = `https://api.whatsapp.com/send?phone=${telefono}&text=${mensaje}`;

            // Enviar a la base de datos silenciosamente (sólo si cambian el link)
            if(googleAppUrl !== "TU_URL_DE_GOOGLE_AQUI") {
                 fetch(googleAppUrl, {
                     method: 'POST',
                     body: formData,
                     mode: 'no-cors' // Super importante para que Google no bloquee la petición
                 }).then(() => {
                     // Sin importar la respuesta, se abre la ventana de WA para no perder la venta
                     btn.innerText = originalText;
                     window.open(waUrl, '_blank');
                 }).catch(() => {
                     btn.innerText = originalText;
                     window.open(waUrl, '_blank');
                 });
            } else {
                 btn.innerText = originalText;
                 window.open(waUrl, '_blank');
            }
        });
    }

});
