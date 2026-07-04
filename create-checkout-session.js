// =====================================================================
//  netlify/functions/create-checkout-session.js
// ---------------------------------------------------------------------
//  Called by the app when a signed-in member clicks "Subscribe".
//  Verifies who they are (via their Supabase access token), then creates
//  a Stripe Checkout session in subscription mode and returns its URL.
//
//  Required Netlify environment variables:
//    STRIPE_SECRET_KEY     - from Stripe → Developers → API keys (secret)
//    STRIPE_PRICE_ID       - the recurring Price ID of your plan (price_...)
//    SUPABASE_URL          - your project URL
//    SUPABASE_ANON_KEY     - the public anon key (used only to read the token)
//    URL                   - provided automatically by Netlify (your site URL)
// =====================================================================

const Stripe = require('stripe');
const { createClient } = require('@supabase/supabase-js');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    // 1. Identify the signed-in user from the token the app sends.
    const authHeader = event.headers.authorization || event.headers.Authorization || '';
    const token = authHeader.replace(/^Bearer\s+/i, '');
    if (!token) return { statusCode: 401, body: 'Not signed in' };

    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) return { statusCode: 401, body: 'Invalid session' };

    // 2. Create the subscription checkout session.
    const siteUrl = process.env.URL || 'http://localhost:8888';
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      line_items: [{ price: process.env.STRIPE_PRICE_ID, quantity: 1 }],
      client_reference_id: user.id,
      customer_email: user.email,
      // Stamp the Supabase user id onto the subscription so the webhook
      // always knows whose status to update, even on renewals/cancellations.
      subscription_data: { metadata: { supabase_user_id: user.id } },
      metadata: { supabase_user_id: user.id },
      success_url: `${siteUrl}/app?checkout=success`,
      cancel_url: `${siteUrl}/app?checkout=cancel`,
    });

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: session.url }),
    };
  } catch (err) {
    console.error('create-checkout-session error:', err);
    return { statusCode: 500, body: 'Server error' };
  }
};
