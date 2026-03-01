require('dotenv').config();
const { Client } = require('pg');

const client = new Client({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 5000,
});

async function test() {
    console.log('Probando conexión a:', process.env.DATABASE_URL.replace(/:[^:@]+@/, ':****@'));
    try {
        await client.connect();
        console.log('✅ CONEXIÓN EXITOSA');
        await client.end();
    } catch (err) {
        console.error('❌ ERROR DE CONEXIÓN:', err.message);
        console.error('Código de error:', err.code);
    }
}

test();
