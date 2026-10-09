import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/state_views.dart';

/// Abre una URL en el navegador externo; avisa si no se pudo.
Future<void> openExternal(BuildContext context, Uri uri) async {
  bool ok;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) showSnack(context, 'No se pudo abrir el enlace.', error: true);
}
