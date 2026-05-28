import '/components/action_card/action_card_widget.dart';
import '/components/contact_avatar/contact_avatar_widget.dart';
import '/components/switch_component/switch_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'home_widget.dart' show HomeWidget;
import 'package:flutter/material.dart';

class HomeModel extends FlutterFlowModel<HomeWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SwitchComponent.
  late SwitchComponentModel switchComponentModel;
  // Model for ActionCard.
  late ActionCardModel actionCardModel1;
  // Model for ActionCard.
  late ActionCardModel actionCardModel2;
  // Model for ActionCard.
  late ActionCardModel actionCardModel3;
  // Model for ContactAvatar.
  late ContactAvatarModel contactAvatarModel1;
  // Model for ContactAvatar.
  late ContactAvatarModel contactAvatarModel2;
  // Model for ContactAvatar.
  late ContactAvatarModel contactAvatarModel3;
  // Model for ContactAvatar.
  late ContactAvatarModel contactAvatarModel4;

  @override
  void initState(BuildContext context) {
    switchComponentModel = createModel(context, () => SwitchComponentModel());
    actionCardModel1 = createModel(context, () => ActionCardModel());
    actionCardModel2 = createModel(context, () => ActionCardModel());
    actionCardModel3 = createModel(context, () => ActionCardModel());
    contactAvatarModel1 = createModel(context, () => ContactAvatarModel());
    contactAvatarModel2 = createModel(context, () => ContactAvatarModel());
    contactAvatarModel3 = createModel(context, () => ContactAvatarModel());
    contactAvatarModel4 = createModel(context, () => ContactAvatarModel());
  }

  @override
  void dispose() {
    switchComponentModel.dispose();
    actionCardModel1.dispose();
    actionCardModel2.dispose();
    actionCardModel3.dispose();
    contactAvatarModel1.dispose();
    contactAvatarModel2.dispose();
    contactAvatarModel3.dispose();
    contactAvatarModel4.dispose();
  }
}
