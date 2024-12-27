import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sph_plan/utils/large_appbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/sph/sph.dart';
import '../../../utils/logger.dart';

class AvatarTile extends StatelessWidget {
  final String networkImage;
  final String name;
  final String contributions;
  final double avatarSize;
  final EdgeInsets contentPadding;
  final void Function() onTap;
  const AvatarTile({super.key, required this.networkImage, required this.name, required this.contributions, required this.avatarSize, required this.contentPadding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: contentPadding,
            child: Row(
              spacing: 8.0,
              children: [
                CircleAvatar(
                  radius: avatarSize,
                  backgroundImage: NetworkImage(networkImage),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    Text(
                      contributions,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                )
              ],
            ),
          ),
        )
    );
  }
}

class AboutLink {
  final String title;
  final Future<void> Function(BuildContext context) onTap;
  final IconData iconData;

  const AboutLink({required this.title, required this.onTap, required this.iconData});
}

class AboutSettings extends StatefulWidget {
  const AboutSettings({super.key});

  @override
  State<AboutSettings> createState() => _AboutSettingsState();
}

class _AboutSettingsState extends State<AboutSettings> {
  dynamic contributors;
  bool error = false;

  Future<dynamic> getContributors() async {
    setState(() {
      contributors = null;
      error = false;
    });

    try {
      final response = await sph!.session.dio.get('https://api.github.com/repos/lanis-mobile/lanis-mobile/contributors');
      setState(() {
        contributors = response.data;
      });
    } catch (e) {
      logger.e(e);
      setState(() {
        error = true;
      });
    }
  }

  final List<AboutLink> links = [
    AboutLink(
      title: "GitHub Repository",
      iconData: Icons.code_outlined,
      onTap: (context) => launchUrl(Uri.parse("https://github.com/alessioC42/lanis-mobile")),
    ),
    AboutLink(
      title: "Discord Server",
      iconData: Icons.diversity_3_outlined,
      onTap: (context) => launchUrl(Uri.parse("https://discord.gg/sWJXZ8FsU7")),
    ),
    AboutLink(
      title: "Feature request",
      iconData: Icons.add_comment_outlined,
      onTap: (context) => launchUrl(Uri.parse("https://github.com/alessioC42/lanis-mobile/issues/new/choose")),
    ),
    AboutLink(
      title: "Latest release",
      iconData: Icons.update_outlined,
      onTap: (context) => launchUrl(Uri.parse("https://github.com/alessioC42/lanis-mobile/releases/latest")),
    ),
    AboutLink(
      title: "Privacy policy",
      iconData: Icons.security_outlined,
      onTap: (context) => launchUrl(Uri.parse("https://github.com/alessioC42/lanis-mobile/blob/main/SECURITY.md")),
    ),
    AboutLink(
      title: "Open-Source licenses",
      iconData: Icons.info_outline_rounded,
      onTap: (context) async => showLicensePage(context: context),
    ),
    AboutLink(
      title: "Build information",
      iconData: Icons.build_outlined,
      onTap: (context) async {
        final packageInfo = await PackageInfo.fromPlatform();

        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("App Information"),
                content: Text(
                    "appName: ${packageInfo.appName}\npackageName: ${packageInfo.packageName}\nversion: ${packageInfo.version}\nbuildNumber: ${packageInfo.buildNumber}\nisDebug: $kDebugMode\nisProfile: $kProfileMode\nisRelease: $kReleaseMode\n"),
              );
            });
      },
    ),
  ];

  @override
  void initState() {
    super.initState();

    getContributors();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      appBar: LargeAppBar(
          title: Text("About Lanis-Mobile"),
      ),
      body: RefreshIndicator(
        onRefresh: () {
          return getContributors();
        },
        child: ListView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (contributors == null && error == false) const LinearProgressIndicator()
                else if (contributors != null && error == false) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16.0,
                      children: [
                        Text(
                          "Contributors",
                          style: Theme.of(context).textTheme.labelLarge!.copyWith(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        Column(
                          spacing: 4.0,
                          children: [
                            SizedBox(
                              height: 176.0,
                              child: Row(
                                spacing: 4.0,
                                children: [
                                  Expanded(
                                    flex: 4800,
                                    child: Material(
                                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: InkWell(
                                        onTap: () => launchUrl(Uri.parse(contributors[0]['html_url'])),
                                        borderRadius: BorderRadius.circular(12.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          spacing: 12.0,
                                          children: [
                                            CircleAvatar(
                                              radius: 38.0,
                                              backgroundImage: NetworkImage(contributors[0]['avatar_url']),
                                            ),
                                            Text(
                                              contributors[0]['login'],
                                              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface),
                                            ),
                                            Text(
                                              "${contributors[0]['contributions']} commits",
                                              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5200,
                                    child: Column(
                                      spacing: 4.0,
                                      children: [
                                        Expanded(
                                          flex: 5500,
                                          child: AvatarTile(
                                            networkImage: contributors[1]['avatar_url'],
                                            name: contributors[1]['login'],
                                            contributions: "${contributors[1]['contributions']} commits",
                                            avatarSize: 24.0,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            onTap: () => launchUrl(Uri.parse(contributors[1]['html_url'])),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 4500,
                                          child: AvatarTile(
                                            networkImage: contributors[2]['avatar_url'],
                                            name: contributors[2]['login'],
                                            contributions: "${contributors[2]['contributions']} commits",
                                            avatarSize: 24.0,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            onTap: () => launchUrl(Uri.parse(contributors[2]['html_url'])),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                            for (var i = 3; i < contributors.length; i++)
                              AvatarTile(
                                networkImage: contributors[i]['avatar_url'],
                                name: contributors[i]['login'],
                                contributions: "${contributors[i]['contributions']} commits",
                                avatarSize: 20.0,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                onTap: () => launchUrl(Uri.parse(contributors[i]['html_url'])),
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (!error) SizedBox(height: 24.0,),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "More information",
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    color: Theme.of(context).colorScheme.primary),
              ),
            ),
            SizedBox(height: 4.0,),
            for (var link in links)
              ListTile(
                leading: Icon(link.iconData),
                title: Text(link.title),
                onTap: () => link.onTap(context),
              ),
            if (error) ...[
              SizedBox(height: 24.0,),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20.0,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(
                        height: 8.0,
                      ),
                      Text(
                        "Normally you would see contributors but an error occurred. Most likely you don't have an internet connection.",
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                      )
                    ],
                  )
              ),
            ],
            SizedBox(height: 12.0,)
          ],
        ),
      ),
    );
  }
}
