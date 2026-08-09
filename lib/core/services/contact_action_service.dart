import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the user's preferred phone or WhatsApp app without any paid API.
class ContactActionService {
  const ContactActionService._();

  static Future<bool> call(String phone) async {
    final number = _phoneForTel(phone);
    if (number.isEmpty) return false;

    return launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<bool> openWhatsApp({
    required String phone,
    required String name,
    required String site,
  }) async {
    final number = _phoneForWhatsApp(phone);
    if (number.isEmpty) return false;

    final url = Uri.https('wa.me', '/$number', {'text': welcomeMessage(name)});

    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Welcome template sent to new/existing leads on WhatsApp. Kept as two
  /// full, separate messages (Hindi first, then English) rather than
  /// merged/mixed together, per the client's requirement.
  static String welcomeMessage(String name) {
    final hindi =
        'राधे राधे $name जी, PlottingBazaar.com परिवार में आपका स्वागत है! 🙏\n'
        'हम आपके सपनों का घर या बेहतरीन इन्वेस्टमेंट के लिए सही ज़मीन ढूंढने में आपकी मदद करने के लिए बेहद उत्सुक हैं। चाहे आपको शांत आवासीय जगह चाहिए या हाई-रिटर्न प्लॉट, हमारे पास आपके लिए सब कुछ है।\n'
        'आज हम आपकी किस तरह मदद कर सकते हैं? अपनी पसंद हमें बताएं, और हमारी टीम तुरंत बेहतरीन ऑप्शंस आपके साथ शेयर करेगी! ✨';
    final english =
        'Radhe Radhe $name ji, welcome to the PlottingBazaar.com family! 🙏\n'
        "We're excited to help you find the perfect land for your dream home or a great investment. Whether you're looking for a peaceful residential plot or a high-return investment opportunity, we have it all for you.\n"
        'How can we help you today? Share your preference with us, and our team will get back to you right away with the best options! ✨';
    return '$hindi\n\n$english';
  }

  /// Shares one or more picked files (image/video/audio/document) through
  /// the device's native share sheet, so the user can pick WhatsApp and
  /// attach real media -- something a plain wa.me link cannot do for free.
  /// The recipient still has to be picked manually inside WhatsApp; that
  /// last step is an OS/WhatsApp restriction with no free workaround.
  static Future<bool> shareFiles({
    required List<XFile> files,
    String? caption,
  }) async {
    if (files.isEmpty) return false;
    final result = await Share.shareXFiles(files, text: caption);
    return result.status == ShareResultStatus.success ||
        result.status == ShareResultStatus.unavailable;
  }

  static String _phoneForTel(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  static String _phoneForWhatsApp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    return digits;
  }
}
