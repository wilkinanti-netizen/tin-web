document.addEventListener('DOMContentLoaded', () => {
    const distanceInput = document.getElementById('distance');
    const prices = {
        essentials: document.getElementById('price-essentials'),
        xl: document.getElementById('price-xl'),
        executive: document.getElementById('price-executive'),
        signature: document.getElementById('price-signature')
    };

    function calculateFares(miles) {
        if (isNaN(miles) || miles < 0) return { essentials: 0, xl: 0, executive: 0, signature: 0 };

        // Essentials: 2.50 base, 2.15 up to 5, then 1.85
        let essentials = 2.50;
        if (miles <= 5) {
            essentials += miles * 2.15;
        } else {
            essentials += (5 * 2.15) + ((miles - 5) * 1.85);
        }

        // XL: 3.00 base, 2.40 up to 5, then 2.15
        let xl = 3.00;
        if (miles <= 5) {
            xl += miles * 2.40;
        } else {
            xl += (5 * 2.40) + ((miles - 5) * 2.15);
        }

        // Executive: 5 base, 4.40 up to 5, then 3.50 up to 15, then 3.30
        let executive = 5.00;
        if (miles <= 5) {
            executive += miles * 4.40;
        } else if (miles <= 15) {
            executive += (5 * 4.40) + ((miles - 5) * 3.50);
        } else {
            executive += (5 * 4.40) + (10 * 3.50) + ((miles - 15) * 3.30);
        }

        // Signature: 12 base, 5 up to 5, then 4.30 up to 15, then 4.00
        let signature = 12.00;
        if (miles <= 5) {
            signature += miles * 5.00;
        } else if (miles <= 15) {
            signature += (5 * 5.00) + ((miles - 5) * 4.30);
        } else {
            signature += (5 * 5.00) + (10 * 4.30) + ((miles - 15) * 4.00);
        }

        return {
            essentials: essentials.toFixed(2),
            xl: xl.toFixed(2),
            executive: executive.toFixed(2),
            signature: signature.toFixed(2)
        };
    }

    function updatePrices() {
        const miles = parseFloat(distanceInput.value) || 0;
        const fares = calculateFares(miles);

        prices.essentials.textContent = `$${fares.essentials}`;
        prices.xl.textContent = `$${fares.xl}`;
        prices.executive.textContent = `$${fares.executive}`;
        prices.signature.textContent = `$${fares.signature}`;
    }

    distanceInput.addEventListener('input', updatePrices);

    // Initial calculation
    updatePrices();

    // Scroll Reveal Animation
    const observerOptions = {
        threshold: 0.1
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
            }
        });
    }, observerOptions);

    document.querySelectorAll('.reveal, .reveal-delay, .reveal-delay-2').forEach(el => {
        observer.observe(el);
    });

    // Simple reveal animation classes
    const style = document.createElement('style');
    style.textContent = `
        .reveal { transition: opacity 0.8s ease-out, transform 0.8s ease-out; }
        .reveal-delay { transition: opacity 0.8s ease-out 0.2s, transform 0.8s ease-out 0.2s; opacity: 0; transform: translateY(30px); }
        .reveal-delay-2 { transition: opacity 0.8s ease-out 0.4s, transform 0.8s ease-out 0.4s; opacity: 0; transform: translateY(30px); }
        .reveal.active, .reveal-delay.active, .reveal-delay-2.active { opacity: 1; transform: translateY(0); }
    `;
    document.head.appendChild(style);

    // --- Language Toggle Logic ---
    const translations = {
        es: {
            nav_home: "Inicio", nav_services: "Servicios", nav_calculator: "Calculadora", nav_download: "Descargar",
            hero_title_1: "Confianza que te transporta,", hero_title_2: "lujo que te acompaña.",
            hero_subtitle: "Conectamos destinos con profesionalismo, seguridad y una flota diseñada para superar tus expectativas.",
            hero_btn_fleet: "Ver Flota", hero_btn_estimate: "Estimar Tarifa",
            services_title: "Nuestra Flota", services_subtitle: "Elige el vehículo que mejor se adapte a tu necesidad.",
            badge_popular: "Popular", badge_premium: "Premium", badge_luxury: "Luxury",
            essentials_desc: "Vehículo cómodo y elegante, pensado para brindarte una experiencia agradable y segura.",
            feat_passengers_4: "Hasta 4 pasajeros", feat_ac: "Aire Acondicionado",
            xl_desc: "Más espacio para viajes en grupo. Confort y amplitud en cada trayecto.",
            feat_passengers_6: "Hasta 6 pasajeros", feat_space: "Espacio extra",
            executive_desc: "Conductores experimentados y vehículos de gama alta para un viaje confiable.",
            feat_people_4: "Hasta 4 personas", feat_drivers: "Conductores Top",
            signature_desc: "Lujo superior. Vehículos de alta gama para brindarte una experiencia inigualable.",
            feat_people_6: "Hasta 6 personas", feat_vip: "Servicio VIP",
            calc_title: "Calculadora de Tarifas", calc_subtitle: "Ingresa la distancia para estimar el costo de tu viaje.", calc_label: "Distancia (Millas)",
            footer_quote: "\"Conectamos destinos con confianza, lujo y profesionalismo que te acompaña.\"", footer_rights: "Todos los derechos reservados.",
            footer_privacy: "Política de Privacidad",
            privacy_title: "Aviso de Privacidad y Protección de Datos",
            privacy_intro: "En Tins cars premium, la seguridad y privacidad de nuestros usuarios son nuestra máxima prioridad. Este Aviso de Privacidad detalla de manera transparente cómo gestionamos, protegemos y procesamos la información personal recolectada a través de nuestra plataforma tecnológica, garantizando el cumplimiento de los estándares internacionales de protección de datos.",
            privacy_section1_title: "1. Recopilación de Información Sensible",
            privacy_section1_text: "Para garantizar la eficiencia y seguridad de nuestros servicios, recopilamos las siguientes categorías de datos:",
            privacy_section1_li1: "<strong>Identificación Personal:</strong> Nombre completo, dirección de correo electrónico validada y número de contacto telefónico.",
            privacy_section1_li2: "<strong>Datos Financieros:</strong> Información de transacciones procesada a través de pasarelas de pago seguras (PCI-DSS), sin almacenar números completos de tarjetas en nuestros servidores.",
            privacy_section1_li3: "<strong>Geolocalización Precisa:</strong> Datos de ubicación en tiempo real del dispositivo, necesarios para coordinar trayectos, estimar tiempos de llegada y garantizar la seguridad durante el viaje.",
            privacy_section1_li4: "<strong>Información Técnica:</strong> Dirección IP, identificadores únicos de dispositivo (UDID), tipo de navegador y registros de interacción con la aplicación.",
            privacy_section2_title: "2. Finalidad del Tratamiento de Datos",
            privacy_section2_text: "Los datos recopilados se utilizan estrictamente para los siguientes fines operativos:",
            privacy_section2_li1: "Gestión y optimización de la logística de transporte en tiempo real.",
            privacy_section2_li2: "Verificación de identidad para prevenir fraudes y garantizar un entorno seguro para conductores y pasajeros.",
            privacy_section2_li3: "Mejora continua del algoritmo de rutas y estimación de tarifas mediante análisis de datos agregados.",
            privacy_section2_li4: "Cumplimiento de normativas legales y requerimientos de autoridades competentes.",
            privacy_section3_title: "3. Seguridad y Resguardo de la Información",
            privacy_section3_text: "Implementamos protocolos de seguridad de grado bancario para proteger su información:",
            privacy_section3_li1: "<strong>Encriptación SSL/TLS:</strong> Toda transferencia de datos entre el usuario y nuestros servidores está cifrada.",
            privacy_section3_li2: "<strong>Acceso Restringido:</strong> Solo personal autorizado tiene acceso a los datos sensibles bajo estrictos acuerdos de confidencialidad.",
            privacy_section3_li3: "<strong>Monitoreo 24/7:</strong> Sistemas de detección de intrusiones y auditorías de seguridad periódicas.",
            privacy_section4_title: "4. Transferencia de Datos a Terceros",
            privacy_section4_text: "Tins cars premium no comercializa bases de datos. La información se comparte exclusivamente con:",
            privacy_section4_li1: "<strong>Socios Conductores:</strong> Únicamente los datos necesarios para localizar al pasajero y completar el servicio.",
            privacy_section4_li2: "<strong>Proveedores de Tecnología:</strong> Servicios de infraestructura en la nube (como Google Firebase) y procesadores de pago que cumplen con normativas de seguridad.",
            privacy_section5_title: "5. Derechos del Titular (Derechos ARCO)",
            privacy_section5_text: "Usted mantiene el control total sobre su información. Puede ejercer sus derechos de Acceso, Rectificación, Cancelación y Oposición en cualquier momento enviando una solicitud formal a nuestro departamento de privacidad.",
            privacy_section6_title: "6. Protección de Menores",
            privacy_section6_text: "Nuestra plataforma no está diseñada para menores de 13 años. Si detectamos la recopilación accidental de datos de un menor sin consentimiento parental, procederemos a la eliminación inmediata de dicha información de nuestros registros activos.",
            privacy_section7_title: "7. Contacto y Soporte Legal",
            privacy_section7_text: "Para cualquier consulta relacionada con sus datos, puede contactar a nuestro Oficial de Privacidad en: <strong>legal@tinscars.com</strong>",
            privacy_last_update: "Última revisión legal: 13 de Mayo de 2026"
        },
        en: {
            nav_home: "Home", nav_services: "Services", nav_calculator: "Calculator", nav_download: "Download",
            hero_title_1: "Trust that moves you,", hero_title_2: "luxury that accompanies you.",
            hero_subtitle: "Connecting destinations with professionalism, safety, and a fleet designed to exceed your expectations.",
            hero_btn_fleet: "View Fleet", hero_btn_estimate: "Estimate Fare",
            services_title: "Our Fleet", services_subtitle: "Choose the vehicle that best fits your needs.",
            badge_popular: "Popular", badge_premium: "Premium", badge_luxury: "Luxury",
            essentials_desc: "Comfortable and elegant vehicle, designed to provide a pleasant and safe experience.",
            feat_passengers_4: "Up to 4 passengers", feat_ac: "Air Conditioning",
            xl_desc: "More room for group trips. Comfort and spaciousness in every journey.",
            feat_passengers_6: "Up to 6 passengers", feat_space: "Extra space",
            executive_desc: "Experienced drivers and high-end vehicles for a reliable trip.",
            feat_people_4: "Up to 4 people", feat_drivers: "Top Drivers",
            signature_desc: "Top tier luxury. High-end vehicles to provide an unparalleled experience.",
            feat_people_6: "Up to 6 people", feat_vip: "VIP Service",
            calc_title: "Fare Calculator", calc_subtitle: "Enter the distance to estimate the cost of your trip.", calc_label: "Distance (Miles)",
            footer_quote: "\"Connecting destinations with trust, luxury, and professionalism that accompanies you.\"", footer_rights: "All rights reserved.",
            footer_privacy: "Privacy Policy",
            privacy_title: "Privacy Notice and Data Protection",
            privacy_intro: "At Tins cars premium, the security and privacy of our users are our highest priority. This Privacy Notice transparently details how we manage, protect, and process the personal information collected through our technological platform, ensuring compliance with international data protection standards.",
            privacy_section1_title: "1. Collection of Sensitive Information",
            privacy_section1_text: "To ensure the efficiency and security of our services, we collect the following categories of data:",
            privacy_section1_li1: "<strong>Personal Identification:</strong> Full name, validated email address, and telephone contact number.",
            privacy_section1_li2: "<strong>Financial Data:</strong> Transaction information processed through secure payment gateways (PCI-DSS), without storing full card numbers on our servers.",
            privacy_section1_li3: "<strong>Precise Geolocation:</strong> Real-time location data from the device, necessary to coordinate trips, estimate arrival times, and ensure safety during the journey.",
            privacy_section1_li4: "<strong>Technical Information:</strong> IP address, unique device identifiers (UDID), browser type, and application interaction logs.",
            privacy_section2_title: "2. Purpose of Data Processing",
            privacy_section2_text: "The collected data is used strictly for the following operational purposes:",
            privacy_section2_li1: "Management and optimization of real-time transportation logistics.",
            privacy_section2_li2: "Identity verification to prevent fraud and ensure a safe environment for both drivers and passengers.",
            privacy_section2_li3: "Continuous improvement of the routing algorithm and fare estimation through aggregate data analysis.",
            privacy_section2_li4: "Compliance with legal regulations and requirements from competent authorities.",
            privacy_section3_title: "3. Security and Information Safeguarding",
            privacy_section3_text: "We implement bank-grade security protocols to protect your information:",
            privacy_section3_li1: "<strong>SSL/TLS Encryption:</strong> All data transfer between the user and our servers is encrypted.",
            privacy_section3_li2: "<strong>Restricted Access:</strong> Only authorized personnel have access to sensitive data under strict confidentiality agreements.",
            privacy_section3_li3: "<strong>24/7 Monitoring:</strong> Intrusion detection systems and periodic security audits.",
            privacy_section4_title: "4. Data Transfer to Third Parties",
            privacy_section4_text: "Tins cars premium does not commercialize databases. Information is shared exclusively with:",
            privacy_section4_li1: "<strong>Driver Partners:</strong> Only the data necessary to locate the passenger and complete the service.",
            privacy_section4_li2: "<strong>Technology Providers:</strong> Cloud infrastructure services (such as Google Firebase) and payment processors that comply with security regulations.",
            privacy_section5_title: "5. User Rights (Data Subject Rights)",
            privacy_section5_text: "You maintain full control over your information. You may exercise your rights of Access, Rectification, Cancellation, and Opposition at any time by sending a formal request to our privacy department.",
            privacy_section6_title: "6. Protection of Minors",
            privacy_section6_text: "Our platform is not designed for children under 13. If we detect the accidental collection of data from a minor without parental consent, we will proceed to immediately delete such information from our active records.",
            privacy_section7_title: "7. Contact and Legal Support",
            privacy_section7_text: "For any queries related to your data, you can contact our Privacy Officer at: <strong>legal@tinscars.com</strong>",
            privacy_last_update: "Last legal review: May 13, 2026"
        }
    };

    let currentLang = 'es';
    const langBtn = document.getElementById('lang-toggle');

    langBtn.addEventListener('click', () => {
        currentLang = currentLang === 'es' ? 'en' : 'es';
        langBtn.textContent = currentLang === 'es' ? 'EN' : 'ES'; // Shows the language they can switch TO

        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            if (translations[currentLang][key]) {
                el.textContent = translations[currentLang][key];
            }
        });
    });

    // --- Mobile Menu Toggle ---
    const hamburger = document.querySelector('.hamburger');
    const navLinks = document.querySelector('.nav-links');
    const navItems = document.querySelectorAll('.nav-links li a');

    hamburger.addEventListener('click', () => {
        navLinks.classList.toggle('active');
    });

    // Close menu when clicking a link
    navItems.forEach(item => {
        item.addEventListener('click', () => {
            navLinks.classList.remove('active');
        });
    });
});
