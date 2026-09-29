// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/autofill_host_port.dart';
import '../../infrastructure/method_channel_autofill_host.dart';

part 'autofill_host_port_provider.g.dart';

@Riverpod(keepAlive: true)
AutofillHostPort autofillHostPort(Ref ref) => const MethodChannelAutofillHost();
