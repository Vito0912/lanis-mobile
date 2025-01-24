import 'package:flutter/material.dart';

import '../../models/substitution.dart';

class SubstitutionListTile extends StatelessWidget {
  final Substitution substitutionData;
  const SubstitutionListTile({super.key, required this.substitutionData});

  bool doesExist(String? info) {
    List empty = [null, "", " ", "-", "---"];
    return !empty.contains(info);
  }

  bool doesExistList(List<String?> info) {
    List empty = [null, "", " ", "-", "---"];
    return info.any((element) => !empty.contains(element));
  }

  @override
  Widget build(BuildContext context) {
    Substitution data = substitutionData;
    TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Card(
        child: Column(
          spacing: 8.0,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  spacing: 8.0,
                  children: [
                    if (doesExist(data.klasse))
                      Text(
                        data.klasse!,
                        style: textTheme.titleMedium,
                      ),
                    if (doesExist(data.klasse_alt) && !doesExist(data.klasse))
                      Text(
                        data.klasse_alt!,
                        style: textTheme.titleMedium,
                      ),
                    if (doesExist(data.lerngruppe)) Text('(${data.lerngruppe})')
                  ],
                ),
                if (doesExist(data.fach))
                  Text(
                    data.fach!,
                    style: textTheme.titleMedium,
                  ),
              ],
            ),
            Row(
              spacing: 8.0,
              children: [
                if (doesExistList([data.lehrer, data.vertreter]))
                  Icon(Icons.school_outlined),
                // Für Vertreter
                if (doesExistList([data.vertreter, data.Vertreterkuerzel]))
                  Text(
                    [
                      if (doesExist(data.vertreter)) data.vertreter!,
                      if (!doesExist(data.vertreter) &&
                          doesExist(data.Vertreterkuerzel))
                        data.Vertreterkuerzel!,
                      if (doesExist(data.vertreter) &&
                          doesExist(data.Vertreterkuerzel))
                        "(${data.Vertreterkuerzel})"
                    ].join(" "),
                    style: textTheme.bodyLarge,
                  ),
                if ((doesExist(data.lehrer) || doesExist(data.Lehrerkuerzel)) &&
                    (doesExist(data.vertreter) ||
                        doesExist(data.Vertreterkuerzel)))
                  Text("->"),
                if (doesExist(data.lehrer) || doesExist(data.Lehrerkuerzel))
                  Text(
                    [
                      if (doesExist(data.lehrer)) data.lehrer!,
                      if (!doesExist(data.lehrer) &&
                          doesExist(data.Lehrerkuerzel))
                        data.Lehrerkuerzel!,
                      if (doesExist(data.lehrer) &&
                          doesExist(data.Lehrerkuerzel))
                        "(${data.Lehrerkuerzel})"
                    ].join(" "),
                    style: textTheme.bodyLarge!.copyWith(
                      decoration: (doesExist(data.vertreter) &&
                              doesExist(data.Vertreterkuerzel))
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
              ],
            ),
            Row(
              spacing: 8.0,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  spacing: 8.0,
                  children: [
                    if (doesExist(data.raum)) Icon(Icons.room_outlined),
                    if (doesExist(data.raum))
                      Text(
                        data.raum!,
                        style: textTheme.bodyLarge,
                      ),
                  ],
                ),
                if (doesExist(data.stunde))
                  Text(data.stunde,
                      style: textTheme.bodyLarge!.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              ],
            ),
            if (doesExistList([data.hinweis, data.hinweis2]))
              Divider(
                height: 4.0,
              ),
            Row(
              spacing: 12.0,
              children: [
                if (doesExist(data.hinweis))
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20.0,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                if (doesExist(data.hinweis))
                  SubstitutionsFormattedText(
                    data.hinweis!,
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            Row(
              spacing: 12.0,
              children: [
                if (doesExist(data.hinweis2))
                  Icon(
                    Icons.info_outline_rounded,
                    size: 20.0,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                if (doesExist(data.hinweis2))
                  SubstitutionsFormattedText(
                    data.hinweis2!,
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// Takes a string with eventual html tags and applies the necessary formatting according to the tags.
/// Tags may only occur at the beginning or end of the string.
///
/// Tags include: <b>, <i>, <del>
class SubstitutionsFormattedText extends StatelessWidget {
  final String data;
  final TextStyle style;

  const SubstitutionsFormattedText(this.data, this.style, {super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(text: _format(data, style));
  }

  TextSpan _format(String data, TextStyle style) {
    if (data.startsWith("<b>") && data.endsWith("</b>")) {
      return TextSpan(
          text: data.substring(3, data.length - 4),
          style: style.copyWith(fontWeight: FontWeight.bold));
    } else if (data.startsWith("<i>") && data.endsWith("</i>")) {
      return TextSpan(
          text: data.substring(3, data.length - 4),
          style: style.copyWith(fontStyle: FontStyle.italic));
    } else if (data.startsWith("<del>") && data.endsWith("</del>")) {
      return TextSpan(
          text: data.substring(5, data.length - 6),
          style: style.copyWith(decoration: TextDecoration.lineThrough));
    } else {
      return TextSpan(text: data, style: style);
    }
  }
}
