import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/screens/settings_screen.dart';
import 'package:onelap_strava_sync/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Finder fieldWithLabel(String labelText) {
    return find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == labelText,
      description: 'TextField($labelText)',
    );
  }

  void useLargeTestViewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> enterVisibleText(
    WidgetTester tester,
    String labelText,
    String value,
  ) async {
    final Finder field = fieldWithLabel(labelText);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  Finder buttonWithText(String text) {
    final Finder elevated = find.widgetWithText(ElevatedButton, text);
    if (elevated.evaluate().isNotEmpty) {
      return elevated;
    }

    final Finder outlined = find.widgetWithText(OutlinedButton, text);
    if (outlined.evaluate().isNotEmpty) {
      return outlined;
    }

    return find.text(text);
  }

  Future<void> tapVisibleText(WidgetTester tester, String text) async {
    final Finder target = buttonWithText(text);
    await tester.ensureVisible(target);
    await tester.tap(target, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('preserves entered credentials after successful Strava auth', (
    WidgetTester tester,
  ) async {
    useLargeTestViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          authorizeStrava: (String clientId, String clientSecret) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await enterVisibleText(tester, 'OneLap 用户名', 'rider@example.com');
    await enterVisibleText(tester, 'OneLap 密码', 'onelap-pass');
    await enterVisibleText(tester, 'Strava Client ID', '12345');
    await enterVisibleText(tester, 'Strava Client Secret', 'secret-xyz');

    await tapVisibleText(tester, '授权 Strava');

    final Map<String, String> settings = await SettingsService().loadSettings();
    expect(settings[SettingsService.keyOneLapUsername], 'rider@example.com');
    expect(settings[SettingsService.keyOneLapPassword], 'onelap-pass');
    expect(settings[SettingsService.keyStravaClientId], '12345');
    expect(settings[SettingsService.keyStravaClientSecret], 'secret-xyz');
  });

  testWidgets('save OneLap credentials validates and persists on success', (
    WidgetTester tester,
  ) async {
    useLargeTestViewport(tester);

    FlutterSecureStorage.setMockInitialValues(<String, String>{
      SettingsService.keyStravaClientId: 'stored-client-id',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          validateOneLapLogin: (String username, String password) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await enterVisibleText(tester, 'OneLap 用户名', 'solo-user');
    await enterVisibleText(tester, 'OneLap 密码', 'solo-pass');

    await tapVisibleText(tester, '保存 OneLap 账号');

    final Map<String, String> settings = await SettingsService().loadSettings();
    expect(settings[SettingsService.keyOneLapUsername], 'solo-user');
    expect(settings[SettingsService.keyOneLapPassword], 'solo-pass');
    expect(settings[SettingsService.keyStravaClientId], 'stored-client-id');
  });

  testWidgets('save OneLap credentials also validates current input', (
    WidgetTester tester,
  ) async {
    useLargeTestViewport(tester);

    String? validatedUsername;
    String? validatedPassword;

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          validateOneLapLogin: (String username, String password) async {
            validatedUsername = username;
            validatedPassword = password;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await enterVisibleText(tester, 'OneLap 用户名', 'verify-user');
    await enterVisibleText(tester, 'OneLap 密码', 'verify-pass');

    await tapVisibleText(tester, '保存 OneLap 账号');

    expect(validatedUsername, 'verify-user');
    expect(validatedPassword, 'verify-pass');

    final Map<String, String> settings = await SettingsService().loadSettings();
    expect(settings[SettingsService.keyOneLapUsername], 'verify-user');
    expect(settings[SettingsService.keyOneLapPassword], 'verify-pass');
  });

  testWidgets('failed OneLap validation keeps previously saved credentials', (
    WidgetTester tester,
  ) async {
    useLargeTestViewport(tester);

    FlutterSecureStorage.setMockInitialValues(<String, String>{
      SettingsService.keyOneLapUsername: 'stable-user',
      SettingsService.keyOneLapPassword: 'stable-pass',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          validateOneLapLogin: (String username, String password) async {
            throw Exception('invalid credentials');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await enterVisibleText(tester, 'OneLap 用户名', 'wrong-user');
    await enterVisibleText(tester, 'OneLap 密码', 'wrong-pass');

    await tapVisibleText(tester, '保存 OneLap 账号');

    final Map<String, String> settings = await SettingsService().loadSettings();
    expect(settings[SettingsService.keyOneLapUsername], 'stable-user');
    expect(settings[SettingsService.keyOneLapPassword], 'stable-pass');
  });
}
