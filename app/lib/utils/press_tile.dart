import 'package:flutter/material.dart';

class PressTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final void Function()? onPressed;
  final Color? foregroundColor;
  final BorderRadius? borderRadius;
  const PressTile({super.key, required this.title, required this.subtitle, required this.icon, this.onPressed, this.foregroundColor, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: foregroundColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: borderRadius ?? BorderRadius.circular(12.0),
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius ?? BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                  icon,
                  color:
                  Theme.of(context).colorScheme.onSurface),
              SizedBox(
                width: 16,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
