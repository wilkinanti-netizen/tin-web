// index.js (Versión Completa con Redis + PostgreSQL)
require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const { createClient } = require('redis');
const { Client } = require('pg'); // ⚠️ IMPORTANTE: Importar el cliente de PostgreSQL
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// --- CONFIGURACIÓN DE REDIS ---
const redisClient = createClient({
  url: process.env.REDIS_URL,
  socket: {
    tls: true,
    rejectUnauthorized: false,
    reconnectStrategy: (retries) => {
      if (retries > 10) {
        return new Error('No se pudo reconectar a Redis después de 10 intentos.');
      }
      return Math.min(retries * 100, 3000);
    }
  }
});

redisClient.on('error', (err) => console.log('❌ Redis Client Error', err));
redisClient.on('end', () => {
  console.log('⚠️ Redis client disconnected. Attempting to reconnect...');
  if (!redisClient.isOpen) {
    redisClient.connect().catch(err => console.error('Failed to reconnect to Redis:', err));
  }
});
redisClient.on('connect', () => console.log('🔄 Connecting to Redis...'));
redisClient.on('ready', () => console.log('✅ Redis client is ready.'));
redisClient.on('reconnecting', () => console.log('🔄 Reconnecting to Redis...'));

// --- CONFIGURACIÓN DE POSTGRESQL ---
const pgClient = new Client({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

// Función para inicializar la base de datos (PostgreSQL en Supabase)
async function initializeDatabase() {
  try {
    await pgClient.connect();
    console.log('✅ PostgreSQL (Supabase) conectado.');

    const query = `
      -- 1. Tabla de Datos GPS (Historial)
      CREATE TABLE IF NOT EXISTS gps_data (
        id SERIAL PRIMARY KEY,
        trip_id VARCHAR(255) NOT NULL,
        latitude DECIMAL(10, 7) NOT NULL,
        longitude DECIMAL(10, 7) NOT NULL,
        timestamp BIGINT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_trip_id ON gps_data(trip_id);
      CREATE INDEX IF NOT EXISTS idx_timestamp ON gps_data(trip_id, timestamp);

      -- 2. Tabla de Perfiles Generales
      CREATE TABLE IF NOT EXISTS profiles (
        id UUID PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        full_name TEXT,
        avatar_url TEXT,
        is_driver BOOLEAN DEFAULT FALSE,
        driver_status TEXT DEFAULT 'inactive',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      -- 3. Tabla de Datos del Conductor (TINS CARS)
      CREATE TABLE IF NOT EXISTS driver_data (
        profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE PRIMARY KEY,
        vehicle_model TEXT NOT NULL,
        vehicle_plate TEXT NOT NULL,
        vehicle_type TEXT NOT NULL,
        is_verified BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      -- 4. Tabla de Viajes (TRIPS) - CRITICAL para la funcionalidad de pedidos
      CREATE TABLE IF NOT EXISTS trips (
        id UUID PRIMARY KEY,
        passenger_id UUID NOT NULL,
        driver_id UUID,
        pickup_lat DECIMAL(10, 7) NOT NULL,
        pickup_lng DECIMAL(10, 7) NOT NULL,
        dropoff_lat DECIMAL(10, 7) NOT NULL,
        dropoff_lng DECIMAL(10, 7) NOT NULL,
        pickup_address TEXT NOT NULL,
        dropoff_address TEXT NOT NULL,
        distance DECIMAL(10, 2) NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        status TEXT NOT NULL DEFAULT 'requested',
        driver_lat DECIMAL(10, 7),
        driver_lng DECIMAL(10, 7),
        vehicle_type TEXT NOT NULL,
        payment_method TEXT DEFAULT 'Efectivo',
        comment TEXT,
        has_extra_luggage BOOLEAN DEFAULT FALSE,
        has_pets BOOLEAN DEFAULT FALSE,
        payment_intent_id TEXT,
        payment_status TEXT,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
      );

      -- Script para asegurar columnas de pago existentes
      DO $$ 
      BEGIN 
          IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='trips' AND COLUMN_NAME='payment_intent_id') THEN
              ALTER TABLE trips ADD COLUMN payment_intent_id TEXT;
          END IF;
          IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='trips' AND COLUMN_NAME='payment_status') THEN
              ALTER TABLE trips ADD COLUMN payment_status TEXT;
          END IF;
          IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='trips' AND COLUMN_NAME='payment_method') THEN
              ALTER TABLE trips ADD COLUMN payment_method TEXT DEFAULT 'Efectivo';
          END IF;
          IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='trips' AND COLUMN_NAME='comment') THEN
              ALTER TABLE trips ADD COLUMN comment TEXT;
          END IF;
      END $$;
    `;
    await pgClient.query(query);
    console.log('✅ Base de datos inicializada: gps_data, profiles y driver_data listas.');
  } catch (err) {
    console.error('❌ Error al conectar o inicializar base de datos:', err);
    process.exit(1);
  }
}

// --- CONFIGURACIÓN DE EXPRESS Y SOCKET.IO ---
const app = express();
app.use(cors());
app.use(express.json());

// Ruta para verificar el estado del servidor
app.get('/', (_, res) => {
  res.json({
    status: 'online',
    message: 'Servidor Socket.IO v2 con Redis y PostgreSQL funcionando',
    timestamp: new Date().toISOString()
  });
});

// 🆕 NUEVA RUTA: Obtener lista de viajes activos
app.get('/api/trips/active', async (req, res) => {
  try {
    // Obtener todos los viajes que tienen datos en los últimos 30 minutos
    const thirtyMinutesAgo = Date.now() - (30 * 60 * 1000);
    const query = `
      SELECT DISTINCT trip_id, 
             COUNT(*) as points_count,
             MAX(timestamp) as last_update,
             MIN(timestamp) as first_update
      FROM gps_data 
      WHERE timestamp > $1
      GROUP BY trip_id
      ORDER BY last_update DESC
    `;
    const result = await pgClient.query(query, [thirtyMinutesAgo]);

    const activeTrips = result.rows.map(row => ({
      tripId: row.trip_id,
      pointsCount: parseInt(row.points_count),
      lastUpdate: new Date(parseInt(row.last_update)),
      firstUpdate: new Date(parseInt(row.first_update)),
      duration: parseInt(row.last_update) - parseInt(row.first_update)
    }));

    res.json({
      success: true,
      count: activeTrips.length,
      trips: activeTrips
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// --- ENDPOINTS DE STRIPE ---
app.post('/api/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency, customerId } = req.body;

    // 1. Crear o recuperar el cliente en Stripe (opcional, para guardar tarjetas)
    // Por ahora asumimos que el customerId viene del frontend o se crea uno nuevo

    // 2. Crear una clave efímera para el cliente (necesario para el Payment Sheet de Flutter)
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId || 'cus_placeholder' }, // TODO: Usar ID real del cliente
      { apiVersion: '2022-11-15' }
    );

    // 3. Crear el Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      customer: customerId || 'cus_placeholder',
      automatic_payment_methods: {
        enabled: true,
      },
    });

    res.json({
      paymentIntent: paymentIntent.client_secret,
      ephemeralKey: ephemeralKey.secret,
      customer: customerId || 'cus_placeholder',
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY
    });
  } catch (err) {
    console.error('❌ Error en Stripe:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 🆕 NUEVA RUTA: Obtener todos los viajes históricos
app.get('/api/trips/all', async (req, res) => {
  try {
    const query = `
      SELECT DISTINCT trip_id, 
             COUNT(*) as points_count,
             MAX(timestamp) as last_update,
             MIN(timestamp) as first_update
      FROM gps_data 
      GROUP BY trip_id
      ORDER BY last_update DESC
      LIMIT 100
    `;
    const result = await pgClient.query(query);

    const allTrips = result.rows.map(row => ({
      tripId: row.trip_id,
      pointsCount: parseInt(row.points_count),
      lastUpdate: new Date(parseInt(row.last_update)),
      firstUpdate: new Date(parseInt(row.first_update))
    }));

    res.json({
      success: true,
      count: allTrips.length,
      trips: allTrips
    });
  } catch (err) {
    console.error('❌ Error al obtener todos los viajes:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// 🆕 NUEVA RUTA: Obtener detalles de un viaje específico
app.get('/api/trips/:tripId', async (req, res) => {
  try {
    const { tripId } = req.params;
    const query = `
      SELECT latitude, longitude, timestamp 
      FROM gps_data 
      WHERE trip_id = $1 
      ORDER BY timestamp ASC
    `;
    const result = await pgClient.query(query, [tripId]);

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Viaje no encontrado'
      });
    }

    const route = result.rows.map(row => ({
      lat: parseFloat(row.latitude),
      lng: parseFloat(row.longitude),
      timestamp: parseInt(row.timestamp)
    }));

    res.json({
      success: true,
      tripId,
      pointsCount: route.length,
      route
    });
  } catch (err) {
    console.error('❌ Error al obtener detalles del viaje:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' }
});

// --- LÓGICA DE SOCKET.IO ---
io.on('connection', socket => {
  console.log('🔌 Cliente conectado:', socket.id);

  socket.on('joinTrip', async (tripId) => {
    socket.join(tripId);
    console.log(`→ ${socket.id} se unió a viaje ${tripId}`);

    try {
      // 1. Buscar historial en PostgreSQL
      const query = `
        SELECT latitude, longitude, timestamp 
        FROM gps_data 
        WHERE trip_id = $1 
        ORDER BY timestamp ASC
      `;
      const result = await pgClient.query(query, [tripId]);

      const historicalRoute = result.rows.map(row => ({
        lat: parseFloat(row.latitude),
        lng: parseFloat(row.longitude),
        ts: parseInt(row.timestamp)
      }));

      if (historicalRoute.length > 0) {
        socket.emit('tripHistory', historicalRoute);
        console.log(`✅ Historial de ${tripId} (${historicalRoute.length} puntos) enviado.`);
      } else {
        console.log(`⚠️ No hay historial para ${tripId}`);
      }

      // 2. Buscar última ubicación en Redis
      const locationJson = await redisClient.get(tripId);
      if (locationJson) {
        socket.emit('locationUpdate', JSON.parse(locationJson));
      }
    } catch (err) {
      console.error('❌ Error en joinTrip:', err);
      socket.emit('error', { message: 'Error al cargar datos del viaje' });
    }
  });

  socket.on('driverLocation', async ({ tripId, lat, lng }) => {
    const update = { lat, lng, ts: Date.now() };

    try {
      // 1. Guardar en Redis (tiempo real)
      await redisClient.set(tripId, JSON.stringify(update), { EX: 3600 });

      // 2. Guardar en PostgreSQL (historial persistente)
      const query = `
        INSERT INTO gps_data(trip_id, latitude, longitude, timestamp) 
        VALUES($1, $2, $3, $4)
      `;
      await pgClient.query(query, [tripId, lat, lng, update.ts]);

      console.log(`📍 Nueva ubicación de ${tripId}: lat=${lat}, lng=${lng}`);

      // 3. Emitir a todos los clientes suscritos
      io.to(tripId).emit('locationUpdate', update);
    } catch (err) {
      console.error('❌ Error al procesar ubicación:', err);
    }
  });

  socket.on('finishTrip', async (tripId) => {
    try {
      await redisClient.del(tripId);
      console.log(`🧹 Viaje ${tripId} finalizado y limpiado de Redis.`);
      io.to(tripId).emit('tripFinished', { tripId });
    } catch (err) {
      console.error('❌ Error al finalizar viaje:', err);
    }
  });

  socket.on('disconnect', () => {
    console.log('🔌 Cliente desconectado:', socket.id);
  });
});

// --- INICIO DEL SERVIDOR ---
async function startServer() {
  try {
    // 1. Conectar PostgreSQL e inicializar tablas (Prioridad)
    await initializeDatabase();

    // 2. Conectar Redis (Opcional, no bloquea el inicio)
    try {
      await redisClient.connect();
      console.log('✅ Redis conectado exitosamente.');
    } catch (redisErr) {
      console.error('⚠️ Advertencia: No se pudo conectar a Redis. El tiempo real podría no funcionar, pero la base de datos está lista.', redisErr.message);
    }

    // 3. Iniciar servidor HTTP
    const PORT = process.env.PORT || 3000;
    server.listen(PORT, () => {
      console.log(`🚀 Servidor TINS CARS escuchando en puerto ${PORT}`);
      console.log(`📊 Panel web: http://localhost:${PORT}`);
      console.log(`📡 API REST disponible en /api/trips/*`);
    });
  } catch (err) {
    console.error('❌ Error fatal al iniciar servidor:', err);
    process.exit(1);
  }
}

// Manejo de cierre graceful
process.on('SIGINT', async () => {
  console.log('\n⚠️ Cerrando servidor...');
  try {
    await redisClient.quit();
    await pgClient.end();
    process.exit(0);
  } catch (err) {
    console.error('Error al cerrar conexiones:', err);
    process.exit(1);
  }
});

startServer();