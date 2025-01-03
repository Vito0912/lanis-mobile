import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:sph_plan/view/settings/info_button.dart';

import '../../../core/sph/sph.dart';

class UserdataAnsicht extends StatefulWidget {
  const UserdataAnsicht({super.key});

  @override
  State<StatefulWidget> createState() => _UserdataAnsichtState();
}

class _UserdataAnsichtState extends State<UserdataAnsicht> {
  double padding = 10.0;

  List<ListTile> userDataListTiles = [];

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  void loadUserData() {
    setState(() {
      userDataListTiles.clear();
      (sph!.session.userData).forEach((key, value) {
        userDataListTiles.add(ListTile(
          title: Text(value),
          subtitle: Text(toBeginningOfSentenceCase(key)!),
        ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.userData),
        actions: [
          InfoButton(
              infoText: AppLocalizations.of(context)!.settingsInfoUserData,
              context: context)
        ],
      ),
      body: ListView(
        children: userDataListTiles,
      ),
    );
  }
}
