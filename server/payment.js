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
