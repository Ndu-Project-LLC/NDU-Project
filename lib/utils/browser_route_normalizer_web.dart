import 'package:web/web.dart' as web;

void normalizeBrowserHashRouteImpl() {
  final path = web.window.location.pathname.replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final hash = web.window.location.hash;

  if (path.isEmpty || path == '/') return;
  if (path.contains('.')) return;
  if (hash.isNotEmpty && hash != '#/' && hash != '#/dashboard') return;

  web.window.history.replaceState(null, '', '/#$path');
}
