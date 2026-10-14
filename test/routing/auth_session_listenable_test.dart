import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ndu_project/routing/auth_session_listenable.dart';

void main() {
  late StreamController<User?> controller;
  late AuthSessionListenable listenable;
  late int notifications;

  setUp(() {
    controller = StreamController<User?>();
    listenable = AuthSessionListenable(controller.stream);
    notifications = 0;
    listenable.addListener(() => notifications++);
  });

  tearDown(() async {
    listenable.dispose();
    await controller.close();
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  test('notifies when a signed-in session ends', () async {
    controller.add(_FakeUser());
    await flush();
    expect(notifications, 0);

    controller.add(null);
    await flush();
    expect(notifications, 1);
  });

  test('does not notify on sign-in or on the initial signed-out state', () async {
    controller.add(null);
    await flush();
    controller.add(_FakeUser());
    await flush();
    expect(notifications, 0);
  });

  test('does not notify again while already signed out', () async {
    controller.add(_FakeUser());
    await flush();
    controller.add(null);
    await flush();
    controller.add(null);
    await flush();
    expect(notifications, 1);
  });
}

class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
