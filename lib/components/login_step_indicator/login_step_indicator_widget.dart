import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'login_step_indicator_model.dart';
export 'login_step_indicator_model.dart';

class LoginStepIndicatorWidget extends StatefulWidget {
  const LoginStepIndicatorWidget({
    super.key,
    bool? active,
  }) : this.active = active ?? true;

  final bool active;

  @override
  State<LoginStepIndicatorWidget> createState() =>
      _LoginStepIndicatorWidgetState();
}

class _LoginStepIndicatorWidgetState extends State<LoginStepIndicatorWidget> {
  late LoginStepIndicatorModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoginStepIndicatorModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: widget.active ? 24.0 : 8.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: widget.active
                ? FlutterFlowTheme.of(context).tertiary
                : FlutterFlowTheme.of(context).surfaceVariant,
            borderRadius: BorderRadius.circular(9999.0),
            shape: BoxShape.rectangle,
          ),
        ),
        Container(
          width: widget.active ? 8.0 : 24.0,
          height: 8.0,
          decoration: BoxDecoration(
            color: widget.active
                ? FlutterFlowTheme.of(context).surfaceVariant
                : FlutterFlowTheme.of(context).tertiary,
            borderRadius: BorderRadius.circular(9999.0),
            shape: BoxShape.rectangle,
          ),
        ),
      ].divide(SizedBox(width: 4.0)),
    );
  }
}
