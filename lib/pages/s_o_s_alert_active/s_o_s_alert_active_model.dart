import '/components/button/button_widget.dart';
import '/components/contact_notified_item/contact_notified_item_widget.dart';
import '/flutter_flow/flutter_flow_google_map.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 's_o_s_alert_active_widget.dart' show SOSAlertActiveWidget;
import 'package:flutter/material.dart';

class SOSAlertActiveModel extends FlutterFlowModel<SOSAlertActiveWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Map Google Map widget.
  LatLng? mapGoogleMapsCenter;
  final mapGoogleMapsController = Completer<GoogleMapController>();
  // Model for ContactNotifiedItem.
  late ContactNotifiedItemModel contactNotifiedItemModel1;
  // Model for ContactNotifiedItem.
  late ContactNotifiedItemModel contactNotifiedItemModel2;
  // Model for ContactNotifiedItem.
  late ContactNotifiedItemModel contactNotifiedItemModel3;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    contactNotifiedItemModel1 =
        createModel(context, () => ContactNotifiedItemModel());
    contactNotifiedItemModel2 =
        createModel(context, () => ContactNotifiedItemModel());
    contactNotifiedItemModel3 =
        createModel(context, () => ContactNotifiedItemModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    contactNotifiedItemModel1.dispose();
    contactNotifiedItemModel2.dispose();
    contactNotifiedItemModel3.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}
