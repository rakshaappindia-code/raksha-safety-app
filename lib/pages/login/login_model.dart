import '/components/button/button_widget.dart';
import '/components/login_step_indicator/login_step_indicator_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'login_widget.dart' show LoginWidget;
import 'package:flutter/material.dart';

class LoginModel extends FlutterFlowModel<LoginWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for LoginStepIndicator.
  late LoginStepIndicatorModel loginStepIndicatorModel;
  // Model for TextField.
  late TextFieldModel textFieldModel;
  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    loginStepIndicatorModel =
        createModel(context, () => LoginStepIndicatorModel());
    textFieldModel = createModel(context, () => TextFieldModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    loginStepIndicatorModel.dispose();
    textFieldModel.dispose();
    buttonModel.dispose();
  }
}
