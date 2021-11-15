const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

exports.handler =  async(event, context) => {
  const { session_id } = JSON.parse(event.body);

  const session = await stripe.checkout.sessions.retrieve(session_id);

  console.log(session);
  return {
    statusCode: 200,
    body: JSON.stringify(session)
  }
};
