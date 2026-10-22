import test from 'node:test';
import assert from 'node:assert/strict';
import { isCapturedPaymentForOrder, refundStatusFromProvider } from './payment.js';

const expected = { orderId: 'order_123', amountPaise: 215000 };
const payment = { status: 'captured', order_id: 'order_123', currency: 'INR', amount: 215000 };

test('accepts a captured payment matching the order, currency, and amount', () => {
  assert.equal(isCapturedPaymentForOrder(payment, expected), true);
});

test('rejects an authorized but uncaptured payment', () => {
  assert.equal(isCapturedPaymentForOrder({ ...payment, status: 'authorized' }, expected), false);
});

test('rejects payments for another order or amount', () => {
  assert.equal(isCapturedPaymentForOrder({ ...payment, order_id: 'order_other' }, expected), false);
  assert.equal(isCapturedPaymentForOrder({ ...payment, amount: 1 }, expected), false);
});

test('rejects non-INR or malformed provider amounts', () => {
  assert.equal(isCapturedPaymentForOrder({ ...payment, currency: 'USD' }, expected), false);
  assert.equal(isCapturedPaymentForOrder({ ...payment, amount: 'NaN' }, expected), false);
});

test('maps Razorpay refund states to safe local refund states', () => {
  assert.equal(refundStatusFromProvider('processed'), 'processed');
  assert.equal(refundStatusFromProvider('failed'), 'failed');
  assert.equal(refundStatusFromProvider('pending'), 'requested');
  assert.equal(refundStatusFromProvider('created'), 'requested');
  assert.equal(refundStatusFromProvider(undefined), 'unknown');
});
