import 'dart:convert';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/custom_code/profile_avatar_save.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_ui_tokens.dart';
import '/widgets/swimmer_profile_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Agent-themed swimmer profile (opened from header avatar).
class SwimmerProfilePage extends StatefulWidget {
  const SwimmerProfilePage({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SwimmerProfilePage(),
      ),
    );
  }

  @override
  State<SwimmerProfilePage> createState() => _SwimmerProfilePageState();
}

class _SwimmerProfilePageState extends State<SwimmerProfilePage> {
  final _nameCtrl = TextEditingController();
  bool _loadingClub = true;
  MetadataClubsRecord? _club;
  String _practiceTierValue = '';
  bool _saving = false;

  static const _defaultAvatarAsset = 'assets/images/mcroskey-headshot.jpg';

  static const _practiceOptions = <_PracticeOption>[
    _PracticeOption(
      value: '',
      menuLabel: 'Auto (from club profile)',
    ),
    _PracticeOption(
      value: 'Junior / Age group',
      menuLabel: 'Junior / Age group',
    ),
    _PracticeOption(
      value: 'Senior',
      menuLabel: 'Senior',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final app = FFAppState();
    _nameCtrl.text = app.currentSwimmerName.trim();
    _practiceTierValue = app.swimmerPracticeTierLabel.trim();
    _loadClubMeta();
  }

  Future<void> _loadClubMeta() async {
    final code = FFAppState().currentSwimmerGroup.trim();
    if (code.isEmpty) {
      safeSetState(() {
        _club = null;
        _loadingClub = false;
      });
      return;
    }
    try {
      final c = await MetadataClubsRecord.findByClubLookup(code);
      safeSetState(() {
        _club = c;
        _loadingClub = false;
      });
    } catch (_) {
      safeSetState(() {
        _club = null;
        _loadingClub = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String _normalizedPracticeValue() {
    final v = _practiceTierValue.trim();
    if (_practiceOptions.any((o) => o.value == v)) {
      return v;
    }
    return '';
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      FFAppState().update(() {
        FFAppState().profileAvatarWebBase64 = b64;
        FFAppState().profileAvatarLocalPath = '';
      });
    } else {
      final path = await persistProfileAvatarFromXFile(file);
      FFAppState().update(() {
        FFAppState().profileAvatarLocalPath = path ?? '';
        FFAppState().profileAvatarWebBase64 = '';
      });
    }
    await FFAppState().persistSwimmerContext();
    safeSetState(() {});
  }

  Future<void> _resetAvatar() async {
    FFAppState().update(() {
      FFAppState().profileAvatarLocalPath = '';
      FFAppState().profileAvatarWebBase64 = '';
    });
    await FFAppState().persistSwimmerContext();
    safeSetState(() {});
  }

  Future<void> _saveProfile() async {
    final uid = currentUserUid;
    if (uid.isEmpty) return;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a swimmer name.',
              style: GoogleFonts.sora(fontSize: 14)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    safeSetState(() => _saving = true);
    try {
      final ref = await SwimmerRecord.documentRefForAuthUid(uid);
      if (ref != null) {
        await ref.set(
          createSwimmerRecordData(name: name),
          SetOptions(merge: true),
        );
      }

      FFAppState().update(() {
        FFAppState().currentSwimmerName = name;
        FFAppState().swimmerPracticeTierLabel = _practiceTierValue.trim();
      });
      await FFAppState().persistSwimmerContext();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Profile saved', style: GoogleFonts.sora(fontSize: 14)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e',
              style: GoogleFonts.sora(fontSize: 14)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) safeSetState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final app = context.watch<FFAppState>();

    final clubCode = app.currentSwimmerGroup.trim();
    final clubName = _club?.clubName.trim() ?? '';
    final zoneLabel = app.currentSwimmerZoneLabel.trim();

    return Scaffold(
      backgroundColor: SwimUiTokens.surfaceCanvasAgent,
      appBar: AppBar(
        backgroundColor: SwimUiTokens.surfaceCanvasAgent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: SwimUiTokens.textTitle, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Swimmer profile',
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SwimUiTokens.textTitle,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LavenderIndigoTokens.bgSurface,
                        border:
                            Border.all(color: theme.primary, width: 2),
                        boxShadow: LavenderIndigoTokens.shadowMd,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: buildSwimmerProfileAvatar(
                          defaultAssetPath: _defaultAvatarAsset,
                          filePath: app.profileAvatarLocalPath,
                          webBase64: app.profileAvatarWebBase64,
                          size: 104,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: 4,
                      child: Material(
                        color: LavenderIndigoTokens.primary,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickAvatar,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resetAvatar,
                  child: Text(
                    'Use default photo',
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: LavenderIndigoTokens.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _sectionCard(
            children: [
              Text(
                'Swimmer name',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: SwimUiTokens.textTitle,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: SwimUiTokens.surfaceMuted,
                  hintText: 'Preferred display name',
                  hintStyle: GoogleFonts.sora(
                    fontSize: 15,
                    color: SwimUiTokens.textFaint,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            children: [
              Text(
                'Club',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingClub)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                _kvRow('Name', clubName.isNotEmpty ? clubName : '—'),
                const SizedBox(height: 8),
                _kvRow('Code', clubCode.isNotEmpty ? clubCode : '—'),
              ],
              const SizedBox(height: 6),
              Text(
                'Club comes from your roster. Contact your coach to change it.',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  height: 1.35,
                  color: SwimUiTokens.textFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            children: [
              Text(
                'Swim zone',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                zoneLabel.isNotEmpty ? zoneLabel : 'Zone not set yet',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.textTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            children: [
              Text(
                'Practice / age group',
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SwimUiTokens.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Used by Agent to prioritize junior vs senior meets.',
                style: GoogleFonts.sora(
                  fontSize: 12,
                  height: 1.35,
                  color: SwimUiTokens.textFaint,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: SwimUiTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _normalizedPracticeValue(),
                    icon: Icon(Icons.expand_more_rounded,
                        color: SwimUiTokens.textMuted),
                    items: _practiceOptions
                        .map(
                          (o) => DropdownMenuItem<String>(
                            value: o.value,
                            child: Text(
                              o.menuLabel,
                              style: GoogleFonts.sora(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: SwimUiTokens.textTitle,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      safeSetState(() => _practiceTierValue = v ?? '');
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: LavenderIndigoTokens.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    LavenderIndigoTokens.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.sora(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SwimUiTokens.cardSurfaceEdgeBorder),
        boxShadow: LavenderIndigoTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _kvRow(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            k,
            style: GoogleFonts.sora(
              fontSize: 13,
              color: SwimUiTokens.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: SwimUiTokens.textTitle,
            ),
          ),
        ),
      ],
    );
  }
}

class _PracticeOption {
  const _PracticeOption({
    required this.value,
    required this.menuLabel,
  });

  final String value;
  final String menuLabel;
}
