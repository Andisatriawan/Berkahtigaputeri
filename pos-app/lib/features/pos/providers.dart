// lib/features/pos/providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'checkout/payment_service.dart';

/// Riverpod wiring for POS checkout.
final paymentServiceProvider =
    Provider.family<PaymentService, SaleRepository>(
  (ref, repository) => PaymentService(repository: repository),
);
