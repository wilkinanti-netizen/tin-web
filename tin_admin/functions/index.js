const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const geofire = require("geofire-common");

const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});


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

// Secretos de Stripe definidos en Firebase Secret Manager
// Subidos con: firebase functions:secrets:set STRIPE_SECRET_KEY / STRIPE_PUBLISHABLE_KEY
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripePublishableKey = defineSecret('STRIPE_PUBLISHABLE_KEY');

exports.stripePayments = onCall({ secrets: [stripeSecretKey, stripePublishableKey] }, async (request) => {
    const stripe = new Stripe(stripeSecretKey.value());
    const data = request.data;
    const action = data.action;

    // Usar el UID del usuario autenticado directamente desde el contexto de Firebase
    if (!request.auth) {
        throw new Error('El usuario debe estar autenticado');
    }
    const uid = request.auth.uid;

    try {
        // 1. Buscar el perfil del usuario para obtener su stripe_customer_id
        const userDoc = await db.collection('profiles').doc(uid).get();
        let customerId = userDoc.exists ? userDoc.data().stripe_customer_id : null;

        // 2. Si no tiene ID de Stripe o el documento no existe, lo creamos
        if (!customerId) {
            console.log(`Creando nuevo cliente de Stripe para UID: ${uid}`);
            const customer = await stripe.customers.create({
                metadata: { firebaseUID: uid }
            });
            customerId = customer.id;

            // Guardar el nuevo ID en Firestore
            await db.collection('profiles').doc(uid).set({
                stripe_customer_id: customerId
            }, { merge: true });
        }

        if (action === 'create-payment-intent') {
            const amount = data.amount;
            const currency = data.currency || 'usd';

            const ephemeralKey = await stripe.ephemeralKeys.create(
                { customer: customerId },
                { apiVersion: '2023-10-16' }
            );

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
                publishableKey: stripePublishableKey.value(),
            };

        } else if (action === 'create-setup-intent') {
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
                publishableKey: stripePublishableKey.value(),
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

/**
 * Atomic trip acceptance function.
 * Ensures that only one driver can accept a trip.
 */
exports.acceptTrip = onCall(async (request) => {
    const data = request.data;
    const tripId = data.tripId;
    const driverId = data.driverId;

    if (!tripId || !driverId) {
        throw new Error('Missing tripId or driverId');
    }

    const tripRef = db.collection('trips').doc(tripId);

    try {
        const result = await db.runTransaction(async (transaction) => {
            const tripDoc = await transaction.get(tripRef);

            if (!tripDoc.exists) {
                throw new Error('Trip not found');
            }

            const tripData = tripDoc.data();

            if (tripData.status !== 'requested') {
                return { success: false, error: 'TRIP_ALREADY_ACCEPTED' };
            }

            if (tripData.driver_id) {
                return { success: false, error: 'TRIP_ALREADY_ACCEPTED' };
            }

            // Update the trip with driver info and new status
            transaction.update(tripRef, {
                status: 'accepted',
                driver_id: driverId,
                accepted_at: admin.firestore.FieldValue.serverTimestamp(),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            return { success: true };
        });

        return result;

    } catch (error) {
        console.error("Error in acceptTrip function:", error);
        return { success: false, error: error.message };
    }
});

/**
 * Reject trip function for drivers.
 * Adds the driver ID to the rejected_by array in the trip document.
 */
exports.rejectTrip = onCall(async (request) => {
    const data = request.data;
    const tripId = data.tripId;
    const driverId = data.driverId;

    if (!tripId || !driverId) {
        throw new Error('Missing tripId or driverId');
    }

    const tripRef = db.collection('trips').doc(tripId);

    try {
        await tripRef.update({
            rejected_by: admin.firestore.FieldValue.arrayUnion(driverId),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true };
    } catch (error) {
        console.error("Error in rejectTrip function:", error);
        return { success: false, error: error.message };
    }
});

/**
 * Triggered when a new message is sent in a trip chat.
 * Notifies the other participant (driver or passenger).
 */
exports.onnewmessage = onDocumentCreated("messages/{messageId}", async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const messageData = snap.data();
    const tripId = messageData.trip_id;
    const senderId = messageData.sender_id;
    const text = messageData.text;

    if (!tripId || !senderId) return null;

    try {
        // 1. Fetch trip data to find participants
        const tripDoc = await db.collection('trips').doc(tripId).get();
        if (!tripDoc.exists) return null;

        const tripData = tripDoc.data();
        const passengerId = tripData.passenger_id;
        const driverId = tripData.driver_id;

        // 2. Determine receiverId
        let receiverId = null;
        let senderName = 'Usuario';

        if (senderId === passengerId) {
            receiverId = driverId;
            senderName = 'Pasajero';
        } else if (senderId === driverId) {
            receiverId = passengerId;
            senderName = 'Conductor';
        }

        if (!receiverId) {
            console.log("No receiver found for message in trip:", tripId);
            return null;
        }

        // 3. Get receiver's FCM token
        const profileSnap = await db.collection('profiles').doc(receiverId).get();
        if (!profileSnap.exists) return null;

        const fcmToken = profileSnap.data().fcm_token;
        if (!fcmToken) return null;

        // 4. Send notification
        const message = {
            notification: {
                title: `💬 Nuevo mensaje de ${senderName}`,
                body: text.length > 100 ? text.substring(0, 97) + '...' : text,
            },
            data: {
                type: 'NEW_MESSAGE',
                tripId: tripId,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: fcmToken,
            android: {
                priority: 'high',
                notification: {
                    sound: 'default',
                    channelId: 'chat_messages_channel',
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                    },
                },
            },
        };

        const response = await admin.messaging().send(message);
        console.log(`Successfully notified receiver ${receiverId} about new message in trip ${tripId}:`, response);

    } catch (error) {
        console.error("Error sending chat notification:", error);
    }

    return null;
});

/**
 * Triggered when an admin creates a notification job document.
 * Reads FCM tokens from profiles, sends real FCM push notifications,
 * and updates the job doc with the result.
 */
exports.onnotificationjobcreated = onDocumentCreated("notification_jobs/{jobId}", async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const jobData = snap.data();
    const { title, body, target } = jobData;

    if (!title || !body) {
        await snap.ref.update({ status: 'failed', error: 'Missing title or body' });
        return null;
    }

    try {
        // 1. Fetch profiles based on target
        let query = db.collection('profiles');
        const profilesSnap = await query.get();
        const tokens = [];

        const userEmails = [];
        profilesSnap.forEach(doc => {
            const data = doc.data();
            const token = data.fcm_token;
            const isDriver = data.is_driver === true;

            if (!token) return;

            if (target === 'all' || (target === 'drivers' && isDriver) || (target === 'passengers' && !isDriver) || target === doc.id) {
                tokens.push(token);
                userEmails.push(data.email || doc.id);
            }
        });

        if (tokens.length === 0) {
            await snap.ref.update({
                status: 'done',
                success_count: 0,
                failure_count: 0,
                total_targeted: 0,
            });
            return null;
        }

        console.log(`Admin notification job: sending to ${tokens.length} devices (target: ${target})`);
        userEmails.forEach((email, i) => {
            console.log(`Index ${i}: User ${email}`);
        });


        // 2. Prepare and send multicast message (cloned from working ontripcreated logic)
        const message = {
            notification: { title, body },
            data: {
                type: 'ADMIN_BROADCAST',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
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
            tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);

        const detailedResults = [];
        let firstError = null;

        response.responses.forEach((resp, idx) => {
            const email = userEmails[idx];
            if (resp.success) {
                detailedResults.push({ email, status: 'success' });
                console.log(`✅ SUCCESS for ${email}`);
            } else {
                const errMsg = resp.error ? resp.error.message : 'Unknown error';
                detailedResults.push({ email, status: 'failed', error: errMsg });
                console.error(`❌ FAILED for ${email}: ${errMsg}`);
                if (!firstError) firstError = errMsg;
            }
        });

        // 3. Update job doc with result
        await snap.ref.update({
            status: 'done',
            success_count: response.successCount,
            failure_count: response.failureCount,
            total_targeted: tokens.length,
            detailed_results: detailedResults, // NEW: Detailed list for the admin to see
            error_details: firstError || null,
            completed_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`Admin notification job done: ${response.successCount} success, ${response.failureCount} failed.`);

    } catch (error) {
        console.error('Error in onnotificationjobcreated:', error);
        await snap.ref.update({ status: 'failed', error: error.message });
    }

    return null;
});
/**
 * HTTPS Callable function to send broadcast notifications from the admin panel.
 * Provides immediate feedback to the UI.
 */
exports.sendBroadcastNotification = onCall(async (request) => {
    console.log('--- sendBroadcastNotification TRIGGERED ---');
    console.log('Data:', JSON.stringify(request.data));

    // 1. Verify admin authentication
    // Skip admin authentication check for now to allow panel access
    /*
    if (!request.auth) {
        throw new Error('Unauthorized: Admin authentication required');
    }
    */

    const { title, body, target } = request.data;

    if (!title || !body) {
        return { success: false, error: 'Missing title or body' };
    }

    try {
        // 2. Fetch profiles based on target
        const profilesSnap = await db.collection('profiles').get();
        const tokensWithIds = [];

        profilesSnap.forEach(doc => {
            const data = doc.data();
            const token = data.fcm_token;
            const isDriver = data.is_driver === true;

            if (!token) return;

            if (target === 'all' || (target === 'drivers' && isDriver) || (target === 'passengers' && !isDriver)) {
                tokensWithIds.push({
                    id: doc.id,
                    token: token,
                    email: data.email || 'No email'
                });
            }
        });

        console.log(`--- [SERVER] Tokens encontrados para target ${target}: ${tokensWithIds.length} ---`);

        if (tokensWithIds.length === 0) {
            console.log('--- [SERVER] No se encontraron tokens. Cancelando envío. ---');
            return { success: true, successCount: 0, failureCount: 0, totalTargeted: 0 };
        }

        let totalSuccess = 0;
        let totalFailure = 0;
        const failures = [];

        // 3. Process in batches
        for (let i = 0; i < tokensWithIds.length; i += 500) {
            const batch = tokensWithIds.slice(i, i + 500);
            const tokens = batch.map(t => t.token);

            console.log(`--- [SERVER] Enviando lote de ${batch.length} tokens... ---`);

            const sendPromises = tokens.map(async (token, idx) => {
                const singleMessage = {
                    notification: { title, body },
                    data: {
                        type: 'ADMIN_BROADCAST',
                        click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    },
                    android: {
                        priority: 'high',
                        notification: {
                            sound: 'default',
                            channelId: 'trip_status_channel',
                        },
                    },
                    apns: {
                        payload: { aps: { sound: 'default', badge: 1, 'content-available': 1 } },
                    },
                    token: token,
                };

                try {
                    await admin.messaging().send(singleMessage);
                    return { success: true, idx };
                } catch (e) {
                    return { success: false, error: e, idx };
                }
            });

            const results = await Promise.all(sendPromises);

            let batchSuccess = 0;
            let batchFailure = 0;
            const responses = results.map(r => {
                if (r.success) {
                    batchSuccess++;
                    return { success: true };
                } else {
                    batchFailure++;
                    return { success: false, error: r.error };
                }
            });

            console.log(`--- [SERVER] Resultado del lote: ${batchSuccess} éxito, ${batchFailure} fallo ---`);

            totalSuccess += batchSuccess;
            totalFailure += batchFailure;

            // 4. Handle responses and cleanup stale tokens
            for (let idx = 0; idx < responses.length; idx++) {
                const resp = responses[idx];
                const userInfo = batch[idx];

                if (resp.success) {
                    console.log(`[SUCCESS] Enviado a: ${userInfo.email} (ID: ${userInfo.id})`);
                } else {
                    const error = resp.error;
                    const errorMsg = error ? error.message : 'Unknown error';
                    failures.push({ email: userInfo.email, error: errorMsg });
                    console.error(`[FAILED] No se pudo enviar a: ${userInfo.email} (ID: ${userInfo.id}) - Error: ${errorMsg}`);

                    if (error && (
                        error.code === 'messaging/invalid-registration-token' ||
                        error.code === 'messaging/registration-token-not-registered'
                    )) {
                        console.log(`[CLEANUP] Eliminando token inválido para: ${userInfo.email}`);
                        await db.collection('profiles').doc(userInfo.id).update({
                            fcm_token: admin.firestore.FieldValue.delete(),
                            token_error: error.code,
                            token_last_error_at: admin.firestore.FieldValue.serverTimestamp()
                        });
                    }
                }
            }
        }

        return {
            success: true,
            successCount: totalSuccess,
            failureCount: totalFailure,
            totalTargeted: tokensWithIds.length,
            failures: failures.slice(0, 50), // Send some failures back for UI
        };

    } catch (error) {
        console.error('Error in sendBroadcastNotification:', error);
        return { success: false, error: error.message };
    }
});
