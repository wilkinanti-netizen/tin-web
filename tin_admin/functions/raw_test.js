const { GoogleAuth } = require('google-auth-library');
const admin = require('firebase-admin');

async function runRawTest() {
    console.log("======================================================");
    console.log("INICIANDO PRUEBA REST API FCM V1 (SIN FIREBASE ADMIN)");
    console.log("======================================================");

    try {
        // 1. Get a token from the DB using Admin SDK (already initialized globally if needed, or we just init it)
        const serviceAccount = require('./serviceAccountKey.json');
        if (!admin.apps.length) {
            admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
        }

        const db = admin.firestore();
        const profilesSnap = await db.collection('profiles').limit(5).get();
        const auth = new GoogleAuth({
            keyFilename: './serviceAccountKey.json',
            scopes: ['https://www.googleapis.com/auth/firebase.messaging']
        });
        const client = await auth.getClient();
        const accessTokenResponse = await client.getAccessToken();
        const accessToken = accessTokenResponse.token;
        console.log(`✅ Token OAuth obtenido exitosamente (Empieza con: ${accessToken.substring(0, 10)}...)`);

        for (const doc of profilesSnap.docs) {
            if (!doc.data().fcm_token) continue;
            const targetToken = doc.data().fcm_token;
            console.log(`\n======================================`);
            console.log(`Probando token de: ${doc.data().email || doc.id}`);

            const projectId = "tincars-b7d42";
            const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

            const payload = {
                message: {
                    token: targetToken,
                    notification: {
                        title: "Prueba Directa",
                        body: "Mensaje desde HTTP puro"
                    }
                }
            };

            const response = await fetch(url, {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${accessToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(payload)
            });

            const data = await response.json();
            console.log("Status Code:", response.status);
            console.log(JSON.stringify(data, null, 2));
        }

    } catch (error) {
        console.error("FATAL ERROR:", error);
    }
}

runRawTest();
