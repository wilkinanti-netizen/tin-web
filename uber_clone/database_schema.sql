-- Esquema de Base de Datos para Uber Clone (TINS CARS)

-- 1. Tabla de Perfiles
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    avatar_url TEXT,
    is_driver BOOLEAN DEFAULT FALSE,
    driver_status TEXT DEFAULT 'inactive', -- 'active', 'inactive', 'busy'
    phone_number TEXT,
    gender TEXT,
    birth_date DATE,
    ssn_last_4 TEXT,
    fcm_token TEXT,
    device_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Tabla de Datos del Conductor
CREATE TABLE IF NOT EXISTS driver_data (
    profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE PRIMARY KEY,
    vehicle_model TEXT NOT NULL,
    vehicle_plate TEXT NOT NULL,
    vehicle_type TEXT NOT NULL, -- 'essentials', 'executive', 'motorcycle', etc.
    is_verified BOOLEAN DEFAULT FALSE,
    active_services TEXT[] DEFAULT '{}',
    vehicle_year TEXT,
    vehicle_color TEXT,
    background_check_consent BOOLEAN DEFAULT FALSE,
    doc_license_url TEXT,
    doc_insurance_url TEXT,
    doc_registration_url TEXT,
    doc_photo_url TEXT,
    docs_submitted_at TIMESTAMP WITH TIME ZONE,
    earnings DECIMAL(10, 2) DEFAULT 0.0,
    trips_count INTEGER DEFAULT 0,
    rating DECIMAL(3, 2) DEFAULT 5.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Tabla de Viajes (TRIPS) - CRITICAL: Incluye columnas de pago
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    passenger_id UUID NOT NULL REFERENCES profiles(id),
    driver_id UUID REFERENCES profiles(id),
    
    pickup_lat DECIMAL(10, 7) NOT NULL,
    pickup_lng DECIMAL(10, 7) NOT NULL,
    dropoff_lat DECIMAL(10, 7) NOT NULL,
    dropoff_lng DECIMAL(10, 7) NOT NULL,
    
    pickup_address TEXT NOT NULL,
    dropoff_address TEXT NOT NULL,
    
    distance DECIMAL(10, 2) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'requested', -- 'requested', 'accepted', 'arrived', 'inProgress', 'completed', 'cancelled'
    
    driver_lat DECIMAL(10, 7),
    driver_lng DECIMAL(10, 7),
    
    vehicle_type TEXT NOT NULL,
    payment_method TEXT DEFAULT 'Efectivo',
    comment TEXT,
    has_extra_luggage BOOLEAN DEFAULT FALSE,
    has_pets BOOLEAN DEFAULT FALSE,
    
    payment_intent_id TEXT,
    payment_status TEXT,
    cancellation_reason TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Tabla de Mensajes (CHAT)
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES profiles(id),
    text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Tabla de Historial GPS (Tiempo Real)
CREATE TABLE IF NOT EXISTS gps_data (
    id SERIAL PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 7) NOT NULL,
    longitude DECIMAL(10, 7) NOT NULL,
    timestamp BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_trip_id ON gps_data(trip_id);

-- 5. Script para arreglar columnas si la tabla ya existe
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

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='trips' AND COLUMN_NAME='cancellation_reason') THEN
        ALTER TABLE trips ADD COLUMN cancellation_reason TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='driver_data' AND COLUMN_NAME='is_online') THEN
        ALTER TABLE driver_data ADD COLUMN is_online BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='profiles' AND COLUMN_NAME='phone_number') THEN
        ALTER TABLE profiles ADD COLUMN phone_number TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='profiles' AND COLUMN_NAME='gender') THEN
        ALTER TABLE profiles ADD COLUMN gender TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='profiles' AND COLUMN_NAME='birth_date') THEN
        ALTER TABLE profiles ADD COLUMN birth_date DATE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='profiles' AND COLUMN_NAME='ssn_last_4') THEN
        ALTER TABLE profiles ADD COLUMN ssn_last_4 TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='driver_data' AND COLUMN_NAME='vehicle_year') THEN
        ALTER TABLE driver_data ADD COLUMN vehicle_year TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='driver_data' AND COLUMN_NAME='vehicle_color') THEN
        ALTER TABLE driver_data ADD COLUMN vehicle_color TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='driver_data' AND COLUMN_NAME='background_check_consent') THEN
        ALTER TABLE driver_data ADD COLUMN background_check_consent BOOLEAN DEFAULT FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='profiles' AND COLUMN_NAME='device_id') THEN
        ALTER TABLE profiles ADD COLUMN device_id TEXT;
    END IF;
END $$;

-- 6. Storage Bucket for Avatars (Run manually in Supabase SQL editor if getting errors)
-- Create bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for avatars bucket (Need to run on storage.objects)
-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow public read
CREATE POLICY "Public Read Avatars" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'avatars');

-- Allow authenticated users to upload their own avatar
CREATE POLICY "Auth Users Upload Avatars" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow authenticated users to update their own avatar
CREATE POLICY "Auth Users Update Avatars" 
ON storage.objects FOR UPDATE 
TO authenticated 
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 7. Payout Methods (Bank Accounts)
CREATE TABLE IF NOT EXISTS payout_methods (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_holder_name TEXT NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE payout_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own payout methods" 
ON payout_methods FOR ALL 
TO authenticated 
USING (auth.uid() = user_id);
