import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/money_utils.dart';
import '../../../business_profile/providers/business_profile_provider.dart';
import '../../../invoices/models/invoice_record.dart';

class PaymentReminderModal extends ConsumerWidget {
  final InvoiceRecord invoice;

  const PaymentReminderModal({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessProfile = ref.watch(businessProfileProvider);
    final sym = invoice.currencySymbol.isNotEmpty ? invoice.currencySymbol : businessProfile.currencySymbol;
    final dec = invoice.currencyCode.isNotEmpty ? invoice.currencyDecimals : businessProfile.currencyDecimals;
    final formattedAmount = formatMoney(invoice.balanceDueCents, symbol: sym, decimals: dec);
    final clientName = invoice.clientName.trim().isNotEmpty ? invoice.clientName.trim() : 'Client';
    final businessName = businessProfile.businessName.trim().isNotEmpty ? businessProfile.businessName.trim() : 'Accounts Team';
    final dueDate = invoice.dueDate.isNotEmpty ? invoice.dueDate : 'recently';

    final message = "Hi $clientName, hope you're doing well! This is a polite note that Invoice ${invoice.invoiceNumber} for $formattedAmount was due on $dueDate. Please let us know if you need any assistance with remittance. Thank you! - $businessName";

    return AlertDialog(
      title: const Text('Send Payment Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invoice ${invoice.invoiceNumber} for $clientName', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Reminder Message'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment reminder copied to clipboard!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Send via WhatsApp'),
            onTap: () async {
              final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
              if (await canLaunchUrl(url)) await launchUrl(url);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Send Email'),
            onTap: () async {
              final url = Uri.parse('mailto:?subject=Invoice ${invoice.invoiceNumber} Payment Reminder&body=${Uri.encodeComponent(message)}');
              if (await canLaunchUrl(url)) await launchUrl(url);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
