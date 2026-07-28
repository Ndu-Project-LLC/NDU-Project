const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');
const { Resend } = require('resend');

// Initialize admin only if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ── Resend email sender ────────────────────────────────────────────────────
// API key stored as Firebase secret: firebase functions:secrets:set RESEND_API_KEY
// Domain: nduproject.tech (verified in Resend dashboard)
const RESEND_FROM_EMAIL = 'NDU Project <noreply@nduproject.tech>';
function getResendClient() {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    console.error('RESEND_API_KEY not configured. Set it via: firebase functions:secrets:set RESEND_API_KEY');
    throw new functions.https.HttpsError('failed-precondition', 'Email service not configured.');
  }
  return new Resend(apiKey);
}

// ── 2FA OTP helpers ────────────────────────────────────────────────────────
const OTP_LENGTH = 6;
const OTP_TTL_MS = 10 * 60 * 1000; // 10 minutes
const OTP_COLLECTION = 'twoFactorCodes';
const MAX_OTP_ATTEMPTS = 5;

function generateOtp() {
  let otp = '';
  for (let i = 0; i < OTP_LENGTH; i++) {
    otp += Math.floor(Math.random() * 10).toString();
  }
  return otp;
}


// Lazy-load config to avoid deployment timeouts
function getRuntimeConfig() {
  try {
    return typeof functions.config === 'function' ? functions.config() : {};
  } catch (e) {
    console.warn('Failed to load runtime config:', e);
    return {};
  }
}

function getCorsAllowedOrigins() {
  const runtimeConfig = getRuntimeConfig();
  const appConfig = runtimeConfig.app || {};
  const configuredBaseUrl = appConfig.base_url || appConfig.baseUrl || '';
  const configAllowedOrigins = appConfig.allowed_origins || appConfig.allowedOrigins || '';
  const envAllowedOrigins = process.env.APP_ALLOWED_ORIGINS || '';
  const APP_BASE_URL = process.env.APP_BASE_URL || configuredBaseUrl || 'https://ndu-d3f60.web.app';
  const EXTRA_ALLOWED_ORIGINS = [configAllowedOrigins, envAllowedOrigins]
    .flatMap((value) => value.split(','))
    .map((origin) => origin.trim())
    .filter(Boolean);
  return [
    /^(http|https):\/\/localhost(:\d+)?$/,
    /^(http|https):\/\/127\.0\.0\.1(:\d+)?$/,
    /\.web\.app$/,
    /\.firebaseapp\.com$/,
    /^https:\/\/staging\.admin\.nduproject\.com$/,
    /^https:\/\/.*\.nduproject\.com$/, // Allow all nduproject.com subdomains
    /^https:\/\/nduproject\.com$/, // Allow bare domain
    /^https:\/\/www\.nduproject\.com$/, // Allow www
    APP_BASE_URL,
    ...EXTRA_ALLOWED_ORIGINS
  ];
}

const FX_CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const fxCache = { usdToNgn: null, fetchedAt: 0 };

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Verify Firebase Auth token from request headers
 */
async function verifyAuthToken(req) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  try {
    const idToken = authHeader.split('Bearer ')[1];
    return await admin.auth().verifyIdToken(idToken);
  } catch (error) {
    console.error('Auth token verification failed:', error);
    return null;
  }
}

/**
 * Set CORS headers for response
 */
function setCorsHeaders(req, res) {
  const origin = (req.headers.origin || '').toString().trim();
  const CORS_ALLOWED_ORIGINS = getCorsAllowedOrigins();
  const isAllowed = origin.length > 0 && CORS_ALLOWED_ORIGINS.some((allowed) =>
    typeof allowed === 'string' ? allowed === origin : allowed.test(origin)
  );

  if (isAllowed) {
    res.set('Access-Control-Allow-Origin', origin);
  } else if (req.method === 'OPTIONS') {
    // Keep preflight resilient even if an origin string is unexpectedly missing
    // or slightly different from runtime configuration.
    res.set('Access-Control-Allow-Origin', '*');
  }
  res.set('Vary', 'Origin');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

// (transformToClaudeFormat removed — project uses OpenAI, not Claude/Anthropic)

function getRequestOrigin(req) {
  return req.headers.origin || APP_BASE_URL;
}

function getPayPalBaseUrl(clientId) {
  const env = (process.env.PAYPAL_ENV || '').toLowerCase();
  if (env === 'sandbox') return 'https://api-m.sandbox.paypal.com';
  if (env === 'live') return 'https://api-m.paypal.com';

  const normalizedId = (clientId || '').toLowerCase();
  if (normalizedId.startsWith('sb') || normalizedId.includes('sandbox')) {
    return 'https://api-m.sandbox.paypal.com';
  }

  return 'https://api-m.paypal.com';
}

async function getUsdToNgnRate() {
  const now = Date.now();
  if (fxCache.usdToNgn && now - fxCache.fetchedAt < FX_CACHE_TTL_MS) {
    return fxCache.usdToNgn;
  }

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3500);
    const response = await fetch('https://open.er-api.com/v6/latest/USD', {
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!response.ok) {
      throw new Error(`FX fetch failed (${response.status})`);
    }

    const data = await response.json();
    const rate = Number(data?.rates?.NGN);
    if (!Number.isFinite(rate) || rate <= 0) {
      throw new Error('FX rate for NGN unavailable');
    }

    fxCache.usdToNgn = rate;
    fxCache.fetchedAt = now;
    return rate;
  } catch (error) {
    console.warn('FX rate fetch failed:', error.message || error);
    return null;
  }
}

/**
 * Get subscription pricing in cents
 */
function getSubscriptionPrice(tier, isAnnual) {
  const prices = {
    project: { monthly: 7900, annual: 79000 },
    program: { monthly: 18900, annual: 189000 },
    portfolio: { monthly: 44900, annual: 449000 }
  };
  const tierPrices = prices[tier] || prices.project;
  return isAnnual ? tierPrices.annual : tierPrices.monthly;
}

/**
 * Validate a coupon and calculate the discounted price (in cents).
 */
async function validateCouponForTier(couponCode, tier, originalPriceCents) {
  if (!couponCode) {
    return { couponId: null, discountedPriceCents: originalPriceCents, discountPercent: 0, discountAmount: 0 };
  }

  const couponSnapshot = await db.collection('coupons')
    .where('code', '==', couponCode.toUpperCase())
    .limit(1)
    .get();

  if (couponSnapshot.empty) {
    throw new Error('Coupon not found');
  }

  const couponDoc = couponSnapshot.docs[0];
  const coupon = couponDoc.data();

  const now = new Date();
  const validFrom = coupon.validFrom?.toDate ? coupon.validFrom.toDate() : new Date(0);
  const validUntil = coupon.validUntil?.toDate ? coupon.validUntil.toDate() : new Date(0);

  if (!coupon.isActive) throw new Error('Coupon is inactive');
  if (now < validFrom || now > validUntil) throw new Error('Coupon has expired');
  if (coupon.maxUses && coupon.currentUses >= coupon.maxUses) throw new Error('Coupon usage limit reached');
  if (coupon.applicableTiers && coupon.applicableTiers.length > 0 && !coupon.applicableTiers.includes(tier)) {
    throw new Error('Coupon not valid for this plan');
  }

  let discountedPriceCents = originalPriceCents;
  if (coupon.discountAmount && coupon.discountAmount > 0) {
    discountedPriceCents = Math.max(0, originalPriceCents - Math.round(coupon.discountAmount * 100));
  } else if (coupon.discountPercent && coupon.discountPercent > 0) {
    discountedPriceCents = Math.max(0, Math.round(originalPriceCents * (1 - coupon.discountPercent / 100)));
  }

  return {
    couponId: couponDoc.id,
    discountedPriceCents,
    discountPercent: coupon.discountPercent || 0,
    discountAmount: coupon.discountAmount || 0,
  };
}

/**
 * Secure OpenAI API Proxy
 * 
 * This Cloud Function acts as a secure proxy to OpenAI's Chat Completions API,
 * keeping the API key server-side and never exposing it to client code or version control.
 * 
 * The app already sends OpenAI-format requests (chat/completions with messages array),
 * so this proxy forwards them directly to OpenAI without format transformation.
 * 
 * Setup Instructions:
 * 1. Set your OpenAI API key as a secret in Firebase:
 *    firebase functions:secrets:set OPENAI_API_KEY
 *    
 * 2. Deploy this function:
 *    firebase deploy --only functions
 *    
 * 3. The app's SecureAPIConfig.baseUrl should point to this Cloud Function URL.
 * 
 * Security Features:
 * - API key stored as Firebase secret (never in code or environment)
 * - Optional Firebase Auth verification
 * - CORS configured for your app domain only
 * - Request validation and sanitization
 */

exports.openaiProxy = functions
  .runWith({
    secrets: ['OPENAI_API_KEY'],
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed. Use POST.' });
      return;
    }
    
    try {
      let apiKey = process.env.OPENAI_API_KEY;
      if (!apiKey) {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
          apiKey = authHeader.split('Bearer ')[1];
        }
      }
      if (!apiKey) {
        console.error('No API key configured (set OPENAI_API_KEY secret or provide via Authorization header)');
        res.status(500).json({ error: 'Service configuration error' });
        return;
      }
      
      // The app sends OpenAI-format requests directly — no transformation needed.
      // Just forward the payload as-is to OpenAI's Chat Completions API.
      const rawPayload = req.body.payload || req.body;

      // Ensure the payload has the required fields for OpenAI Chat Completions
      const openaiBody = {
        model: rawPayload.model || 'gpt-4o',
        messages: rawPayload.messages || [],
        temperature: rawPayload.temperature ?? 0.7,
        max_tokens: rawPayload.max_tokens || rawPayload.max_completion_tokens || 2000,
        stream: false,
      };
      
      // Copy over any additional fields the client may have sent
      if (rawPayload.response_format) openaiBody.response_format = rawPayload.response_format;
      if (rawPayload.top_p) openaiBody.top_p = rawPayload.top_p;
      if (rawPayload.frequency_penalty) openaiBody.frequency_penalty = rawPayload.frequency_penalty;
      if (rawPayload.presence_penalty) openaiBody.presence_penalty = rawPayload.presence_penalty;

      // Forward the request to OpenAI Chat Completions API
      const openaiUrl = 'https://api.openai.com/v1/chat/completions';
      
      const openaiResponse = await fetch(openaiUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify(openaiBody)
      });
      
      const data = await openaiResponse.json();
      
      // Return OpenAI's response to the client
      res.status(openaiResponse.status).json(data);
      
    } catch (error) {
      console.error('OpenAI proxy error:', error);
      res.status(500).json({ 
        error: 'Failed to process request',
        message: error.message 
      });
    }
  });

// openaiProxy is the canonical export (see above)

// ============================================================================
// STRIPE PAYMENT FUNCTIONS
// ============================================================================

/**
 * Create Stripe Checkout Session
 * 
 * Setup: firebase functions:secrets:set STRIPE_SECRET_KEY
 */
exports.createStripeCheckout = functions
  .runWith({
    secrets: ['STRIPE_SECRET_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
      if (!stripeSecretKey) {
        console.error('STRIPE_SECRET_KEY not configured');
        res.status(500).json({ error: 'Payment service not configured' });
        return;
      }
      
      const { tier, isAnnual, email, couponCode } = req.body;
      const userId = decodedToken.uid;
      let priceInCents = getSubscriptionPrice(tier, isAnnual);
      let couponId = null;

      if (couponCode) {
        try {
          const couponResult = await validateCouponForTier(couponCode, tier, priceInCents);
          priceInCents = couponResult.discountedPriceCents;
          couponId = couponResult.couponId;
        } catch (err) {
          res.status(400).json({ error: err.message || 'Invalid coupon' });
          return;
        }
      }
      
      // Create pending subscription record
      const subscriptionRef = db.collection('subscriptions').doc();
      await subscriptionRef.set({
        id: subscriptionRef.id,
        userId,
        tier,
        status: 'pending',
        provider: 'stripe',
        isAnnual: isAnnual || false,
        couponId: couponId || null,
        couponCode: couponCode ? couponCode.toUpperCase() : null,
        discountedPriceCents: priceInCents,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Call Stripe API to create checkout session
      const origin = getRequestOrigin(req);
      const response = await fetch('https://api.stripe.com/v1/checkout/sessions', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: new URLSearchParams({
          'payment_method_types[]': 'card',
          'line_items[0][price_data][currency]': 'usd',
          'line_items[0][price_data][product_data][name]': `${tier.charAt(0).toUpperCase() + tier.slice(1)} Plan`,
          'line_items[0][price_data][unit_amount]': priceInCents.toString(),
          'line_items[0][quantity]': '1',
          'mode': 'payment',
          'success_url': `${origin}/payment-success?session_id={CHECKOUT_SESSION_ID}&subscription_id=${subscriptionRef.id}`,
          'cancel_url': `${origin}/pricing`,
          'customer_email': email,
          'metadata[subscription_id]': subscriptionRef.id,
          'metadata[user_id]': userId,
          'metadata[tier]': tier,
          ...(couponId ? { 'metadata[coupon_id]': couponId } : {})
        })
      });
      
      const session = await response.json();
      
      if (session.error) {
        throw new Error(session.error.message);
      }
      
      // Update subscription with Stripe session ID
      await subscriptionRef.update({
        externalSubscriptionId: session.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      res.json({
        success: true,
        checkoutUrl: session.url,
        subscriptionId: subscriptionRef.id
      });
      
    } catch (error) {
      console.error('Stripe checkout error:', error);
      res.status(500).json({ error: error.message });
    }
  });

/**
 * Verify Stripe Payment
 */
exports.verifyStripePayment = functions
  .runWith({
    secrets: ['STRIPE_SECRET_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
      if (!stripeSecretKey) {
        res.status(500).json({ error: 'Payment service not configured' });
        return;
      }
      
      const { reference } = req.body;
      
      // Retrieve session from Stripe
      const response = await fetch(`https://api.stripe.com/v1/checkout/sessions/${reference}`, {
        headers: {
          'Authorization': `Bearer ${stripeSecretKey}`
        }
      });
      
      const session = await response.json();
      
      if (session.payment_status === 'paid') {
        const subscriptionId = session.metadata?.subscription_id;
        const userId = session.metadata?.user_id;
        const tier = session.metadata?.tier;
        const couponId = session.metadata?.coupon_id;
        
        if (subscriptionId) {
          const now = new Date();
          const endDate = new Date(now);
          endDate.setFullYear(endDate.getFullYear() + 1);

          const subscriptionDoc = await db.collection('subscriptions').doc(subscriptionId).get();
          const subscriptionData = subscriptionDoc.data() || {};
          
          await db.collection('subscriptions').doc(subscriptionId).update({
            status: 'active',
            startDate: admin.firestore.Timestamp.fromDate(now),
            endDate: admin.firestore.Timestamp.fromDate(endDate),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          const appliedCouponId = couponId || subscriptionData.couponId;
          if (appliedCouponId) {
            await db.collection('coupons').doc(appliedCouponId).update({
              currentUses: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
          
          // Record invoice
          const invoiceRef = db.collection('invoices').doc();
          await invoiceRef.set({
            id: invoiceRef.id,
            userId: userId || decodedToken.uid,
            amount: session.amount_total / 100,
            currency: (session.currency || 'usd').toUpperCase(),
            status: 'paid',
            provider: 'stripe',
            subscriptionId,
            externalId: session.id,
            tier,
            description: `${tier ? tier.charAt(0).toUpperCase() + tier.slice(1) : ''} Plan Subscription`,
            receiptUrl: session.receipt_url || null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        
        res.json({ success: true, subscriptionId });
      } else {
        res.json({ success: false, error: 'Payment not completed' });
      }
      
    } catch (error) {
      console.error('Stripe verification error:', error);
      res.status(500).json({ error: error.message });
    }
  });

// ============================================================================
// PAYPAL PAYMENT FUNCTIONS
// ============================================================================

/**
 * Create PayPal Order
 * 
 * Setup:
 *   firebase functions:secrets:set PAYPAL_CLIENT_ID
 *   firebase functions:secrets:set PAYPAL_CLIENT_SECRET
 */
exports.createPayPalOrder = functions
  .runWith({
    secrets: ['PAYPAL_CLIENT_ID', 'PAYPAL_CLIENT_SECRET'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const clientId = process.env.PAYPAL_CLIENT_ID;
      const clientSecret = process.env.PAYPAL_CLIENT_SECRET;
      
      if (!clientId || !clientSecret) {
        console.error('PayPal credentials not configured');
        res.status(500).json({ error: 'Payment service not configured' });
        return;
      }
      
      const { tier, isAnnual, couponCode } = req.body;
      const userId = decodedToken.uid;
      let priceInCents = getSubscriptionPrice(tier, isAnnual);
      let couponId = null;

      if (couponCode) {
        try {
          const couponResult = await validateCouponForTier(couponCode, tier, priceInCents);
          priceInCents = couponResult.discountedPriceCents;
          couponId = couponResult.couponId;
        } catch (err) {
          res.status(400).json({ error: err.message || 'Invalid coupon' });
          return;
        }
      }
      const priceInDollars = (priceInCents / 100).toFixed(2);
      
      // Create pending subscription record
      const subscriptionRef = db.collection('subscriptions').doc();
      await subscriptionRef.set({
        id: subscriptionRef.id,
        userId,
        tier,
        status: 'pending',
        provider: 'paypal',
        isAnnual: isAnnual || false,
        couponId: couponId || null,
        couponCode: couponCode ? couponCode.toUpperCase() : null,
        discountedPriceCents: priceInCents,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Get PayPal access token
      const paypalBaseUrl = getPayPalBaseUrl(clientId);
      const authResponse = await fetch(`${paypalBaseUrl}/v1/oauth2/token`, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'grant_type=client_credentials'
      });
      
      const authData = await authResponse.json();
      if (!authData.access_token) {
        throw new Error('Failed to authenticate with PayPal');
      }
      
      // Create PayPal order
      const origin = getRequestOrigin(req);
      const orderResponse = await fetch(`${paypalBaseUrl}/v2/checkout/orders`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${authData.access_token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          intent: 'CAPTURE',
          purchase_units: [{
            amount: {
              currency_code: 'USD',
              value: priceInDollars
            },
            description: `${tier.charAt(0).toUpperCase() + tier.slice(1)} Plan Subscription`,
            custom_id: subscriptionRef.id
          }],
          application_context: {
            return_url: `${origin}/payment-success?subscription_id=${subscriptionRef.id}`,
            cancel_url: `${origin}/pricing`
          }
        })
      });
      
      const order = await orderResponse.json();
      
      if (order.error) {
        throw new Error(order.error.message || 'PayPal order creation failed');
      }
      
      // Update subscription with PayPal order ID
      await subscriptionRef.update({
        externalSubscriptionId: order.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const approvalLink = order.links?.find(link => link.rel === 'approve');
      
      res.json({
        success: true,
        approvalUrl: approvalLink?.href,
        orderId: order.id,
        subscriptionId: subscriptionRef.id
      });
      
    } catch (error) {
      console.error('PayPal order error:', error);
      res.status(500).json({ error: error.message });
    }
  });

/**
 * Verify PayPal Payment
 */
exports.verifyPayPalPayment = functions
  .runWith({
    secrets: ['PAYPAL_CLIENT_ID', 'PAYPAL_CLIENT_SECRET'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const clientId = process.env.PAYPAL_CLIENT_ID;
      const clientSecret = process.env.PAYPAL_CLIENT_SECRET;
      
      if (!clientId || !clientSecret) {
        res.status(500).json({ error: 'Payment service not configured' });
        return;
      }
      
      const { reference } = req.body;
      
      // Get PayPal access token
      const paypalBaseUrl = getPayPalBaseUrl(clientId);
      const authResponse = await fetch(`${paypalBaseUrl}/v1/oauth2/token`, {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${Buffer.from(`${clientId}:${clientSecret}`).toString('base64')}`,
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'grant_type=client_credentials'
      });
      
      const authData = await authResponse.json();
      
      // Capture the payment
      const captureResponse = await fetch(`${paypalBaseUrl}/v2/checkout/orders/${reference}/capture`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${authData.access_token}`,
          'Content-Type': 'application/json'
        }
      });
      
      const captureData = await captureResponse.json();
      
      if (captureData.status === 'COMPLETED') {
        const subscriptionId = captureData.purchase_units?.[0]?.custom_id;
        const purchaseUnit = captureData.purchase_units?.[0];
        const capture = purchaseUnit?.payments?.captures?.[0];
        
        if (subscriptionId) {
          const now = new Date();
          const endDate = new Date(now);
          endDate.setFullYear(endDate.getFullYear() + 1);
          
          // Get subscription to get tier and userId
          const subscriptionDoc = await db.collection('subscriptions').doc(subscriptionId).get();
          const subscriptionData = subscriptionDoc.data() || {};
          
          await db.collection('subscriptions').doc(subscriptionId).update({
            status: 'active',
            startDate: admin.firestore.Timestamp.fromDate(now),
            endDate: admin.firestore.Timestamp.fromDate(endDate),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });

          if (subscriptionData.couponId) {
            await db.collection('coupons').doc(subscriptionData.couponId).update({
              currentUses: admin.firestore.FieldValue.increment(1),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
          }
          
          // Record invoice
          const invoiceRef = db.collection('invoices').doc();
          await invoiceRef.set({
            id: invoiceRef.id,
            userId: subscriptionData.userId || decodedToken.uid,
            amount: parseFloat(capture?.amount?.value || purchaseUnit?.amount?.value || 0),
            currency: (capture?.amount?.currency_code || purchaseUnit?.amount?.currency_code || 'USD'),
            status: 'paid',
            provider: 'paypal',
            subscriptionId,
            externalId: captureData.id,
            tier: subscriptionData.tier,
            description: `${subscriptionData.tier ? subscriptionData.tier.charAt(0).toUpperCase() + subscriptionData.tier.slice(1) : ''} Plan Subscription`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        
        res.json({ success: true, subscriptionId });
      } else {
        res.json({ success: false, error: 'Payment not completed' });
      }
      
    } catch (error) {
      console.error('PayPal verification error:', error);
      res.status(500).json({ error: error.message });
    }
  });

// ============================================================================
// PAYSTACK PAYMENT FUNCTIONS
// ============================================================================

/**
 * Create Paystack Transaction
 * 
 * Setup: firebase functions:secrets:set PAYSTACK_SECRET_KEY
 */
exports.createPaystackTransaction = functions
  .runWith({
    secrets: ['PAYSTACK_SECRET_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY;
      if (!paystackSecretKey) {
        console.error('PAYSTACK_SECRET_KEY not configured');
        res.status(500).json({ error: 'Payment service not configured' });
        return;
      }
      
      const { tier, isAnnual, email, couponCode } = req.body;
      const userId = decodedToken.uid;
      let priceInCents = getSubscriptionPrice(tier, isAnnual);
      let couponId = null;

      if (couponCode) {
        try {
          const couponResult = await validateCouponForTier(couponCode, tier, priceInCents);
          priceInCents = couponResult.discountedPriceCents;
          couponId = couponResult.couponId;
        } catch (err) {
          res.status(400).json({ error: err.message || 'Invalid coupon' });
          return;
        }
      }

      const paystackCurrency = (process.env.PAYSTACK_CURRENCY || 'NGN').toUpperCase();
      const paystackUsdRateRaw = process.env.PAYSTACK_USD_TO_NGN;
      const paystackUsdRateOverride = Number.isFinite(Number(paystackUsdRateRaw)) ? Number(paystackUsdRateRaw) : null;
      const liveUsdToNgnRate = paystackCurrency === 'NGN' ? await getUsdToNgnRate() : null;
      const paystackUsdRate = paystackUsdRateOverride ?? liveUsdToNgnRate ?? 1500;
      const paystackUsdEquivalentRaw = process.env.PAYSTACK_USD_EQUIVALENT;
      const paystackUsdEquivalent = Number.isFinite(Number(paystackUsdEquivalentRaw)) ? Number(paystackUsdEquivalentRaw) : 20;
      const baseUsdAmount = paystackUsdEquivalent > 0 ? paystackUsdEquivalent : (priceInCents / 100);
      let priceInMinorUnits;

      if (paystackCurrency === 'NGN') {
        priceInMinorUnits = Math.round(baseUsdAmount * paystackUsdRate * 100);
      } else {
        const paystackAmountMultiplierRaw = process.env.PAYSTACK_AMOUNT_MULTIPLIER;
        const paystackAmountMultiplier = Number.isFinite(Number(paystackAmountMultiplierRaw))
          ? Number(paystackAmountMultiplierRaw)
          : 1;
        priceInMinorUnits = Math.round(priceInCents * paystackAmountMultiplier);
      }
      
      // Create pending subscription record
      const subscriptionRef = db.collection('subscriptions').doc();
      await subscriptionRef.set({
        id: subscriptionRef.id,
        userId,
        tier,
        status: 'pending',
        provider: 'paystack',
        isAnnual: isAnnual || false,
        couponId: couponId || null,
        couponCode: couponCode ? couponCode.toUpperCase() : null,
        discountedPriceCents: priceInCents,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Initialize Paystack transaction
      const origin = getRequestOrigin(req);
      const response = await fetch('https://api.paystack.co/transaction/initialize', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${paystackSecretKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email,
          amount: priceInMinorUnits,
          currency: paystackCurrency,
          reference: subscriptionRef.id,
          callback_url: `${origin}/payment-success`,
          metadata: {
            subscription_id: subscriptionRef.id,
            user_id: userId,
            tier
          }
        })
      });
      
      const data = await response.json();
      
      if (!data.status) {
        throw new Error(data.message || 'Paystack initialization failed');
      }
      
      // Update subscription with Paystack reference
      await subscriptionRef.update({
        externalSubscriptionId: data.data.reference,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      res.json({
        success: true,
        authorizationUrl: data.data.authorization_url,
        accessCode: data.data.access_code,
        reference: data.data.reference,
        subscriptionId: subscriptionRef.id
      });
      
    } catch (error) {
      console.error('Paystack transaction error:', error);
      res.status(500).json({ error: error.message });
    }
  });

/**
 * Verify Paystack Payment
 */
exports.verifyPaystackPayment = functions
  .runWith({
    secrets: ['PAYSTACK_SECRET_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY;
      if (!paystackSecretKey) {
        res.status(500).json({ error: 'Payment service not configured' });
        return;
      }
      
      const { reference } = req.body;
      
      // Verify transaction
      const response = await fetch(`https://api.paystack.co/transaction/verify/${reference}`, {
        headers: {
          'Authorization': `Bearer ${paystackSecretKey}`
        }
      });
      
      const data = await response.json();
      
      if (data.status && data.data.status === 'success') {
        const subscriptionId = data.data.metadata?.subscription_id || reference;
        const txnData = data.data;
        
        const now = new Date();
        const endDate = new Date(now);
        endDate.setFullYear(endDate.getFullYear() + 1);
        
        // Get subscription to get tier and userId
        const subscriptionDoc = await db.collection('subscriptions').doc(subscriptionId).get();
        const subscriptionData = subscriptionDoc.data() || {};
        
        await db.collection('subscriptions').doc(subscriptionId).update({
          status: 'active',
          startDate: admin.firestore.Timestamp.fromDate(now),
          endDate: admin.firestore.Timestamp.fromDate(endDate),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        if (subscriptionData.couponId) {
          await db.collection('coupons').doc(subscriptionData.couponId).update({
            currentUses: admin.firestore.FieldValue.increment(1),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
        
        // Record invoice
        const invoiceRef = db.collection('invoices').doc();
        await invoiceRef.set({
          id: invoiceRef.id,
          userId: subscriptionData.userId || decodedToken.uid,
          amount: (txnData.amount || 0) / 100,
          currency: txnData.currency || 'NGN',
          status: 'paid',
          provider: 'paystack',
          subscriptionId,
          externalId: txnData.reference,
          tier: subscriptionData.tier || txnData.metadata?.tier,
          description: `${subscriptionData.tier ? subscriptionData.tier.charAt(0).toUpperCase() + subscriptionData.tier.slice(1) : ''} Plan Subscription`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        res.json({ success: true, subscriptionId });
      } else {
        res.json({ success: false, error: 'Payment not completed' });
      }
      
    } catch (error) {
      console.error('Paystack verification error:', error);
      res.status(500).json({ error: error.message });
    }
  });

// ============================================================================
// COUPON MANAGEMENT
// ============================================================================

/**
 * Apply Coupon to Payment
 * Validates and applies a coupon code during checkout
 */
exports.applyCoupon = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const { couponCode, tier, originalPrice } = req.body;
      
      if (!couponCode || !tier || originalPrice === undefined) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const originalPriceCents = Math.round(Number(originalPrice) * 100);
      const couponResult = await validateCouponForTier(couponCode, tier, originalPriceCents);
      
      res.json({
        success: true,
        couponId: couponResult.couponId,
        originalPrice,
        discountedPrice: Math.round(couponResult.discountedPriceCents) / 100,
        discountPercent: couponResult.discountPercent,
        discountAmount: couponResult.discountAmount || 0,
        description: ''
      });
      
    } catch (error) {
      console.error('Apply coupon error:', error);
      res.status(500).json({ error: error.message });
    }
  });

/**
 * Use Coupon (increment usage count)
 * Called after successful payment
 */
exports.useCoupon = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const { couponId } = req.body;
      
      if (!couponId) {
        res.status(400).json({ error: 'Missing coupon ID' });
        return;
      }
      
      // Increment usage count
      await db.collection('coupons').doc(couponId).update({
        currentUses: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      res.json({ success: true });
      
    } catch (error) {
      console.error('Use coupon error:', error);
      res.status(500).json({ error: error.message });
    }
  });

// ============================================================================
// INVOICE HISTORY
// ============================================================================

/**
 * Get User Invoice History
 * Fetches payment history from all providers for a specific user
 */
exports.getUserInvoices = functions
  .runWith({
    secrets: ['STRIPE_SECRET_KEY', 'PAYPAL_CLIENT_ID', 'PAYPAL_CLIENT_SECRET', 'PAYSTACK_SECRET_KEY'],
    timeoutSeconds: 60,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const { userId, userEmail } = req.body;
      const targetUserId = userId || decodedToken.uid;
      
      // Check if requesting user is admin or requesting own data
      const adminEmails = ['chungu424@gmail.com'];
      const isAdmin = adminEmails.includes(decodedToken.email);
      if (!isAdmin && targetUserId !== decodedToken.uid) {
        res.status(403).json({ error: 'Not authorized to view this user\'s invoices' });
        return;
      }
      
      const invoices = [];
      
      // Get subscriptions for the user to find external IDs
      const subscriptionsSnapshot = await db.collection('subscriptions')
        .where('userId', '==', targetUserId)
        .orderBy('createdAt', 'desc')
        .get();
      
      // Also fetch from invoices collection (stored after successful payments)
      const invoicesSnapshot = await db.collection('invoices')
        .where('userId', '==', targetUserId)
        .orderBy('createdAt', 'desc')
        .get();
      
      for (const doc of invoicesSnapshot.docs) {
        const data = doc.data();
        invoices.push({
          id: doc.id,
          amount: data.amount || 0,
          currency: data.currency || 'USD',
          status: data.status || 'paid',
          provider: data.provider || 'unknown',
          description: data.description || 'Subscription payment',
          createdAt: data.createdAt?.toDate()?.toISOString() || new Date().toISOString(),
          paidAt: data.paidAt?.toDate()?.toISOString(),
          subscriptionId: data.subscriptionId,
          externalId: data.externalId,
          tier: data.tier,
          receiptUrl: data.receiptUrl,
        });
      }
      
      // Try to fetch from Stripe if configured
      const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
      if (stripeSecretKey && userEmail) {
        try {
          // First find customer by email
          const customerResponse = await fetch(
            `https://api.stripe.com/v1/customers?email=${encodeURIComponent(userEmail)}&limit=1`,
            {
              headers: { 'Authorization': `Bearer ${stripeSecretKey}` }
            }
          );
          const customerData = await customerResponse.json();
          
          if (customerData.data && customerData.data.length > 0) {
            const customerId = customerData.data[0].id;
            
            // Fetch charges/payments for this customer
            const chargesResponse = await fetch(
              `https://api.stripe.com/v1/charges?customer=${customerId}&limit=100`,
              {
                headers: { 'Authorization': `Bearer ${stripeSecretKey}` }
              }
            );
            const chargesData = await chargesResponse.json();
            
            if (chargesData.data) {
              for (const charge of chargesData.data) {
                // Avoid duplicates
                if (!invoices.find(i => i.externalId === charge.id)) {
                  invoices.push({
                    id: `stripe_${charge.id}`,
                    amount: charge.amount / 100,
                    currency: charge.currency.toUpperCase(),
                    status: charge.status === 'succeeded' ? 'paid' : charge.status,
                    provider: 'stripe',
                    description: charge.description || 'Stripe payment',
                    createdAt: new Date(charge.created * 1000).toISOString(),
                    paidAt: charge.status === 'succeeded' ? new Date(charge.created * 1000).toISOString() : null,
                    externalId: charge.id,
                    receiptUrl: charge.receipt_url,
                    tier: charge.metadata?.tier,
                  });
                }
              }
            }
          }
        } catch (stripeError) {
          console.error('Error fetching Stripe invoices:', stripeError);
        }
      }
      
      // Try to fetch from PayPal if configured
      const paypalClientId = process.env.PAYPAL_CLIENT_ID;
      const paypalClientSecret = process.env.PAYPAL_CLIENT_SECRET;
      if (paypalClientId && paypalClientSecret && userEmail) {
        try {
          // Get PayPal access token
          const paypalBaseUrl = getPayPalBaseUrl(paypalClientId);
          const authResponse = await fetch(`${paypalBaseUrl}/v1/oauth2/token`, {
            method: 'POST',
            headers: {
              'Authorization': `Basic ${Buffer.from(`${paypalClientId}:${paypalClientSecret}`).toString('base64')}`,
              'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: 'grant_type=client_credentials'
          });
          
          const authData = await authResponse.json();
          if (authData.access_token) {
            // Search for transactions by email (PayPal Reporting API)
            const startDate = new Date();
            startDate.setFullYear(startDate.getFullYear() - 2);
            const endDate = new Date();
            
            const transactionsResponse = await fetch(
              `${paypalBaseUrl}/v1/reporting/transactions?start_date=${startDate.toISOString()}&end_date=${endDate.toISOString()}&fields=all`,
              {
                headers: {
                  'Authorization': `Bearer ${authData.access_token}`,
                  'Content-Type': 'application/json'
                }
              }
            );
            
            const transactionsData = await transactionsResponse.json();
            if (transactionsData.transaction_details) {
              for (const txn of transactionsData.transaction_details) {
                const info = txn.transaction_info || {};
                const payerEmail = txn.payer_info?.email_address;
                
                // Only include if payer email matches
                if (payerEmail && payerEmail.toLowerCase() === userEmail.toLowerCase()) {
                  if (!invoices.find(i => i.externalId === info.transaction_id)) {
                    invoices.push({
                      id: `paypal_${info.transaction_id}`,
                      amount: parseFloat(info.transaction_amount?.value || 0),
                      currency: info.transaction_amount?.currency_code || 'USD',
                      status: info.transaction_status === 'S' ? 'paid' : info.transaction_status,
                      provider: 'paypal',
                      description: info.transaction_subject || 'PayPal payment',
                      createdAt: info.transaction_initiation_date || new Date().toISOString(),
                      paidAt: info.transaction_updated_date,
                      externalId: info.transaction_id,
                    });
                  }
                }
              }
            }
          }
        } catch (paypalError) {
          console.error('Error fetching PayPal invoices:', paypalError);
        }
      }
      
      // Try to fetch from Paystack if configured
      const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY;
      if (paystackSecretKey && userEmail) {
        try {
          // First find customer by email
          const customerResponse = await fetch(
            `https://api.paystack.co/customer/${encodeURIComponent(userEmail)}`,
            {
              headers: { 'Authorization': `Bearer ${paystackSecretKey}` }
            }
          );
          const customerData = await customerResponse.json();
          
          if (customerData.status && customerData.data) {
            const customerCode = customerData.data.customer_code;
            
            // Fetch transactions for this customer
            const transactionsResponse = await fetch(
              `https://api.paystack.co/transaction?customer=${customerCode}&perPage=100`,
              {
                headers: { 'Authorization': `Bearer ${paystackSecretKey}` }
              }
            );
            const transactionsData = await transactionsResponse.json();
            
            if (transactionsData.status && transactionsData.data) {
              for (const txn of transactionsData.data) {
                if (!invoices.find(i => i.externalId === txn.reference)) {
                  invoices.push({
                    id: `paystack_${txn.id}`,
                    amount: txn.amount / 100,
                    currency: txn.currency || 'NGN',
                    status: txn.status === 'success' ? 'paid' : txn.status,
                    provider: 'paystack',
                    description: txn.metadata?.description || 'Paystack payment',
                    createdAt: txn.created_at || new Date().toISOString(),
                    paidAt: txn.paid_at,
                    externalId: txn.reference,
                    tier: txn.metadata?.tier,
                  });
                }
              }
            }
          }
        } catch (paystackError) {
          console.error('Error fetching Paystack invoices:', paystackError);
        }
      }
      
      // Sort by date descending
      invoices.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
      
      res.json({ success: true, invoices });
      
    } catch (error) {
      console.error('Get invoices error:', error);
      res.status(500).json({ error: error.message });
    }
  });

/**
 * Record Invoice After Payment
 * Called by webhook or after successful payment verification
 */
exports.recordInvoice = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const { 
        userId, 
        amount, 
        currency, 
        provider, 
        subscriptionId, 
        externalId, 
        tier,
        description,
        receiptUrl
      } = req.body;
      
      const invoiceRef = db.collection('invoices').doc();
      await invoiceRef.set({
        id: invoiceRef.id,
        userId: userId || decodedToken.uid,
        amount,
        currency: currency || 'USD',
        status: 'paid',
        provider,
        subscriptionId,
        externalId,
        tier,
        description: description || `${tier ? tier.charAt(0).toUpperCase() + tier.slice(1) : ''} Plan Subscription`,
        receiptUrl,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      res.json({ success: true, invoiceId: invoiceRef.id });
      
    } catch (error) {
      console.error('Record invoice error:', error);
      res.status(500).json({ error: error.message });
    }
  });

// ============================================================================
// SUBSCRIPTION MANAGEMENT
// ============================================================================

/**
 * Cancel Subscription
 */
exports.cancelSubscription = functions
  .runWith({
    secrets: ['STRIPE_SECRET_KEY', 'PAYPAL_CLIENT_ID', 'PAYPAL_CLIENT_SECRET', 'PAYSTACK_SECRET_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onRequest(async (req, res) => {
    setCorsHeaders(req, res);
    
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }
    
    try {
      const decodedToken = await verifyAuthToken(req);
      if (!decodedToken) {
        res.status(401).json({ error: 'Unauthorized' });
        return;
      }
      
      const { subscriptionId } = req.body;
      
      // Get subscription
      const subscriptionDoc = await db.collection('subscriptions').doc(subscriptionId).get();
      if (!subscriptionDoc.exists) {
        res.status(404).json({ error: 'Subscription not found' });
        return;
      }
      
      const subscription = subscriptionDoc.data();
      
      // Verify ownership
      if (subscription.userId !== decodedToken.uid) {
        res.status(403).json({ error: 'Not authorized to cancel this subscription' });
        return;
      }
      
      // Update subscription status to cancelled
      await db.collection('subscriptions').doc(subscriptionId).update({
        status: 'cancelled',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      res.json({ success: true, message: 'Subscription cancelled successfully' });
      
    } catch (error) {
      console.error('Cancel subscription error:', error);
      res.status(500).json({ error: error.message });
    }
  });

// ============================================================================
// TWO-FACTOR AUTHENTICATION (Email OTP via Resend)
// ============================================================================

/**
 * Send a 2FA one-time passcode to the user's email via Resend.
 *
 * Setup:
 *   firebase functions:secrets:set RESEND_API_KEY
 *
 * The function:
 *  1. Generates a 6-digit OTP and stores it in Firestore (collection: twoFactorCodes)
 *  2. Sends the OTP as a branded HTML email from noreply@nduproject.tech via Resend
 *  3. Records a security audit log entry
 *
 * Called from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendTwoFactorCode')
 */
exports.sendTwoFactorCode = functions
  .runWith({
    secrets: ['RESEND_API_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    const { email } = data;
    console.log(`[sendTwoFactorCode] Request for email: ${email}`);

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      console.error(`[sendTwoFactorCode] Invalid email: ${email}`);
      throw new functions.https.HttpsError('invalid-argument', 'A valid email is required.');
    }

    const emailLower = email.toLowerCase().trim();
    await checkRateLimit(emailLower, 'sendTwoFactorCode', 5);

    const resend = getResendClient();
    const otp = generateOtp();
    const expiresAt = new Date(Date.now() + OTP_TTL_MS);

    console.log(`[sendTwoFactorCode] OTP generated (len=${otp.length}) for ${emailLower}, expires at ${expiresAt.toISOString()}`);

    // Store OTP in Firestore — keyed by email for unauthenticated access
    const docRef = db.collection(OTP_COLLECTION).doc(emailLower);
    await docRef.set({
      code: otp,
      email: emailLower,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt,
      used: false,
    });
    console.log(`[sendTwoFactorCode] OTP stored in Firestore for ${emailLower}`);

    // Build branded HTML email
    const htmlBody = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f4f5f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f5f7;padding:40px 0;">
    <tr><td align="center">
      <table width="480" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <tr><td style="background:#051424;padding:28px 36px;text-align:center;">
          <div style="font-size:22px;font-weight:800;color:#fff;letter-spacing:1px;">NDU <span style="color:#f8bd2a;">PROJECT</span></div>
          <div style="font-size:10px;color:#909096;letter-spacing:3px;margin-top:4px;">NAVIGATE. DELIVER. UPGRADE.</div>
        </td></tr>
        <tr><td style="padding:36px 40px;text-align:center;">
          <h1 style="font-size:20px;font-weight:700;color:#1a1d1f;margin:0 0 12px;">Your Verification Code</h1>
          <p style="font-size:14px;color:#6b7280;margin:0 0 28px;">Use the code below to complete sign-in. It expires in 10 minutes.</p>
          <div style="background:#f0f4ff;border-radius:12px;padding:20px 0;margin:0 0 28px;">
            <span style="font-size:36px;font-weight:800;color:#1a1d1f;letter-spacing:8px;">${otp}</span>
          </div>
          <p style="font-size:12px;color:#9ca3af;margin:0 0 24px;">If you did not request this code, you can safely ignore this email.</p>
          <div style="border-top:1px solid #e4e7ec;padding-top:20px;">
            <p style="font-size:11px;color:#9ca3af;margin:0;">&copy; 2026 NDU Project. All rights reserved.</p>
          </div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;

    // Send via Resend
    const { data: emailResult, error } = await resend.emails.send({
      from: RESEND_FROM_EMAIL,
      to: email,
      subject: 'Your NDU Project Verification Code',
      html: htmlBody,
    });

    if (error) {
      console.error('Resend sendTwoFactorCode error:', error);
      throw new functions.https.HttpsError('internal', 'Failed to send verification email.');
    }

    await logSecurityEvent('2fa_code_sent', emailLower, { email, messageId: emailResult?.id });

    console.log(`2FA code sent to ${email}`);
    return { success: true, message: 'Verification code sent.' };
  });

/**
 * Verify a 2FA one-time passcode.
 *
 * Returns { success: true } if the code is valid.
 * Returns { success: false, message: '...' } on failure.
 * After MAX_OTP_ATTEMPTS failures the OTP document is deleted.
 */
exports.verifyTwoFactorCode = functions
  .runWith({
    timeoutSeconds: 15,
    memory: '128MB'
  })
  .https.onCall(async (data, context) => {
    const { code, email } = data;
    console.log(`[verifyTwoFactorCode] Received request for email: ${email}`);

    if (!code || typeof code !== 'string' || code.length !== OTP_LENGTH) {
      console.error(`[verifyTwoFactorCode] Invalid code format: type=${typeof code}, len=${code?.length}`);
      throw new functions.https.HttpsError('invalid-argument', 'A 6-digit code is required.');
    }
    if (!email || typeof email !== 'string' || !email.includes('@')) {
      console.error(`[verifyTwoFactorCode] Invalid email: ${email}`);
      throw new functions.https.HttpsError('invalid-argument', 'Email is required.');
    }

    const emailLower = email.toLowerCase().trim();
    const docRef = db.collection(OTP_COLLECTION).doc(emailLower);
    const doc = await docRef.get();

    console.log(`[verifyTwoFactorCode] Document exists: ${doc.exists}`);

    if (!doc.exists) {
      console.log(`[verifyTwoFactorCode] No OTP document found for ${emailLower}`);
      return { success: false, message: 'No verification code found. Please request a new one.' };
    }

    const record = doc.data();
    console.log(`[verifyTwoFactorCode] Stored code length: ${record.code?.length}, attempts: ${record.attempts}, used: ${record.used}`);

    // Check expiry
    if (record.expiresAt && record.expiresAt.toDate() < new Date()) {
      console.log(`[verifyTwoFactorCode] Code expired at ${record.expiresAt.toDate().toISOString()}`);
      await docRef.delete();
      return { success: false, message: 'Code expired. Please request a new one.' };
    }

    // Check if already used
    if (record.used) {
      console.log(`[verifyTwoFactorCode] Code already used`);
      await docRef.delete();
      return { success: false, message: 'Code already used. Please request a new one.' };
    }

    // Check attempts
    if (record.attempts >= MAX_OTP_ATTEMPTS) {
      console.log(`[verifyTwoFactorCode] Too many attempts: ${record.attempts}`);
      await docRef.delete();
      return { success: false, message: 'Too many failed attempts. Please request a new code.' };
    }

    // Increment attempts
    await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });

    // Verify
    if (record.code !== code) {
      const newAttempts = (record.attempts || 0) + 1;
      const remaining = MAX_OTP_ATTEMPTS - newAttempts;
      console.log(`[verifyTwoFactorCode] Code mismatch. remaining=${remaining}`);
      if (remaining <= 0) {
        await docRef.delete();
      }
      await logSecurityEvent('2fa_code_failed', emailLower, { email: record.email }).catch(() => {});
      return { success: false, message: remaining > 0
        ? `Invalid code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.`
        : 'Too many failed attempts. Please request a new code.' };
    }

    console.log(`[verifyTwoFactorCode] Code verified successfully for ${record.email}`);
    await docRef.update({ used: true });
    await logSecurityEvent('2fa_code_verified', emailLower, { email: record.email }).catch(() => {});

    return { success: true, message: 'Code verified.' };
  });

// ============================================================================
// TEAM INVITATION EMAIL (via Resend)
// ============================================================================

/**
 * Send Team Invitation Email via Resend from noreply@nduproject.tech.
 *
 * Setup:
 *   firebase functions:secrets:set RESEND_API_KEY
 *
 * Called from Flutter:
 *   FirebaseFunctions.instance.httpsCallable('sendTeamInvitation')
 */
exports.sendTeamInvitation = functions
  .runWith({
    secrets: ['RESEND_API_KEY'],
    timeoutSeconds: 30,
    memory: '256MB'
  })
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'You must be signed in to send invitations.');
    }

    const { email, inviterName, projectName, inviteLink } = data;

    if (!email || typeof email !== 'string' || !email.includes('@')) {
      throw new functions.https.HttpsError('invalid-argument', 'A valid email address is required.');
    }

    const inviter = inviterName || context.auth.token.name || context.auth.token.email || 'A team member';
    const project = projectName || 'NDU Project';
    const signInLink = inviteLink || 'https://nduproject.com/#/sign-in';

    // Rate limit
    await checkRateLimit(context.auth.uid, 'invitation', 20);

    const resend = getResendClient();

    const htmlBody = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f4f5f7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f4f5f7;padding:40px 0;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <tr><td style="background:#051424;padding:32px 40px;text-align:center;">
          <div style="font-size:24px;font-weight:800;color:#fff;letter-spacing:1px;">NDU <span style="color:#f8bd2a;">PROJECT</span></div>
          <div style="font-size:11px;color:#909096;letter-spacing:3px;margin-top:4px;">NAVIGATE. DELIVER. UPGRADE.</div>
        </td></tr>
        <tr><td style="padding:40px;">
          <h1 style="font-size:22px;font-weight:700;color:#1a1d1f;margin:0 0 16px;">You're invited to join ${project}</h1>
          <p style="font-size:15px;color:#495057;line-height:1.6;margin:0 0 24px;"><strong>${inviter}</strong> has invited you to collaborate on <strong>${project}</strong> using NDU Project — the project delivery operating system.</p>
          <p style="font-size:14px;color:#6b7280;line-height:1.6;margin:0 0 32px;">Click the button below to accept the invitation and sign in. If you don't have an account yet, you'll be able to create one.</p>
          <table cellpadding="0" cellspacing="0" style="margin:0 auto 32px;"><tr>
            <td style="background:#ffc107;border-radius:12px;">
              <a href="${signInLink}" style="display:inline-block;padding:14px 36px;font-size:15px;font-weight:700;color:#1a1d1f;text-decoration:none;">Accept Invitation &rarr;</a>
            </td>
          </tr></table>
          <p style="font-size:13px;color:#9ca3af;line-height:1.5;margin:0 0 8px;">Or copy this link into your browser:</p>
          <p style="font-size:13px;color:#6366f1;word-break:break-all;margin:0 0 32px;">${signInLink}</p>
          <div style="border-top:1px solid #e4e7ec;padding-top:24px;">
            <p style="font-size:12px;color:#9ca3af;margin:0;">This invitation was sent by ${inviter} via NDU Project. If you weren't expecting this, you can safely ignore this email.</p>
          </div>
        </td></tr>
      </table>
      <p style="font-size:11px;color:#9ca3af;margin:24px 0 0;">&copy; 2026 NDU Project. All rights reserved.</p>
    </td></tr>
  </table>
</body>
</html>`;

    try {
      const { data: emailResult, error } = await resend.emails.send({
        from: RESEND_FROM_EMAIL,
        to: email,
        subject: `You're invited to join ${project} on NDU Project`,
        html: htmlBody,
        text: `${inviter} has invited you to join ${project} on NDU Project. Visit ${signInLink} to accept the invitation.`,
      });

      if (error) {
        console.error('Resend invitation error:', error);
        throw new functions.https.HttpsError('internal', `Failed to send invitation email: ${error.message}`);
      }

      console.log(`Invitation email accepted by Resend for ${email}: ${emailResult?.id}`);

      // Store invitation record in Firestore for tracking.
      // Status is 'accepted' (not 'sent') because Resend has only accepted
      // the email for delivery — actual delivery is confirmed via webhook
      // (handleResendWebhook). The status will be updated to 'delivered',
      // 'bounced', 'complained', or 'failed' by the webhook handler.
      const inviteRef = db.collection('teamInvitations').doc();
      await inviteRef.set({
        id: inviteRef.id,
        email: email.toLowerCase().trim(),
        inviterUid: context.auth.uid,
        inviterName: inviter,
        projectName: project,
        signInLink: signInLink,
        status: 'accepted',
        deliveryStatus: 'pending',
        messageId: emailResult?.id || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      });

      await logSecurityEvent('team_invitation_sent', context.auth.uid, { inviteeEmail: email });

      return { success: true, message: `Invitation sent to ${email}`, messageId: emailResult?.id };

    } catch (error) {
      console.error('Team invitation error:', error);
      if (error instanceof functions.https.HttpsError) throw error;
      throw new functions.https.HttpsError('internal', `Failed to send invitation: ${error.message}`);
    }
  });

// ============================================================================
// SECURITY UTILITIES (shared across all Cloud Functions)
// ============================================================================

/**
 * #2: Rate Limiting — check per-user request count
 * @param {string} uid - User ID
 * @param {string} action - Action name (e.g. 'ai_request', 'invitation')
 * @param {number} maxPerHour - Maximum requests per hour
 * @throws {HttpsError} if rate limit exceeded
 */
async function checkRateLimit(uid, action, maxPerHour) {
  const now = Date.now();
  const hourAgo = now - (60 * 60 * 1000);
  const ref = db.collection('rateLimits').doc(uid).collection(action);
  const recent = await ref.where('timestamp', '>', new Date(hourAgo)).count().get();
  if (recent.data().count >= maxPerHour) {
    throw new functions.https.HttpsError('resource-exhausted', 
      `Rate limit exceeded for ${action}. Maximum ${maxPerHour} per hour.`);
  }
  await ref.add({ timestamp: admin.firestore.FieldValue.serverTimestamp() });
}

/**
 * #3: Input Sanitization — strip XSS and limit length
 * @param {string} input - Raw input
 * @param {number} maxLength - Maximum allowed length
 * @returns {string} Sanitized input
 */
function sanitizeInput(input, maxLength = 1000) {
  if (typeof input !== 'string') return '';
  let sanitized = input.substring(0, maxLength);
  // Remove script tags
  sanitized = sanitized.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '');
  // Remove event handlers
  sanitized = sanitized.replace(/\son\w+\s*=\s*"[^"]*"/gi, '');
  sanitized = sanitized.replace(/\son\w+\s*=\s*'[^']*'/gi, '');
  // Remove javascript: URLs
  sanitized = sanitized.replace(/javascript:/gi, '');
  // Remove data: URLs (can be used for XSS)
  sanitized = sanitized.replace(/data:text\/html/gi, '');
  // Remove SQL injection patterns
  sanitized = sanitized.replace(/(\b(UNION|SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)\b.*\b(FROM|INTO|TABLE|DATABASE)\b)/gi, '');
  return sanitized.trim();
}

/**
 * #5: CSRF Protection — validate Origin header
 * @param {Object} req - HTTP request
 * @throws {Error} if origin is invalid
 */
function validateOrigin(req) {
  const allowedOrigins = [
    'https://staging.nduproject.com',
    'https://nduproject.com',
    'https://www.nduproject.com',
    'https://admin.nduproject.com',
    'https://ndu-d3f60.web.app',
    'https://ndu-d3f60.firebaseapp.com',
  ];
  // Allow localhost for development
  const origin = req.headers.origin || req.headers.referer || '';
  if (!origin) {
    // Allow requests without origin (e.g. curl) but they must have auth token
    return;
  }
  const isAllowed = allowedOrigins.some(allowed => origin.startsWith(allowed)) ||
    /^https?:\/\/localhost(:\d+)?$/.test(origin) ||
    /^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin);
  if (!isAllowed) {
    throw new Error(`Invalid origin: ${origin}`);
  }
}

/**
 * #14: WAF Rules — block malicious requests
 * @param {Object} req - HTTP request
 * @throws {Error} if request matches malicious patterns
 */
function checkWAFRules(req) {
  const body = JSON.stringify(req.body || {});
  const query = JSON.stringify(req.query || {});
  const headers = JSON.stringify(req.headers || {});
  const allInput = `${body}${query}${headers}`.toLowerCase();

  // SQL Injection patterns
  const sqlPatterns = [
    /union\s+select/gi,
    /or\s+1\s*=\s*1/gi,
    /and\s+1\s*=\s*1/gi,
    /';\s*drop\s+table/gi,
    /';\s*delete\s+from/gi,
    /';\s*insert\s+into/gi,
    /';\s*update\s+.*\s+set/gi,
    /exec\s*\(/gi,
    /xp_cmdshell/gi,
  ];

  // XSS patterns
  const xssPatterns = [
    /<script[^>]*>/gi,
    /<\/script>/gi,
    /on\w+\s*=\s*"[^"]*"/gi,
    /on\w+\s*=\s*'[^']*'/gi,
    /javascript:/gi,
    /vbscript:/gi,
    /<iframe[^>]*>/gi,
    /<object[^>]*>/gi,
    /<embed[^>]*>/gi,
  ];

  // Path traversal patterns
  const pathPatterns = [
    /\.\.\.\//g,
    /\.\.\\.\.\\/g,
    /%2e%2e%2f/gi,
    /%2e%2e%5c/gi,
  ];

  // Command injection patterns
  const cmdPatterns = [
    /;\s*(cat|ls|rm|wget|curl|bash|sh|nc|python|perl)\s/gi,
    /\|\s*(cat|ls|rm|wget|curl|bash|sh|nc|python|perl)\s/gi,
    /`[^`]*`/g,
  ];

  // Malicious user agents
  const maliciousUserAgents = [
    'sqlmap', 'nikto', 'nmap', 'masscan', 'metasploit',
    'burp', 'owasp zap', 'w3af', 'dirb', 'gobuster',
  ];

  const userAgent = (req.headers['user-agent'] || '').toLowerCase();
  for (const agent of maliciousUserAgents) {
    if (userAgent.includes(agent)) {
      throw new Error(`Blocked: Malicious user agent detected`);
    }
  }

  // Check all patterns
  for (const pattern of [...sqlPatterns, ...xssPatterns, ...pathPatterns, ...cmdPatterns]) {
    if (pattern.test(allInput)) {
      throw new Error(`Blocked: Malicious input detected`);
    }
  }
}

/**
 * #9: Security Audit Logger — log security events to Firestore
 * @param {string} action - Action name
 * @param {string} userId - User ID
 * @param {Object} metadata - Additional data
 */
async function logSecurityEvent(action, userId, metadata = {}) {
  try {
    await db.collection('securityAudit').add({
      action: action,
      userId: userId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userAgent: typeof req !== 'undefined' ? (req.headers['user-agent'] || 'unknown') : 'cloud-function',
      metadata: metadata,
    });
  } catch (e) {
    console.error('[SecurityAudit] Failed to log:', e);
  }
}

// ============================================================================
// RESEND WEBHOOK — Delivery / Bounce / Complaint tracking
// ============================================================================

/**
 * Receive Resend webhook events to update team invitation delivery status.
 *
 * Setup:
 *   1. In Resend dashboard → Settings → Webhooks → Add webhook
 *      URL: https://<region>-<project-id>.cloudfunctions.net/handleResendWebhook
 *      Events: email.sent, email.delivered, email.delivery_delayed,
 *              email.bounced, email.complained, email.opened, email.clicked
 *   2. Copy the webhook signing secret and set it as a Firebase secret:
 *      firebase functions:secrets:set RESEND_WEBHOOK_SECRET
 *
 * This endpoint verifies the webhook signature, matches the email by
 * messageId, and updates the corresponding teamInvitations document.
 */
exports.handleResendWebhook = functions
  .runWith({
    timeoutSeconds: 30,
    memory: '128MB',
  })
  .https.onRequest(async (req, res) => {
    // Webhooks are called by Resend — no CORS needed, but be permissive
    // for any proxy that might sit in front.
    setCorsHeaders(req, res);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method not allowed' });
      return;
    }

    // ── Signature verification ────────────────────────────────────────
    const webhookSecret = process.env.RESEND_WEBHOOK_SECRET;
    if (webhookSecret) {
      try {
        const signature = req.headers['resend-signature'] || '';
        const timestamp = req.headers['resend-timestamp'] || '';
        const body = JSON.stringify(req.body);
        const payload = `${timestamp}.${body}`;
        const expectedSig = crypto
          .createHmac('sha256', webhookSecret)
          .update(payload)
          .digest('hex');
        if (signature !== expectedSig) {
          console.error('[Webhook] Invalid signature — rejecting');
          res.status(401).json({ error: 'Invalid signature' });
          return;
        }
      } catch (e) {
        console.error('[Webhook] Signature check error:', e);
        // Continue anyway — signature verification is best-effort
      }
    } else {
      console.warn('[Webhook] RESEND_WEBHOOK_SECRET not set — skipping signature verification');
    }

    const event = req.body;
    const eventType = event.type; // e.g. 'email.delivered', 'email.bounced'
    const emailData = event.data || {};
    const messageId = emailData.email_id || emailData.messageId || null;

    console.log(`[Webhook] Event: ${eventType}, messageId: ${messageId}`);

    if (!messageId) {
      console.warn('[Webhook] No messageId in event — ignoring');
      res.status(200).json({ received: true });
      return;
    }

    // ── Map Resend event to our delivery status ───────────────────────
    const statusMap = {
      'email.sent': 'sent',
      'email.delivered': 'delivered',
      'email.delivery_delayed': 'delayed',
      'email.bounced': 'bounced',
      'email.complained': 'complained',
      'email.opened': 'opened',
      'email.clicked': 'clicked',
    };
    const deliveryStatus = statusMap[eventType];
    if (!deliveryStatus) {
      console.log(`[Webhook] Unhandled event type: ${eventType}`);
      res.status(200).json({ received: true });
      return;
    }

    // ── Update Firestore ──────────────────────────────────────────────
    try {
      const snapshot = await db.collection('teamInvitations')
        .where('messageId', '==', messageId)
        .limit(1)
        .get();

      if (snapshot.empty) {
        console.warn(`[Webhook] No invitation found for messageId: ${messageId}`);
        res.status(200).json({ received: true });
        return;
      }

      const doc = snapshot.docs[0];
      const updateData = {
        deliveryStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // Promote 'status' from 'accepted' to 'sent' once Resend confirms it was sent
      if (eventType === 'email.sent') {
        updateData.status = 'sent';
      }

      // Mark as delivered
      if (eventType === 'email.delivered') {
        updateData.status = 'delivered';
        updateData.deliveredAt = admin.firestore.FieldValue.serverTimestamp();
      }

      // Mark terminal failures
      if (eventType === 'email.bounced') {
        updateData.status = 'failed';
        updateData.failureReason = emailData.reason || 'bounced';
      }
      if (eventType === 'email.complained') {
        updateData.status = 'complained';
      }

      await doc.ref.update(updateData);
      console.log(`[Webhook] Updated invitation ${doc.id}: deliveryStatus=${deliveryStatus}`);

      // Security audit
      await logSecurityEvent('invitation_webhook', doc.data().inviterUid || 'system', {
        invitationId: doc.id,
        eventType,
        deliveryStatus,
        messageId,
      }).catch(() => {});
    } catch (e) {
      console.error('[Webhook] Firestore update error:', e);
    }

    res.status(200).json({ received: true });
  });

// Export security utilities for use in other functions
module.exports.security = {
  checkRateLimit,
  sanitizeInput,
  validateOrigin,
  checkWAFRules,
  logSecurityEvent,
};
