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

  static String _phoneForTel(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  static String _phoneForWhatsApp(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '91$digits';
    return digits;
  }
}
