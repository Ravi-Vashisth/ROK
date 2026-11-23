import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:billing_app/core/theme/app_theme.dart';
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
  String? _statusMessage;
  bool _statusIsWarning = false;

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

  Future<bool> _tryLaunchExternalUri(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _launchExternalAction(
    BuildContext context, {
    required Uri uri,
    Uri? fallbackUri,
    required String channelName,
    required String fallbackCopyText,
    bool isWhatsApp = false,
    bool isEmptyEmail = false,
    bool copyBeforeFallback = false,
  }) async {
    var launched = await _tryLaunchExternalUri(uri);
    var usedFallback = false;

    if (!launched && copyBeforeFallback && fallbackCopyText.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: fallbackCopyText));
    }

    if (!launched && fallbackUri != null) {
      usedFallback = await _tryLaunchExternalUri(fallbackUri);
      launched = usedFallback;
    }

    if (!context.mounted) return;

    if (launched) {
      setState(() {
        _statusIsWarning = isWhatsApp || isEmptyEmail;
        if (isWhatsApp) {
          _statusMessage =
              'WhatsApp link handed off. Keep this dialog open to copy the reminder if Dual Apps or your browser intercepted it without opening the chat.';
        } else if (isEmptyEmail) {
          _statusMessage = usedFallback
              ? 'Opened generic mail compose & copied subject + reminder to clipboard.'
              : 'No client email saved — opening generic compose or use Copy Everything below.';
        } else {
          _statusMessage = usedFallback
              ? 'Opened $channelName via device fallback.'
              : 'Opened $channelName app.';
        }
      });
    } else {
      await Clipboard.setData(ClipboardData(text: fallbackCopyText));
      if (!context.mounted) return;
      setState(() {
        _statusIsWarning = true;
        _statusMessage = isEmptyEmail
            ? 'No client email or mail handler available — subject & message copied to clipboard.'
            : 'No $channelName handler available on this device. Details copied to clipboard.';
      });
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final warningTone = AppSemanticColors.resolve(brightness, SemanticStatus.warning);
    final infoTone = AppSemanticColors.resolve(brightness, SemanticStatus.info);
    final neutralTone = AppSemanticColors.resolve(brightness, SemanticStatus.neutral);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant;
    final message = _messageController.text;
    final isApple =
        theme.platform == TargetPlatform.iOS || theme.platform == TargetPlatform.macOS;
    final smsUri = buildSmsUri(phone: client.phone, body: message, isIos: isApple);
    final smsFallbackUri = buildSmsFallbackUri(phone: client.phone, body: message);
    final normalizedPhone = normalizePhoneForUri(client.phone);
    final waValidation = validateWhatsAppPhone(client.phone);
    final cleanEmail = client.email.trim();
    final subject = 'Invoice ${widget.invoice.invoiceNumber} Payment Reminder';
    final copyEverythingText = buildCopyEverythingReminderText(
      subject: subject,
      message: message,
      clientName: client.name,
      clientEmail: cleanEmail,
      phone: client.phone,
    );
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
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
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
              if (_statusMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _statusIsWarning ? warningTone.background : infoTone.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _statusIsWarning ? warningTone.border : infoTone.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _statusIsWarning ? Icons.info_outline : Icons.check_circle_outline,
                        size: 16,
                        color: _statusIsWarning ? warningTone.icon : infoTone.icon,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _statusIsWarning ? warningTone.text : infoTone.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.copy),
                title: const Text('Copy Reminder Message'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (!context.mounted) return;
                  setState(() {
                    _statusIsWarning = false;
                    _statusMessage = 'Payment reminder copied to clipboard.';
                  });
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.copy_all_outlined, color: colorScheme.primary),
                title: const Text('Copy Everything (WeChat / Telegram / SMS)'),
                subtitle: Text(
                  'Copies recipient, subject & message for Email or any messenger',
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: copyEverythingText));
                  if (!context.mounted) return;
                  setState(() {
                    _statusIsWarning = false;
                    _statusMessage = 'Recipient, subject & reminder copied for WeChat / Telegram / SMS / Email.';
                  });
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.message, color: successTone.icon),
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
                  isWhatsApp: true,
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
                      Icon(Icons.warning_amber_rounded, size: 15, color: warningTone.icon),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          waValidation.warningMessage!,
                          style: TextStyle(fontSize: 11, color: warningTone.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(
                  Icons.sms_outlined,
                  color: smsUri != null ? colorScheme.primary : neutralTone.icon,
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
                          fallbackUri: smsFallbackUri,
                          channelName: 'SMS',
                          fallbackCopyText: '$normalizedPhone: $message',
                        ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.email_outlined, color: infoTone.icon),
                title: const Text('Send Email'),
                subtitle: Text(
                  cleanEmail.isNotEmpty
                      ? cleanEmail
                      : 'No client email saved — opening generic compose or use Copy Email+Message',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: () => _launchExternalAction(
                  context,
                  uri: buildMailtoUri(email: cleanEmail, subject: subject, body: message),
                  fallbackUri: cleanEmail.isEmpty ? Uri.parse('mailto:') : null,
                  channelName: 'Email',
                  fallbackCopyText: cleanEmail.isNotEmpty
                      ? '$cleanEmail\n$subject\n\n$message'
                      : 'Subject: $subject\n\n$message',
                  isEmptyEmail: cleanEmail.isEmpty,
                  copyBeforeFallback: cleanEmail.isEmpty,
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
                  style: TextStyle(fontSize: 11, color: secondaryTextColor),
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
