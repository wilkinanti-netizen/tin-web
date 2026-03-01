import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import Stripe from "https://esm.sh/stripe@11.1.0?target=deno"

// @ts-ignore: Deno is available in the Edge Function environment
const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
    httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

    try {
        const { action, customerId: supabaseId, amount, currency = 'usd' } = await req.json()

        // Helper: Find or create Stripe Customer by metadata
        const getStripeCustomer = async (uid: string) => {
            if (uid.startsWith('cus_')) return uid;

            const customers = await stripe.customers.search({
                query: `metadata['supabase_id']:'${uid}'`,
            });

            if (customers.data.length > 0) return customers.data[0].id;

            const newCustomer = await stripe.customers.create({
                metadata: { supabase_id: uid },
            });
            return newCustomer.id;
        }

        const stripeCustomerId = await getStripeCustomer(supabaseId)

        if (action === 'create-setup-intent') {
            const setupIntent = await stripe.setupIntents.create({
                customer: stripeCustomerId,
                payment_method_types: ['card'],
            })
            const ephemeralKey = await stripe.ephemeralKeys.create(
                { customer: stripeCustomerId },
                { apiVersion: '2022-11-15' }
            )
            return new Response(JSON.stringify({
                setupIntent: setupIntent.client_secret,
                ephemeralKey: ephemeralKey.secret,
                customer: stripeCustomerId
            }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        if (action === 'create-payment-intent') {
            const paymentIntent = await stripe.paymentIntents.create({
                amount: Math.round(amount * 100),
                currency,
                customer: stripeCustomerId,
            })
            return new Response(JSON.stringify({ paymentIntent: paymentIntent.client_secret }), {
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        return new Response(JSON.stringify({ error: 'Invalid action' }), { status: 400, headers: corsHeaders })
    } catch (error: any) {
        return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: corsHeaders })
    }
})
