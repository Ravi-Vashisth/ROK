import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../invoices/models/invoice_record.dart';

class PaymentReminderModal extends StatelessWidget {
  final InvoiceRecord invoice;

  const PaymentReminderModal({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final message = "Reminder: Invoice ${invoice.invoiceNumber} for ${invoice.balanceDueCents / 100} is overdue. Please remit payment.";
    
    return AlertDialog(
      title: const Text('Send Payment Reminder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invoice ${invoice.invoiceNumber} for ${invoice.clientName}'),
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
              final url = Uri.parse('mailto:?subject=Overdue Invoice ${invoice.invoiceNumber}&body=${Uri.encodeComponent(message)}');
              if (await canLaunchUrl(url)) await launchUrl(url);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
