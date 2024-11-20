import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_shadow/simple_shadow.dart';
import 'package:sph_plan/home_page.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';
import 'package:sph_plan/utils/cached_network_image.dart';
import 'package:sph_plan/utils/logger.dart';
import 'package:sph_plan/view/login/auth.dart';
import 'package:sph_plan/view/login/screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/database/account_database/account_db.dart';
import 'core/sph/sph.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  LanisException? error;

  // We need to load storage first, so we have to wait before everything.
  ValueNotifier<bool> finishedLoadingStorage = ValueNotifier<bool>(false);

  void openWelcomeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeLoginScreen()),
    );
  }

  void openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: LoginForm(),
        ),
      ),
    );
  }

  Future<void> performLogin() async {
    sph = null;
    final account = await accountDatabase.getLastLoggedInAccount();
    if (account != null) {
      logger.w("SET ACCOUNT: $account");
      sph = SPH(account: account);
    }
    if (sph == null) {
      openWelcomeScreen();
      return;
    }
    await sph?.session.prepareDio();
    try {
      await sph?.session.authenticate();

      if (error == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(showIntro: account!.firstLogin,)),
        );
      }
      return;
    } on WrongCredentialsException {
      openWelcomeScreen();
    } on CredentialsIncompleteException {
      openWelcomeScreen();
    } on LanisException catch (e) {
      error = e;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return errorDialog();
          });
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      finishedLoadingStorage.value = true;
      performLogin();
    });

    super.initState();
  }

  @override
  void dispose() {
    finishedLoadingStorage.dispose();
    super.dispose();
  }

  /// Either school image or app version.
  Widget schoolLogo() {
    var darkMode = Theme.of(context).brightness == Brightness.dark;

    Widget deviceInfo = FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, packageInfo) {
        return Text(
          "lanis-mobile ${packageInfo.data?.version}",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
        );
      },
    );

    return CachedNetworkImage(
      imageType: ImageType.png,
      imageUrl: Uri.parse(
          "https://startcache.schulportal.hessen.de/exporteur.php?a=schoollogo&i=${sph?.account.schoolID}"),
      placeholder: deviceInfo,
      builder: (context, imageProvider) => ColorFiltered(
        colorFilter: darkMode
            ? const ColorFilter.matrix([
                -1,
                0,
                0,
                0,
                255,
                0,
                -1,
                0,
                0,
                255,
                0,
                0,
                -1,
                0,
                255,
                0,
                0,
                0,
                1,
                0
              ])
            : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget appLogo(double horizontal, double vertical) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: LayoutBuilder(builder: (context, constraints) {
        return SimpleShadow(
          color: Theme.of(context).colorScheme.surfaceTint,
          opacity: 0.25,
          sigma: 6,
          offset: const Offset(4, 8),
          child: SvgPicture.asset(
            "assets/startup.svg",
            colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.primary, BlendMode.srcIn),
            fit: BoxFit.contain,
            width: constraints.maxWidth.clamp(0, 300),
            height: constraints.maxHeight.clamp(0, 250),
          ),
        );
      }),
    );
  }

  WidgetSpan toolTipIcon(IconData icon) {
    return WidgetSpan(
        child: Icon(
      icon,
      size: 18,
      color: Theme.of(context).colorScheme.onPrimary,
    ));
  }

  Widget tipText(EdgeInsets padding, EdgeInsets margin, double? width) {
    List<Widget> toolTips = <Widget>[
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage1,
          children: [toolTipIcon(Icons.code)])),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage2,
          children: [toolTipIcon(Icons.people)])),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage3,
          children: [toolTipIcon(Icons.filter_alt)])),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage4,
          children: [toolTipIcon(Icons.star)])),
      Text(AppLocalizations.of(context)!.startUpMessage5),
      Text(AppLocalizations.of(context)!.startUpMessage6),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage7,
          children: [toolTipIcon(Icons.favorite)])),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage8,
          children: [toolTipIcon(Icons.code)])),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage9,
          children: [toolTipIcon(Icons.settings)])),
    ];

    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withAlpha(85),
                blurRadius: 18,
                spreadRadius: 1,
              )
            ],
            borderRadius: BorderRadius.circular(16.0)),
        padding: padding,
        margin: margin,
        width: width,
        child: DefaultTextStyle(
          style: Theme.of(context)
              .textTheme
              .labelLarge!
              .copyWith(color: Theme.of(context).colorScheme.onPrimary),
          textAlign: TextAlign.center,
          child: toolTips.elementAt(Random().nextInt(toolTips.length)),
        ));
  }

  Widget errorDialog() {
    var text = AppLocalizations.of(context)!.startupError;
    if (error is LanisDownException) {
      text = AppLocalizations.of(context)!.lanisDownError;
    } else if (error is NoConnectionException) {
      text = AppLocalizations.of(context)!.noInternetConnection2;
    }
    return AlertDialog(
      icon: error is NoConnectionException
          ? const Icon(Icons.wifi_off)
          : const Icon(Icons.error),
      title: Text(text),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error is! NoConnectionException && error is! LanisDownException)
            Text.rich(TextSpan(
                text: AppLocalizations.of(context)!.startupErrorMessage,
                children: [
                  TextSpan(
                      text: "\n\n${error.runtimeType}: ${error!.cause}",
                      style: Theme.of(context).textTheme.labelLarge)
                ])),
          if (error is LanisDownException)
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: AppLocalizations.of(context)!.lanisDownErrorMessage,
                  style: Theme.of(context).textTheme.labelLarge)
            ])),
        ],
      ),
      actions: [
        if (error is! NoConnectionException &&
            error is! LanisDownException) ...[
          TextButton(
              onPressed: () {
                launchUrl(Uri.parse(
                    "https://github.com/alessioC42/lanis-mobile/issues"));
              },
              child: const Text("GitHub")),
          OutlinedButton(
              onPressed: () {
                launchUrl(Uri.parse("mailto:alessioc42.dev@gmail.com"));
              },
              child: Text(AppLocalizations.of(context)!.startupReportButton)),
        ],
        if (error is LanisDownException) ...[
          OutlinedButton(
              onPressed: () {
                launchUrl(Uri.parse(
                    "https://info.schulportal.hessen.de/status-des-schulportal-hessen/"));
              },
              child: const Text("Status")),
        ],
        FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();

              error = null;
              await performLogin();
            },
            child: Text(AppLocalizations.of(context)!.startupRetryButton)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: MediaQuery.of(context).orientation == Orientation.portrait
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      schoolLogo(),
                      Column(
                        children: [
                          appLogo(80.0, 20.0),
                          tipText(
                              const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 12.0),
                              const EdgeInsets.symmetric(horizontal: 36.0),
                              null)
                        ],
                      ),
                      const LinearProgressIndicator()
                    ],
                  )
                : Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      schoolLogo(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              appLogo(0.0, 0.0),
                              SizedBox.fromSize(
                                size: const Size(48.0, 0.0),
                              ),
                              tipText(
                                  const EdgeInsets.symmetric(
                                      vertical: 16.0, horizontal: 12.0),
                                  const EdgeInsets.only(),
                                  250)
                            ],
                          ),
                        ],
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [LinearProgressIndicator()],
                      )
                    ],
                  )));
  }
}
