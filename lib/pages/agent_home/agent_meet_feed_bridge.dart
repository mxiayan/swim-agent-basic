import '/app_state.dart';
import '/backend/schema/monitored_meets_record.dart';

import 'agent_feed_item.dart';
import 'agent_priority_engine.dart';

/// Builds the same derived Agent feed rows the Agent dashboard uses from monitored meets.
List<AgentFeedItem> agentFeedItemsFromMonitoredMeets({
  required List<MonitoredMeetsRecord> meets,
  required FFAppState app,
  required DateTime now,
}) {
  final swimmerTier = AgentPriorityEngine.trainingTierForApp(app);
  String? swimFirstName() {
    final n = app.currentSwimmerName.trim();
    if (n.isEmpty) return null;
    return n.split(RegExp(r'\s+')).first;
  }

  final out = <AgentFeedItem>[];
  for (final m in meets) {
    if (!AgentPriorityEngine.monitoredMeetMatchesTrainingTier(m, swimmerTier)) {
      continue;
    }
    out.add(
      AgentPriorityEngine.withDerivedUiPriority(
        AgentPriorityEngine.feedStubFromMonitoredMeet(
          meet: m,
          feedDocId: 'meet_${m.reference.id}',
          swimmerDisplayFirstName: swimFirstName(),
        ),
        now,
      ),
    );
  }
  return out;
}
