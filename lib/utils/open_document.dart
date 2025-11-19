import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/home/state/home_state.dart';

Future<void> openDocument(BuildContext context, DocumentItem doc) async {
  if (doc.isPdf) {
    GoRouter.of(context).push('/documents/view', extra: doc);
    return;
  }
  final target = doc.fileUrl ?? doc.path;
  if (target == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not available yet')),
      );
    }
    return;
  }

  if (target.startsWith('http')) {
    final uri = Uri.parse(target);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document link')),
      );
    }
    return;
  }

  final result = await OpenFilex.open(target);
  if (result.type != ResultType.done && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open file: ${result.message}')),
    );
  }
}
