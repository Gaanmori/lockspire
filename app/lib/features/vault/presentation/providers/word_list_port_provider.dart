// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Lockspire

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/ports/word_list_port.dart';
import '../../infrastructure/asset_word_list_adapter.dart';

part 'word_list_port_provider.g.dart';

@Riverpod(keepAlive: true)
WordListPort wordListPort(Ref ref) => AssetWordListAdapter();
