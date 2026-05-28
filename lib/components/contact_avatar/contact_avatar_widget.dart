import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'contact_avatar_model.dart';
export 'contact_avatar_model.dart';

class ContactAvatarWidget extends StatefulWidget {
  const ContactAvatarWidget({
    super.key,
    Color? bg,
    String? initials,
    String? name,
  })  : this.bg = bg ?? const Color(0xFFE1BEE7),
        this.initials = initials ?? 'MA',
        this.name = name ?? 'Maa';

  final Color bg;
  final String initials;
  final String name;

  @override
  State<ContactAvatarWidget> createState() => _ContactAvatarWidgetState();
}

class _ContactAvatarWidgetState extends State<ContactAvatarWidget> {
  late ContactAvatarModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ContactAvatarModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48.0,
          height: 48.0,
          decoration: BoxDecoration(
            color: valueOrDefault<Color>(
              widget.bg,
              Color(0xFFE1BEE7),
            ),
            shape: BoxShape.circle,
          ),
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Text(
            valueOrDefault<String>(
              widget.initials,
              'MA',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            style: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 18.24,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  lineHeight: 1.3,
                ),
            overflow: TextOverflow.clip,
          ),
        ),
        Text(
          valueOrDefault<String>(
            widget.name,
            'Maa',
          ),
          maxLines: 1,
          style: FlutterFlowTheme.of(context).labelSmall.override(
                font: GoogleFonts.plusJakartaSans(
                  fontWeight:
                      FlutterFlowTheme.of(context).labelSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).secondaryText,
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                lineHeight: 1.2,
              ),
          overflow: TextOverflow.ellipsis,
        ),
      ].divide(SizedBox(height: 4.0)),
    );
  }
}
