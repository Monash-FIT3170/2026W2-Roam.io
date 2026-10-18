import 'package:flutter/material.dart';

import '../../../theme/app_cartoon.dart';
import '../../../theme/app_colours.dart';
import '../../../theme/app_surfaces.dart';
import '../data/party_service.dart';
import 'party_style.dart';

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
    final outline = PartyStyle.outline(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: PartyStyle.outlineWidth),
    );
    return AlertDialog(
      backgroundColor: AppSurfaces.pageBackground(context),
      shape: PartyStyle.dialogShape(context),
      title: Text(
        widget.creating ? 'Name your party' : 'Edit party name',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PartyService.maxNameLength,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: const TextStyle(fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: 'Party name',
          hintText: 'Enter a name for your party',
          filled: true,
          fillColor: AppSurfaces.softCard(context),
          border: border(outline),
          enabledBorder: border(outline),
          focusedBorder: border(AppColors.sage),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppSurfaces.textMuted(context),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
          child: const Text('Cancel'),
        ),
        CartoonPressable(
          soft: true,
          enabled: canSubmit,
          offset: 3,
          child: ElevatedButton(
            onPressed: canSubmit ? _submit : null,
            style: PartyStyle.button(
              context,
              background: AppColors.sage,
              foreground: Colors.white,
              height: 44,
            ),
            child: Text(widget.creating ? 'Create Party' : 'Save'),
          ),
        ),
      ],
    );
  }
}
