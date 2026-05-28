import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'contact_notified_item_model.dart';
export 'contact_notified_item_model.dart';

class ContactNotifiedItemWidget extends StatefulWidget {
  const ContactNotifiedItemWidget({
    super.key,
    String? initials,
    String? name,
    String? status,
  })  : this.initials = initials ?? 'AS',
        this.name = name ?? 'Aavya Sharma',
        this.status = status ?? 'Location Received';

  final String initials;
  final String name;
  final String status;

  @override
  State<ContactNotifiedItemWidget> createState() =>
      _ContactNotifiedItemWidgetState();
}

class _ContactNotifiedItemWidgetState extends State<ContactNotifiedItemWidget> {
  late ContactNotifiedItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ContactNotifiedItemModel());
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
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.8,
                child: Container(
                  width: 40.0,
                  height: 40.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Text(
                    valueOrDefault<String>(
                      widget.initials,
                      'AS',
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: FlutterFlowTheme.of(context).labelMedium.override(
                          font: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).tertiary,
                          fontSize: 15.2,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                          lineHeight: 1.3,
                        ),
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      valueOrDefault<String>(
                        widget.name,
                        'Aavya Sharma',
                      ),
                      style: FlutterFlowTheme.of(context).bodyLarge.override(
                            font: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyLarge
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).primaryText,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.bold,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyLarge
                                .fontStyle,
                            lineHeight: 1.6,
                          ),
                    ),
                    Text(
                      valueOrDefault<String>(
                        widget.status,
                        'Location Received',
                      ),
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).success,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodySmall
                                .fontStyle,
                            lineHeight: 1.5,
                          ),
                    ),
                  ].divide(SizedBox(height: 4.0)),
                ),
              ),
              Icon(
                Icons.check_circle_rounded,
                color: FlutterFlowTheme.of(context).success,
                size: 20.0,
              ),
            ].divide(SizedBox(width: 16.0)),
          ),
        ),
      ),
    );
  }
}
