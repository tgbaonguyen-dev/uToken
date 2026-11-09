part of 'figma_pixel_screen.dart';

extension _ExtraMockActions on _FigmaPixelScreenState {
  Future<String?> _pickExtraOption(
      String title, List<String> options, String selected) {
    return showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              ListTile(
                  title: Text(title),
                  subtitle:
                      const Text('Mock configuration / this session only')),
              for (final option in options)
                ListTile(
                    title: Text(option),
                    trailing:
                        option == selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(sheetContext, option)),
            ])));
  }

  Future<bool> _handleExtraHotspot(String name) async {
    if (!FigmaMockRepository.extraScreenIds.contains(widget.screenId)) {
      return false;
    }
    if (widget.screenId == 'O02' &&
        const ['Back', 'Dismiss alert'].contains(name)) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/budget');
      }
      return true;
    }
    if (widget.screenId == 'O01' &&
        const ['Download CSV', 'Download JSON'].contains(name)) {
      final format = name == 'Download CSV' ? 'CSV' : 'JSON';
      final value = await FigmaMockRepository.exportPreview(format);
      if (!mounted) return true;
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                scrollable: true,
                title: Text('$format preview (mock)'),
                content: SizedBox(
                    width: 420,
                    height: 360,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Sample data only. No file is saved.'),
                          const SizedBox(height: 12),
                          Expanded(
                              child: SingleChildScrollView(
                                  child: SelectableText(value,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11)))),
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close')),
                  FilledButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) _showNotice('Mock $format copied.');
                      },
                      child: Text('Copy mock $format')),
                ],
              ));
      return true;
    }
    if (widget.screenId == 'M14' && name == 'Back to settings') {
      context.go('/settings');
      return true;
    }
    if (widget.screenId != 'M15') return false;
    final data = await FigmaMockRepository.extraData();
    final current = await FigmaMockRepository.settingsData();
    if (!mounted) return true;
    final providers = (data['ai']['providers'] as List).cast<Map>();
    if (providers.any((p) => p['name'] == name)) {
      if (current['aiProvider'] != name) {
        await FigmaMockRepository.selectAiProvider(name);
      }
      return true;
    }
    if (name == 'Edit model') {
      final provider =
          providers.firstWhere((p) => p['name'] == current['aiProvider']);
      final selected = await _pickExtraOption(
          'Model',
          List<String>.from(provider['models'] as List),
          current['aiModel'] as String);
      if (selected != null) {
        await FigmaMockRepository.updateSettings({
          'aiModel': selected,
          'aiConnection': 'Not checked',
          'aiCheckedAt': 'Not checked'
        });
      }
      return true;
    }
    if (name == 'Edit API key') {
      final options = List<String>.from(data['ai']['keyChoices'] as List);
      final selected = await _pickExtraOption('Demo key', options,
          current['aiKeyPresent'] == true ? options[0] : options[1]);
      if (selected != null) {
        await FigmaMockRepository.updateSettings({
          'aiKeyPresent': selected == options[0],
          'aiConnection': 'Not checked',
          'aiCheckedAt': 'Not checked'
        });
      }
      return true;
    }
    if (name == 'Test connection') {
      await FigmaMockRepository.testAiConnection();
      if (mounted) {
        _showNotice(current['aiKeyPresent'] == true
            ? 'Demo connection succeeded. No network request was sent.'
            : 'Demo connection failed: choose a demo key first.');
      }
      return true;
    }
    return false;
  }
}
