import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConsentService {
  static const _keyConsentStore = 'consent_store_enabled';
  static const _keyConsentMic = 'consent_mic_enabled';
  static const _keyConsentLocation = 'consent_location_enabled';
  static const _keyConsentFollowUp = 'consent_followup_enabled';
  static const _keyAnonymousMode = 'consent_anonymous_mode';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<bool> isStoreAllowed() async => (await _secure.read(key: _keyConsentStore)) == '1';
  Future<bool> isMicAllowed() async => (await _secure.read(key: _keyConsentMic)) == '1';
  Future<bool> isLocationAllowed() async => (await _secure.read(key: _keyConsentLocation)) == '1';
  Future<bool> isFollowUpAllowed() async => (await _secure.read(key: _keyConsentFollowUp)) == '1';
  Future<bool> isAnonymousMode() async => (await _secure.read(key: _keyAnonymousMode)) == '1';

  Future<void> setStoreAllowed(bool v) async => _secure.write(key: _keyConsentStore, value: v ? '1' : '0');
  Future<void> setMicAllowed(bool v) async => _secure.write(key: _keyConsentMic, value: v ? '1' : '0');
  Future<void> setLocationAllowed(bool v) async => _secure.write(key: _keyConsentLocation, value: v ? '1' : '0');
  Future<void> setFollowUpAllowed(bool v) async => _secure.write(key: _keyConsentFollowUp, value: v ? '1' : '0');
  Future<void> setAnonymousMode(bool v) async => _secure.write(key: _keyAnonymousMode, value: v ? '1' : '0');

  Future<bool> isFirstRun() async {
    final val = await _secure.read(key: _keyConsentStore);
    return val == null; // no consent stored yet
  }
}
