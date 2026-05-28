import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'action_card_model.dart';
export 'action_card_model.dart';

class ActionCardWidget extends StatefulWidget {
  const ActionCardWidget({
    super.key,
    Color? color,
    this.icon,
    String? label,
    String? target,
    Color? tint,
  })  : this.color = color ?? const Color(0x00000000),
        this.label = label ?? 'Police Help',
        this.target = target ?? 'navigate:Home',
        this.tint = tint ?? const Color(0x00000000);

  final Color color;
  final Widget? icon;
  final String label;
  final String target;
  final Color tint;

  @override
  State<ActionCardWidget> createState() => _ActionCardWidgetState();
}

class _ActionCardWidgetState extends State<ActionCardWidget> {
  late ActionCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ActionCardModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(24.0),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: valueOrDefault<Color>(
                    widget.tint,
                    FlutterFlowTheme.of(context).error15,
                  ),
                  borderRadius: BorderRadius.circular(16.0),
                  shape: BoxShape.rectangle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Container(
                    child: widget.icon!,
                  ),
                ),
              ),
              Text(
                valueOrDefault<String>(
                  widget.label,
                  'Police Help',
                ),
                style: FlutterFlowTheme.of(context).labelMedium.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      lineHeight: 1.3,
                    ),
              ),
            ].divide(SizedBox(height: 8.0)),
          ),
        ),
      ),
    );
  }
}
