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

    final message = site.trim().isEmpty
        ? 'Namaste $name, PlottingBazaar CRM se aapke enquiry ke baare mein follow-up kar rahe hain.'
        : 'Namaste $name, PlottingBazaar CRM se $site ke baare mein follow-up kar rahe hain.';
    final url = Uri.https('wa.me', '/$number', {'text': message});

    return launchUrl(url, mode: LaunchMode.externalApplication);
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
