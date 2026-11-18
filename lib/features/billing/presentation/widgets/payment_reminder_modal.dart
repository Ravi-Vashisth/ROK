import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billing_app/core/utils/telephony_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';

class PaymentReminderModal extends ConsumerStatefulWidget {
  final InvoiceRecord invoice;

  const PaymentReminderModal({super.key, required this.invoice});

  @override
  ConsumerState<PaymentReminderModal> createState() => _PaymentReminderModalState();
}

class _PaymentReminderModalState extends ConsumerState<PaymentReminderModal> {
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    final businessProfile = ref.read(businessProfileProvider);
    final clients = ref.read(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == widget.invoice.clientId,
      orElse: () => Client(
        id: widget.invoice.clientId,
        name: widget.invoice.clientName,
        createdAt: '',
      ),
    );
    final sym = widget.invoice.currencySymbol.isNotEmpty
        ? widget.invoice.currencySymbol
        : businessProfile.currencySymbol;
    final dec = widget.invoice.currencyCode.isNotEmpty
        ? widget.invoice.currencyDecimals
        : businessProfile.currencyDecimals;

    _messageController = TextEditingController(
      text: buildPaymentReminderMessage(
        invoiceNumber: widget.invoice.invoiceNumber,
        clientName: client.name.isNotEmpty ? client.name : widget.invoice.clientName,
        balanceDueUnits: widget.invoice.balanceDueCents,
        currencySymbol: sym,
        currencyDecimals: dec,
        dueDate: widget.invoice.dueDate,
        businessName: businessProfile.businessName,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

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
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == widget.invoice.clientId,
      orElse: () => Client(
        id: widget.invoice.clientId,
        name: widget.invoice.clientName,
        createdAt: '',
      ),
    );

    final message = _messageController.text;
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final smsUri = buildSmsUri(phone: client.phone, body: message, isIos: isIos);
    final normalizedPhone = normalizePhoneForUri(client.phone);
    final waValidation = validateWhatsAppPhone(client.phone);
    final cleanEmail = client.email.trim();
    final subject = 'Invoice ${widget.invoice.invoiceNumber} Payment Reminder';
    final fallbackNote = getDesktopTelephonyFallbackNote(
      hasPhone: normalizedPhone.isNotEmpty,
      hasEmail: cleanEmail.isNotEmpty,
    );

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
                'Invoice ${widget.invoice.invoiceNumber} for ${client.name.isNotEmpty ? client.name : "Client"}',
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
              TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 3,
                style: const TextStyle(fontSize: 12),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Reminder Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
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
              if (normalizedPhone.isNotEmpty &&
                  !waValidation.isValid &&
                  waValidation.warningMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amber.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          waValidation.warningMessage!,
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade800),
                        ),
                      ),
                    ],
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
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  fallbackNote,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
