// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Gabriel Ángel Montoya Rico

import 'package:lockspire/shared/platform_capabilities.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/file_transfer_port.dart';
import '../../infrastructure/file_picker_transfer_adapter.dart';

part 'file_transfer_port_provider.g.dart';

@Riverpod(keepAlive: true)
FileTransferPort fileTransferPort(Ref ref) => FilePickerTransferAdapter(
  isAndroid: ref.watch(platformCapabilitiesProvider).isAndroid,
);
