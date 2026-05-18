const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

async function checkTokens() {
    console.log("Checking profiles for FCM tokens and errors...");
    const profilesSnap = await db.collection('profiles').get();

    let total = 0;
    let withToken = 0;
    let withError = 0;
    let drivers = 0;
    let passengers = 0;

    profilesSnap.forEach(doc => {
        total++;
        const data = doc.data();
        const hasToken = !!data.fcm_token;
        const hasError = !!data.token_error;
        const isDriver = data.is_driver === true;

        if (hasToken) withToken++;
        if (hasError) withError++;
        if (isDriver) drivers++;
        else passengers++;

        console.log(`User: ${data.email || doc.id} | is_driver: ${isDriver} | hasToken: ${hasToken} | tokenError: ${data.token_error || 'none'}`);
    });

    console.log(`\nSummary:`);
    console.log(`Total users: ${total}`);
    console.log(`Drivers: ${drivers}, Passengers: ${passengers}`);
    console.log(`Users with fcm_token: ${withToken}`);
    console.log(`Users with token_error: ${withError}`);
}

checkTokens().catch(console.error);
