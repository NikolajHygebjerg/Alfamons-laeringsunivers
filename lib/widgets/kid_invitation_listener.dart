import 'package:flutter/material.dart';
import '../services/kid_invitation_service.dart';

/// Wrapper der starter/stopper KidInvitationService for realtime-notifikationer.
/// Brug om kid-skærme der har kidId.
class KidInvitationListener extends StatefulWidget {
  final String kidId;
  final Widget child;

  const KidInvitationListener({
    super.key,
    required this.kidId,
    required this.child,
  });

  @override
  State<KidInvitationListener> createState() => _KidInvitationListenerState();
}

class _KidInvitationListenerState extends State<KidInvitationListener> {
  @override
  void initState() {
    super.initState();
    KidInvitationService.start(widget.kidId);
  }

  @override
  void dispose() {
    KidInvitationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
