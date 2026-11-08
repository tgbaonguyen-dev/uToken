part of 'figma_mock_repository.dart';

// shortcut: these bindings follow the current light/dark exports; update on re-export.
FigmaMockScreen _settingsMockScreen(
    FigmaMockScreen original, String id, Map<String, dynamic> data, Map month) {
  final layers =
      original.layers.map((l) => Map<String, dynamic>.from(l)).toList();
  void text(int i, Object value) => layers[i]['v'] = value.toString();
  String money(num n) => '\$${n.toStringAsFixed(2)}';
  String on(String key) => data[key] == true ? 'On' : 'Off';
  switch (id) {
    case 'M09':
      text(
          6,
          data['connected']
              ? 'Connected \u00b7 ${data['lastSync']}'
              : 'Not connected');
      text(10, data['language']);
      text(14, '${money(data['monthlyLimit'] as num)} monthly');
      text(19, data['numberFormat']);
      text(23, data['syncInterval']);
      text(31, data['accountEmail']);
      text(57, '${data['aiProvider']} \u00b7 ${data['aiModel']}');
    case 'M10':
      final connected = data['connected'] as bool;
      text(6, connected ? 'Connected' : 'Disconnected');
      layers[5]['c'] = connected ? '#ff39c995' : '#ff8c929b';
      text(7, '${data['desktopName']} \u00b7 synced ${data['lastSync']}');
      layers[7]['w'] = 318;
      for (var i = 0; i < 3; i++) {
        final total =
            (month['totalTokens'] as num) * (month['shares'][i] as num) / 100;
        text(
            [14, 17, 20][i],
            data['numberFormat'] == 'Full'
                ? NumberFormat.decimalPattern('en_US').format(total.round())
                : '${(total / 1000000).toStringAsFixed(2)}M');
        if (data['numberFormat'] == 'Full') layers[[14, 17, 20][i]]['sz'] = 11;
      }
      text(25, on('backgroundSync'));
      text(33,
          connected ? 'Disconnect this computer' : 'Reconnect demo computer');
      layers[33].addAll({'x': 60, 'w': 270, 'al': 'CENTER'});
    case 'M11':
      final limit = data['monthlyLimit'] as num;
      final spent = month['estimatedCost'] as num;
      final used = spent / limit * 100;
      text(5, data['budgetMonth']);
      text(6, money(spent));
      text(7, 'of ${money(limit)}');
      layers[9]['w'] = 318 * (used / 100).clamp(0, 1);
      text(10, '${used.toStringAsFixed(1)}% used');
      text(11, '${data['budgetDaysLeft']} days left');
      text(
          15,
          used >= 70
              ? (limit == data['thresholdBaselineLimit']
                  ? data['thresholdReachedLabel']
                  : 'Threshold reached')
              : 'Not reached');
      text(16, used >= 70 ? 'Done' : 'Pending');
      text(20, on('alert90'));
      text(24, on('alert100'));
      text(28, money(limit));
    case 'M12':
      text(30, on('diagnostics'));
    case 'M13':
      text(6, (data['accountName'] as String).substring(0, 1));
      text(7, data['accountName']);
      text(8, data['accountEmail']);
      text(13, data['connected'] ? 'Active' : 'Paused');
      text(20, data['connected'] ? '1 computer' : '0 computers');
      text(29, 'Version ${data['appVersion']}');
  }
  return FigmaMockScreen(
      nodeId: original.nodeId,
      name: original.name,
      width: original.width,
      height: original.height,
      layers: layers);
}
