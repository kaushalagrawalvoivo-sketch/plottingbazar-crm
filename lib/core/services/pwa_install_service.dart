import 'dart:js_interop';

@JS('isPwaInstallAvailable')
external JSBoolean _isPwaInstallAvailableJS();

@JS('isPwaInstalled')
external JSBoolean _isPwaInstalledJS();

@JS('isIosSafari')
external JSBoolean _isIosSafariJS();

@JS('promptPwaInstall')
external JSPromise<JSString> _promptPwaInstallJS();

/// Talks to the small install-prompt script in web/index.html so the app
/// can offer its own reliable, always-visible "Install App" button instead
/// of depending on the browser's own (inconsistently-timed) install popup.
class PwaInstallService {
  const PwaInstallService._();

  static bool get canInstall {
    try {
      return _isPwaInstallAvailableJS().toDart && !_isPwaInstalledJS().toDart;
    } catch (_) {
      return false;
    }
  }

  static bool get isInstalled {
    try {
      return _isPwaInstalledJS().toDart;
    } catch (_) {
      return false;
    }
  }

  /// iOS Safari never fires the install prompt event -- it only supports
  /// "Share -> Add to Home Screen", so the UI needs to show instructions
  /// instead of a button there.
  static bool get isIosSafari {
    try {
      return _isIosSafariJS().toDart;
    } catch (_) {
      return false;
    }
  }

  /// Returns 'accepted', 'dismissed', or 'unavailable'.
  static Future<String> promptInstall() async {
    try {
      final outcome = await _promptPwaInstallJS().toDart;
      return outcome.toDart;
    } catch (_) {
      return 'unavailable';
    }
  }
}
