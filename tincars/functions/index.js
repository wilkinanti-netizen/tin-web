const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const geofire = require("geofire-common");

admin.initializeApp();

const db = admin.firestore();

/**
 * Triggered when a new trip is created in the 'trips' collection.
 * Notifies active drivers within a 2km radius about the new trip request.
 */
exports.ontripcreated = onDocumentCreated("trips/{tripId}", async (event) => {
    const tripId = event.params.tripId;
    const snap = event.data;
    
    if (!snap) {
        console.log("No data found for trip:", tripId);
        return null;
    }

    const tripData = snap.data();
    
    // Only notify for requested trips
    if (tripData.status !== 'requested') {
        return null;
    }

    const pickupLat = tripData.pickup_lat;
    const pickupLng = tripData.pickup_lng;

    if (!pickupLat || !pickupLng) {
        console.log(`Trip ${tripId} is missing pickup coordinates.`);
        return null;
    }

    console.log(`Processing trip ${tripId} at [${pickupLat}, ${pickupLng}]`);

    try {
        // 1. Fetch all online drivers from driver_data
        const driversDataSnapshot = await db.collection('driver_data')
            .where('is_online', '==', true)
            .get();

        if (driversDataSnapshot.empty) {
            console.log("No online drivers found.");
            return null;
        }

        const eligibleDriverIds = [];
        const radiusInMeters = 2000; // 2km radius

        driversDataSnapshot.forEach(doc => {
            const data = doc.data();
            const dLat = data.last_lat;
            const dLng = data.last_lng;

            if (dLat && dLng) {
                const distanceInKm = geofire.distanceBetween([pickupLat, pickupLng], [dLat, dLng]);
                const distanceInMeters = distanceInKm * 1000;

                if (distanceInMeters <= radiusInMeters) {
                    eligibleDriverIds.push(doc.id);
                }
            }
        });

        if (eligibleDriverIds.length === 0) {
            console.log("No drivers found within 2km radius.");
            return null;
        }

        console.log(`Found ${eligibleDriverIds.length} eligible drivers within 2km.`);

        // 2. Fetch FCM tokens from profiles for eligible drivers
        const tokens = [];
        const profilePromises = eligibleDriverIds.map(id => db.collection('profiles').doc(id).get());
        const profilesSnapshots = await Promise.all(profilePromises);

        profilesSnapshots.forEach(doc => {
            if (doc.exists) {
                const data = doc.data();
                if (data.driver_status === 'active' && data.fcm_token) {
                    tokens.push(data.fcm_token);
                }
            }
        });

        if (tokens.length === 0) {
            console.log("None of the eligible drivers have a valid FCM token.");
            return null;
        }

        // 3. Prepare message
        const message = {
            notification: {
                title: '🚗 ¡Nuevo viaje disponible!',
                body: `Precio: $${tripData.price || 'N/A'} - Recogida: ${tripData.pickup_address || 'No especificada'}`,
            },
            data: {
                type: 'NEW_TRIP',
                tripId: tripId,
                pickup_address: String(tripData.pickup_address || ''),
                price: String(tripData.price || ''),
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'incoming_trip_channel',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        'content-available': 1,
                    },
                },
            },
            tokens: tokens,
        };

        // 4. Send multicast message
        const response = await admin.messaging().sendEachForMulticast(message);
        
        console.log(`Successfully notified ${response.successCount} drivers within 2km.`);

    } catch (error) {
        console.error("Error sending trip notification:", error);
    }

    return null;
});

const Stripe = require('stripe');
// Importante: Debes configurar la variable de entorno 'STRIPE_SECRET_KEY' en Firebase
// firebase functions:secrets:set STRIPE_SECRET_KEY
// o usar process.env.STRIPE_SECRET_KEY
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_tu_clave_secreta_aqui');

exports.stripePayments = onCall(async (request) => {
    const data = request.data;
    const action = data.action;
    let customerId = data.customerId;

    try {
        if (!customerId) {
            // Si el cliente no tiene un ID en Stripe, lo creamos
            const customer = await stripe.customers.create();
            customerId = customer.id;
        }

        if (action === 'create-payment-intent') {
            const amount = data.amount;
            const currency = data.currency || 'usd';

            // Crear el Ephemeral Key para la versión de API requerida por Flutter Stripe
            const ephemeralKey = await stripe.ephemeralKeys.create(
                { customer: customerId },
                { apiVersion: '2023-10-16' }
            );

            // Crear el PaymentIntent (monto en centavos)
            const paymentIntent = await stripe.paymentIntents.create({
                amount: Math.round(amount * 100), 
                currency: currency,
                customer: customerId,
                automatic_payment_methods: {
                    enabled: true,
                },
            });

            return {
                paymentIntent: paymentIntent.client_secret,
                ephemeralKey: ephemeralKey.secret,
                customer: customerId,
            };
            
        } else if (action === 'create-setup-intent') {
            // Guardar tarjeta sin cobro ($0)
            const ephemeralKey = await stripe.ephemeralKeys.create(
                { customer: customerId },
                { apiVersion: '2023-10-16' }
            );
            
            const setupIntent = await stripe.setupIntents.create({
                customer: customerId,
                payment_method_types: ['card'],
            });

            return {
                setupIntent: setupIntent.client_secret,
                ephemeralKey: ephemeralKey.secret,
                customer: customerId,
            };
            
        } else {
            throw new Error(`Acción desconocida: ${action}`);
        }
    } catch (error) {
        console.error("Error en stripePayments:", error);
        return { error: error.message };
    }
});

/**
 * Triggered when a trip document is updated.
 * Notifies the passenger when the trip status changes to accepted, arrived, or in_progress.
 */
exports.ontripstatuschanged = onDocumentUpdated("trips/{tripId}", async (event) => {
    const after = event.data.after.data();
    const before = event.data.before.data();
    
    // Solo continuar si el estado ha cambiado
    if (after.status === before.status) {
        return null;
    }

    const passengerId = after.passenger_id;
    if (!passengerId) return null;

    let title = '';
    let body = '';

    if (after.status === 'accepted') {
        title = '¡Conductor asignado!';
        body = 'Tu conductor está en camino para recogerte.';
    } else if (after.status === 'arrived') {
        title = '¡Tu conductor ha llegado!';
        body = 'El conductor te está esperando en el punto de recogida.';
    } else if (after.status === 'in_progress') {
        title = '¡Viaje iniciado!';
        body = 'Dirigiéndonos a tu destino. ¡Buen viaje!';
    } else {
        // Ignorar otros estados por ahora
        return null;
    }

    try {
        const passengerProfile = await db.collection('profiles').doc(passengerId).get();
        if (!passengerProfile.exists) return null;
        
        const fcmToken = passengerProfile.data().fcm_token;
        if (!fcmToken) {
            console.log(`Passenger ${passengerId} has no FCM token.`);
            return null;
        }

        const message = {
            notification: {
                title: title,
                body: body,
            },
            data: {
                type: 'TRIP_STATUS_CHANGED',
                tripId: event.params.tripId,
                status: after.status,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: fcmToken,
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'trip_status_channel',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        'content-available': 1,
                    },
                },
            },
        };

        const response = await admin.messaging().send(message);
        console.log(`Successfully notified passenger ${passengerId} about status ${after.status}: `, response);
    } catch (error) {
        console.error("Error sending trip status notification:", error);
    }

    return null;
});
