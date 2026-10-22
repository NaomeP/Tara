export function isCapturedPaymentForOrder(payment, order) {
  return Boolean(
    payment &&
    order &&
    payment.status === 'captured' &&
    payment.order_id === order.orderId &&
    payment.currency === 'INR' &&
    Number.isSafeInteger(Number(payment.amount)) &&
    Number(payment.amount) === Number(order.amountPaise)
  );
}

export function refundStatusFromProvider(status) {
  if (status === 'processed') return 'processed';
  if (status === 'failed') return 'failed';
  if (status === 'pending' || status === 'created') return 'requested';
  return 'unknown';
}
