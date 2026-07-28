import 'browser_route_normalizer_stub.dart'
    if (dart.library.html) 'browser_route_normalizer_web.dart';

void normalizeBrowserHashRoute() => normalizeBrowserHashRouteImpl();
