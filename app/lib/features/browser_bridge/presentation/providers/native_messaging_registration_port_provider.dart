// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/native_messaging_registration_port.dart';
import '../../infrastructure/native_messaging_registration_adapter.dart';

part 'native_messaging_registration_port_provider.g.dart';

@Riverpod(keepAlive: true)
NativeMessagingRegistrationPort nativeMessagingRegistrationPort(Ref ref) =>
    NativeMessagingRegistrationAdapter();
