
const admin = require('firebase-admin');

// 1. Descarga tu archivo de credenciales (serviceAccountKey.json) desde la consola de Firebase
// 2. Colócalo en la misma carpeta que este script
const serviceAccount = require('./tincars-b7d42-firebase-adminsdk-fbsvc-606a69e389.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const pricingConfig = {
  vehicles: {
    essentials: {
      name: "Essentials",
      description: "Viajes cómodos y económicos para el día a día.",
      capacity: 4,
      base: 2.50,
      base_weekend: 3.00,
      distance_tiers: [
        { up_to_km: 5.0, price_per_km: 1.20 },
        { up_to_km: 15.0, price_per_km: 1.10 },
        { up_to_km: 999.0, price_per_km: 1.00 }
      ],
      wait_time_free_minutes: 5,
      wait_time_fee_per_minute: 0.50
    },
    essentials_xl: {
      name: "Essentials XL",
      description: "Más espacio para ti y tus acompañantes.",
      capacity: 6,
      base: 4.50,
      base_weekend: 5.00,
      distance_tiers: [
        { up_to_km: 5.0, price_per_km: 1.80 },
        { up_to_km: 15.0, price_per_km: 1.60 },
        { up_to_km: 999.0, price_per_km: 1.40 }
      ],
      wait_time_free_minutes: 5,
      wait_time_fee_per_minute: 0.70
    },
    executive: {
      name: "Executive",
      description: "Vehículos de alta gama con conductores top.",
      capacity: 4,
      base: 6.00,
      base_weekend: 7.00,
      distance_tiers: [
        { up_to_km: 5.0, price_per_km: 2.50 },
        { up_to_km: 15.0, price_per_km: 2.20 },
        { up_to_km: 999.0, price_per_km: 2.00 }
      ],
      wait_time_free_minutes: 10,
      wait_time_fee_per_minute: 1.00
    },
    signature_lux: {
      name: "Signature LUX",
      description: "La máxima experiencia en lujo y confort.",
      capacity: 4,
      base: 10.00,
      base_weekend: 12.00,
      distance_tiers: [
        { up_to_km: 999.0, price_per_km: 3.50 }
      ],
      wait_time_free_minutes: 15,
      wait_time_fee_per_minute: 2.00
    }
  },
  commission: {
    enabled: false,
    percentage: 15.0,
    message: "¡Hoy no se cobra comisión! Disfruta tus ganancias."
  },
  last_updated: admin.firestore.FieldValue.serverTimestamp()
};

async function inject() {
  try {
    console.log('Inyectando configuración de precios...');
    await db.collection('admin_settings').doc('pricing').set(pricingConfig);
    console.log('¡Configuración inyectada con éxito!');
    process.exit(0);
  } catch (error) {
    console.error('Error inyectando precios:', error);
    process.exit(1);
  }
}

inject();
