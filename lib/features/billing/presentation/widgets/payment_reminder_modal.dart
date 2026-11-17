import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/telephony_utils.dart';
import '../../../business_profile/providers/business_profile_provider.dart';
import '../../../clients/models/client.dart';
import '../../../clients/providers/clients_provider.dart';
import '../../../invoices/models/invoice_record.dart';

class PaymentReminderModal extends ConsumerWidget {
  final InvoiceRecord invoice;

  const PaymentReminderModal({super.key, required this.invoice});

  Future<void> _launchExternalAction(
    BuildContext context, {
    required Uri uri,
    required String channelName,
    required String fallbackCopyText,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!context.mounted) return;

    if (launched) {
      Navigator.pop(context);
    } else {
      await Clipboard.setData(ClipboardData(text: fallbackCopyText));
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No $channelName handler available on this device. Details copied to clipboard.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessProfile = ref.watch(businessProfileProvider);
    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == invoice.clientId,
      orElse: () => Client(
        id: invoice.clientId,
        name: invoice.clientName,
        createdAt: '',
      ),
    );

    final sym = invoice.currencySymbol.isNotEmpty
        ? invoice.currencySymbol
        : businessProfile.currencySymbol;
    final dec = invoice.currencyCode.isNotEmpty
        ? invoice.currencyDecimals
        : businessProfile.currencyDecimals;

    final message = buildPaymentReminderMessage(
      invoiceNumber: invoice.invoiceNumber,
      clientName: client.name.isNotEmpty ? client.name : invoice.clientName,
      balanceDueUnits: invoice.balanceDueCents,
      currencySymbol: sym,
      currencyDecimals: dec,
      dueDate: invoice.dueDate,
      businessName: businessProfile.businessName,
    );

    final smsUri = buildSmsUri(phone: client.phone, body: message);
    final normalizedPhone = normalizePhoneForUri(client.phone);
    final cleanEmail = client.email.trim();
    final subject = 'Invoice ${invoice.invoiceNumber} Payment Reminder';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Send Payment Reminder'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice ${invoice.invoiceNumber} for ${client.name.isNotEmpty ? client.name : "Client"}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (cleanEmail.isNotEmpty || normalizedPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    if (cleanEmail.isNotEmpty) cleanEmail,
                    if (normalizedPhone.isNotEmpty) normalizedPhone,
                  ].join(' • '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.copy),
                title: const Text('Copy Reminder Message'),
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Payment reminder copied to clipboard!')),
                  );
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.message, color: Colors.green),
                title: const Text('Send via WhatsApp'),
                subtitle: Text(
                  normalizedPhone.isNotEmpty
                      ? normalizedPhone
                      : 'Open WhatsApp & choose contact',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _launchExternalAction(
                  context,
                  uri: buildWhatsAppUri(phone: client.phone, message: message),
                  channelName: 'WhatsApp',
                  fallbackCopyText: message,
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  Icons.sms_outlined,
                  color: smsUri != null ? Colors.indigo : Colors.grey,
                ),
                title: const Text('Send SMS'),
                subtitle: Text(
                  smsUri != null ? normalizedPhone : 'No client phone number on file',
                  style: const TextStyle(fontSize: 11),
                ),
                enabled: smsUri != null,
                onTap: smsUri == null
                    ? null
                    : () => _launchExternalAction(
                          context,
                          uri: smsUri,
                          channelName: 'SMS',
                          fallbackCopyText: '$normalizedPhone: $message',
                        ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.email_outlined, color: Colors.blue),
                title: const Text('Send Email'),
                subtitle: Text(
                  cleanEmail.isNotEmpty ? cleanEmail : 'Open default email app',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _launchExternalAction(
                  context,
                  uri: buildMailtoUri(email: cleanEmail, subject: subject, body: message),
                  channelName: 'Email',
                  fallbackCopyText: cleanEmail.isNotEmpty ? '$cleanEmail\n\n$message' : message,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

