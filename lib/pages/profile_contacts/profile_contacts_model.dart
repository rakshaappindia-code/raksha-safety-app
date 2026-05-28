import '/components/button/button_widget.dart';
import '/components/contact_item/contact_item_widget.dart';
import '/components/slider/slider_widget.dart';
import '/components/switch_component/switch_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'profile_contacts_widget.dart' show ProfileContactsWidget;
import 'package:flutter/material.dart';

class ProfileContactsModel extends FlutterFlowModel<ProfileContactsWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for ContactItem.
  late ContactItemModel contactItemModel1;
  // Model for ContactItem.
  late ContactItemModel contactItemModel2;
  // Model for ContactItem.
  late ContactItemModel contactItemModel3;
  // Model for ContactItem.
  late ContactItemModel contactItemModel4;
  // Model for SwitchComponent.
  late SwitchComponentModel switchComponentModel1;
  // Model for SwitchComponent.
  late SwitchComponentModel switchComponentModel2;
  // Model for Slider.
  late SliderModel sliderModel;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    buttonModel1 = createModel(context, () => ButtonModel());
    contactItemModel1 = createModel(context, () => ContactItemModel());
    contactItemModel2 = createModel(context, () => ContactItemModel());
    contactItemModel3 = createModel(context, () => ContactItemModel());
    contactItemModel4 = createModel(context, () => ContactItemModel());
    switchComponentModel1 = createModel(context, () => SwitchComponentModel());
    switchComponentModel2 = createModel(context, () => SwitchComponentModel());
    sliderModel = createModel(context, () => SliderModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    buttonModel1.dispose();
    contactItemModel1.dispose();
    contactItemModel2.dispose();
    contactItemModel3.dispose();
    contactItemModel4.dispose();
    switchComponentModel1.dispose();
    switchComponentModel2.dispose();
    sliderModel.dispose();
    buttonModel2.dispose();
  }
}
