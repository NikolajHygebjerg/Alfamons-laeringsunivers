/// Danske brugerbeskeder for ukendte auth-fejl (fx DNS/netværk), så vi ikke viser
/// rå `ClientException`/`SocketException`-stakke i UI.
String authUnknownErrorMessage(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  final connectivity = lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('no address associated with hostname') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('connection reset by peer') ||
      lower.contains('broken pipe') ||
      lower.contains('connection timed out') ||
      lower.contains('clientexception with socketexception') ||
      lower.contains('software caused connection abort');

  final tls = lower.contains('handshakeexception') ||
      lower.contains('certificate_verify_failed');

  if (connectivity) {
    return 'Kunne ikke forbinde til Alfamon. Tjek din internetforbindelse '
        'og prøv igen om lidt. Virker det stadig ikke, kan der være '
        'midlertidige driftsproblemer.';
  }

  if (tls) {
    return 'Sikker forbindelse til serveren mislykkedes. Tjek at dato og tid '
        'på enheden er korrekte, og prøv evt. et andet netværk.';
  }

  return raw;
}
