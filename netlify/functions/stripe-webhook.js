// =====================================================================
//  netlify/functions/stripe-webhook.js
// ---------------------------------------------------------------------
//  Stripe calls THIS endpoint after a payment succeeds, renews, or a
//  subscription is cancelled. It verifies the request really came from
//  Stripe, then writes the member's status into the subscriptions table
//  using the service-role key (which bypasses Row-Level Security).
//
//  Required Netlify environment variables:
//    STRIPE_SECRET_KEY           - Stripe secret key
//    STRIPE_WEBHOOK_SECRET       - from the webhook you create in Stripe (whsec_...)
//    SUPABASE_URL                - your project URL
//    SUPABASE_SERVICE_ROLE_KEY   - Supabase → Settings → API → service_role key
//                                  (SERVER-SIDE ONLY — never put this in the app)
//
//  In netlify.toml, raw body access is needed for signature checks, which
//  Netlify provides via event.body; we handle base64 just in case.
// =====================================================================

const Stripe = require('stripe');
const { createClient } = require('@supabase/supabase-js');

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function setStatus(row) {
  const { error } = await supabase
    .from('subscriptions')
    .upsert({ ...row, updated_at: new Date().toISOString() }, { onConflict: 'user_id' });
  if (error) console.error('Supabase upsert error:', error);
}

exports.handler = async (event) => {
  const sig = event.headers['stripe-signature'];
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body, 'base64').toString('utf8')
    : event.body;

  let stripeEvent;
  try {
    stripeEvent = stripe.webhooks.constructEvent(rawBody, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error('Signature verification failed:', err.message);
    return { statusCode: 400, body: `Webhook Error: ${err.message}` };
  }

  try {
    switch (stripeEvent.type) {
      case 'checkout.session.completed': {
        const s = stripeEvent.data.object;
        const userId = s.client_reference_id || s.metadata?.supabase_user_id;
        if (userId) {
          await setStatus({
            user_id: userId,
            stripe_customer_id: s.customer,
            stripe_subscription_id: s.subscription,
            status: 'active',
          });
        }
        break;
      }

      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const sub = stripeEvent.data.object;
        const userId = sub.metadata?.supabase_user_id;
        const isActive = ['active', 'trialing'].includes(sub.status);
        if (userId) {
          await setStatus({
            user_id: userId,
            stripe_customer_id: sub.customer,
            stripe_subscription_id: sub.id,
            status: isActive ? 'active' : 'inactive',
            current_period_end: sub.current_period_end
              ? new Date(sub.current_period_end * 1000).toISOString()
              : null,
          });
        }
        break;
      }

      default:
        // Other event types are ignored for now.
        break;
    }

    return { statusCode: 200, body: JSON.stringify({ received: true }) };
  } catch (err) {
    console.error('stripe-webhook handler error:', err);
    return { statusCode: 500, body: 'Server error' };
  }
};
