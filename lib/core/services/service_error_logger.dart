import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mappa_prezzi_benzina/core/utils/logger.dart';

/// Registra su Firestore i fallimenti dei servizi esterni gratuiti senza
/// dashboard propria (Nominatim, Overpass) — sono l'unico modo per
/// accorgersi se hanno iniziato a bloccarci per troppo traffico, dato che
/// oggi questi errori vengono ingoiati in silenzio per non disturbare
/// l'utente. Al massimo un log per servizio per sessione app, per evitare
/// di intasare Firestore con errori ripetuti dello stesso tipo.
class ServiceErrorLogger {
  static final Set<String> _loggedThisSession = {};

  static Future<void> log(String service, {String? detail}) async {
    if (_loggedThisSession.contains(service)) return;
    _loggedThisSession.add(service);

    try {
      await FirebaseFirestore.instance.collection('service_errors').add({
        'serviceName': service,
        if (detail != null) 'detail': detail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logError('Failed to log service error for $service', e);
    }
  }
}
