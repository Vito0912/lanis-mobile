import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sph_plan/applets/definitions.dart';
import 'package:sph_plan/core/database/account_database/account_db.dart';
import 'package:sph_plan/view/settings/info_button.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../core/sph/sph.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.notifications),
        actions: [
          InfoButton(
            infoText: AppLocalizations.of(context)!.settingsInfoNotifications,
            context: context,
          )
        ],
      ),
      body: ListView(
        children: [NotificationElements()],
      ),
    );
  }
}

class NotificationElements extends StatefulWidget {
  const NotificationElements({super.key});

  @override
  State<NotificationElements> createState() => _NotificationElementsState();
}

class _NotificationElementsState extends State<NotificationElements> {
  final Map<String, String> _keyTitles = {};

  double _notificationInterval = 15.0;
  PermissionStatus _notificationPermissionStatus = PermissionStatus.provisional;
  Future<int> accountsCount = accountDatabase.select(accountDatabase.accountsTable).get().then((value) => value.length);
  Timer? _timer;

  List<String> _getNotificationKeys() {
    List<String> result = [];
    for (final applet
    in AppDefinitions.applets.where((a) => a.notificationTask != null)) {
      if (sph!.session.doesSupportFeature(applet)) {
        result.add('notification-${applet.appletPhpUrl}');
        _keyTitles['notification-${applet.appletPhpUrl}'] =
            applet.label(context);
      }
    }
    result.addAll([
      'notifications-allow',
      'notifications-android-target-interval-minutes'
    ]);
    return result;
  }

  void initVars() async {
    _notificationPermissionStatus = await Permission.notification.status;
    final String interval = (await accountDatabase.kv
        .get('notifications-android-target-interval-minutes')) ??
        '15';
    setState(() {
      _notificationPermissionStatus = _notificationPermissionStatus;
      _notificationInterval = double.parse(interval);
    });
  }

  void _startPermissionCheck() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      final newStatus = await Permission.notification.status;
      if (newStatus != _notificationPermissionStatus && mounted) {
        setState(() {
          _notificationPermissionStatus = newStatus;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initVars();
    _startPermissionCheck();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: sph!.prefs.kv.subscribeMultiple(_getNotificationKeys()),
      builder: (BuildContext context, snapshot) {
        if (snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        List<String> sortedKeys = snapshot.data!.keys.toList()..sort();
        sortedKeys.removeWhere((element) => !element.endsWith('.php'));

        final bool allowNotifications =
            (snapshot.data!['notifications-allow'] ?? 'true') == 'true' &&
                _notificationPermissionStatus == PermissionStatus.granted;

        return Column(
          children: [
            ListTile(
              leading: Icon(Icons.perm_device_info),
              title: Text(AppLocalizations.of(context)!
                  .systemPermissionForNotifications),
              subtitle: Text(AppLocalizations.of(context)!
                  .systemPermissionForNotificationsExplained),
              onTap: () => AppSettings.openAppSettings(type: AppSettingsType.notification, asAnotherTask: false),
              trailing:
              (_notificationPermissionStatus == PermissionStatus.granted)
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            ),
            const Divider(),
            FutureBuilder<int>(
              future: accountsCount,
              builder: (context, snapshot){
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data == 1) {
                  return SizedBox.shrink();
                }
                return ListTile(
                  subtitle: Text(AppLocalizations.of(context)!.notificationAccountBoundExplanation),
                  leading: Icon(Icons.info),
                );
              },
            ),
            if (Platform.isAndroid)
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 16.0, right: 24),
                    child: Row(
                      children: [
                        Text('Update interval', style: TextStyle(fontSize: 16),),
                        const Spacer(),
                        Text('${_notificationInterval.round()} min', style: Theme.of(context).textTheme.titleMedium,),
                      ],
                    ),
                  ),
                  Slider(
                    value: _notificationInterval,
                    onChanged: allowNotifications
                        ? (val) {
                      setState(() {
                        _notificationInterval = val;
                      });
                    }
                        : null,
                    onChangeEnd: allowNotifications
                        ? (val) {
                      int value = val.round();
                      accountDatabase.kv.set(
                          'notifications-android-target-interval-minutes',
                          value.toString());
                    }
                        : null,
                    min: 15.0,
                    max: 180.0,
                  ),
                ],
              ),
            const Divider(),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.useNotifications),
              subtitle: Text(AppLocalizations.of(context)!.forThisAccount),
              value:
              (snapshot.data!['notifications-allow'] ?? 'true') == 'true',
              onChanged: allowNotifications ? (value) {
                sph!.prefs.kv.set('notifications-allow', value.toString());
              } : null,
            ),
            ...sortedKeys.map(
                  (key) => SwitchListTile(
                title: Text(_keyTitles[key] ?? key),
                value: (snapshot.data![key] ?? 'true') == 'true',
                onChanged: allowNotifications
                    ? (value) {
                  sph!.prefs.kv.set(key, value.toString());
                }
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}