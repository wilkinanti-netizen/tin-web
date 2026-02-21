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
            footer_quote: "\"Conectamos destinos con confianza, lujo y profesionalismo que te acompaña.\"", footer_rights: "Todos los derechos reservados."
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
            footer_quote: "\"Connecting destinations with trust, luxury, and professionalism that accompanies you.\"", footer_rights: "All rights reserved."
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
});
