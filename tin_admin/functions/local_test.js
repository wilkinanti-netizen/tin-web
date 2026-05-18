const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: "tincars-b7d42"
});

async function runLocalTest() {
    console.log("======================================================");
    console.log("INICIANDO PRUEBA LOCAL DE FCM CON MULTIPLES TOKENS");
    console.log("Proyecto: tincars-b7d42");
    console.log("======================================================");

    try {
        const db = admin.firestore();
        console.log(">> Obteniendo perfiles de la base de datos (limite 15)...");
        const profilesSnap = await db.collection('profiles').limit(15).get();
        console.log(`>> Se encontraron ${profilesSnap.size} perfiles en la consulta.`);

        let tested = 0;
        let successCount = 0;
        let errorCount = 0;

        for (const doc of profilesSnap.docs) {
            const data = doc.data();
            const token = data.fcm_token;
            console.log("------------------------------------------------------");
            console.log(`👤 Analizando usuario: ${data.email || 'Sin email'} (ID: ${doc.id})`);

            if (!token) {
                console.log(`⚠️  SALTANDO: El usuario NO tiene fcm_token guardado.`);
                continue;
            }

            tested++;
            console.log(`📲 TOKEN ENCONTRADO: ${token.substring(0, 30)}...`);
            console.log(`>> Intentando enviar mensaje de prueba a este token...`);

            try {
                const message = {
                    notification: { title: "Test de Conexión", body: "Si ves esto, tu token es correcto." },
                    token: token
                };
                const response = await admin.messaging().send(message);
                console.log(`✅ ¡ÉXITO TOTAL! Mensaje enviado correctamente al usuario: ${data.email} (${doc.id})`);
                successCount++;
            } catch (err) {
                errorCount++;
            }
        }

        console.log("======================================================");
        console.log("RESUMEN DE LA PRUEBA:");
        console.log(`Total de tokens probados: ${tested}`);
        console.log(`Tokens correctos (Éxito): ${successCount}`);
        console.log(`Tokens incorrectos (Fallos): ${errorCount}`);
        console.log("======================================================");
    } catch (e) {
        console.error("FATAL ERROR EN EL SCRIPT:", e);
    }
}

runLocalTest();
