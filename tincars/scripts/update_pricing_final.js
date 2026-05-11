const admin = require('firebase-admin');
const serviceAccount = require('./tincars-b7d42-firebase-adminsdk-fbsvc-606a69e389.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function updatePricing() {
  const pricingRef = db.collection('admin_settings').doc('pricing');

  const newPricing = {
    vehicles: {
      essentials: {
        name: "Essentials",
        description: "Viajes cómodos y económicos para el día a día.",
        capacity: 4,
        base: 5.50,
        base_weekend: 5.50,
        wait_time_free_minutes: 1,
        wait_time_fee_per_minute: 1.0,
        distance_tiers: [
          { up_to_km: 5, price_per_km: 2.45 },
          { up_to_km: 15, price_per_km: 2.00 },
          { up_to_km: 999, price_per_km: 1.70 }
        ]
      },
      essentials_xl: {
        name: "Essentials XL",
        description: "Más espacio para ti y tus acompañantes.",
        capacity: 6,
        base: 6.60,
        base_weekend: 6.60,
        wait_time_free_minutes: 1,
        wait_time_fee_per_minute: 1.0,
        distance_tiers: [
          { up_to_km: 5, price_per_km: 2.70 },
          { up_to_km: 15, price_per_km: 2.25 },
          { up_to_km: 999, price_per_km: 2.00 }
        ]
      },
      executive: {
        name: "Executive",
        description: "Vehículos de alta gama con conductores top.",
        capacity: 4,
        base: 9.00,
        base_weekend: 9.00,
        wait_time_free_minutes: 1,
        wait_time_fee_per_minute: 1.0,
        distance_tiers: [
          { up_to_km: 5, price_per_km: 4.80 },
          { up_to_km: 15, price_per_km: 3.90 },
          { up_to_km: 999, price_per_km: 3.30 }
        ]
      },
      signature_lux: {
        name: "Signature LUX",
        description: "La máxima experiencia en lujo y confort.",
        capacity: 4,
        base: 16.00,
        base_weekend: 16.00,
        wait_time_free_minutes: 1,
        wait_time_fee_per_minute: 1.0,
        distance_tiers: [
          { up_to_km: 5, price_per_km: 6.50 },
          { up_to_km: 15, price_per_km: 4.60 },
          { up_to_km: 999, price_per_km: 4.00 }
        ]
      }
    },
    commission: {
      enabled: true,
      percentage: 25,
      message: "",
      last_updated: admin.firestore.FieldValue.serverTimestamp()
    }
  };

  try {
    await pricingRef.set(newPricing, { merge: true });
    console.log('✅ ¡Precios actualizados con éxito en Firebase!');
  } catch (error) {
    console.error('❌ Error al actualizar:', error);
  } finally {
    process.exit();
  }
}

updatePricing();
