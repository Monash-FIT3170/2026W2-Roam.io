import 'package:flutter/material.dart';

import '../data/party_service.dart';

Future<String?> showPartyNameDialog(
  BuildContext context, {
  String initialName = '',
  required bool creating,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _PartyNameDialog(initialName: initialName, creating: creating),
  );
}

class _PartyNameDialog extends StatefulWidget {
  const _PartyNameDialog({required this.initialName, required this.creating});

  final String initialName;
  final bool creating;

  @override
  State<_PartyNameDialog> createState() => _PartyNameDialogState();
}

class _PartyNameDialogState extends State<_PartyNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty || name.length > PartyService.maxNameLength) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    final canSubmit =
        name.isNotEmpty && name.length <= PartyService.maxNameLength;
    return AlertDialog(
      title: Text(widget.creating ? 'Name your party' : 'Edit party name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PartyService.maxNameLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Party name',
          hintText: 'Enter a name for your party',
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: canSubmit ? _submit : null,
          style: widget.creating
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                )
              : null,
          child: Text(widget.creating ? 'Create Party' : 'Save'),
        ),
      ],
    );
  }
}
