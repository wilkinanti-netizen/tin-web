const targetUrl = 'https://us-central1-tincars-b7d42.cloudfunctions.net/sendBroadcastNotification';

async function runTest() {
    console.log(`Sending request to ${targetUrl}...`);
    try {
        const response = await fetch(targetUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                data: {
                    title: "🔔 Prueba desde el Script",
                    body: "Si recibes esto, los permisos ya están configurados correctamente.",
                    target: "all"
                }
            })
        });

        const result = await response.json();
        console.log("Response Status:", response.status);
        console.log("Response Body:", JSON.stringify(result, null, 2));
    } catch (e) {
        console.error("Error making request:", e);
    }
}

runTest();
