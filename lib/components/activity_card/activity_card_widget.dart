import '/flutter_flow/flutter_flow_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Expandable meet card used by [ActivitiesWidget].
class ActivityCardWidget extends StatelessWidget {
  const ActivityCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.expanded,
    required this.image,
    required this.favorite,
    required this.index,
  });

  final String title;
  final String subtitle;
  final String description;
  final bool expanded;
  final String image;
  final bool favorite;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      clipBehavior: Clip.antiAlias,
      elevation: 2.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140.0,
            child: CachedNetworkImage(
              imageUrl: image,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: theme.secondaryBackground),
              errorWidget: (_, __, ___) => Container(
                color: theme.accent4,
                child: Icon(Icons.image_not_supported, color: theme.secondaryText),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16.0, 12.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.titleSmall.override(
                          font: GoogleFonts.sora(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            subtitle,
                            style: theme.bodySmall.override(
                              font: GoogleFonts.sora(),
                              color: theme.secondaryText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.secondaryText,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 16.0),
              child: Text(
                description,
                style: theme.bodyMedium.override(font: GoogleFonts.sora()),
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
