import 'package:flutter/material.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'diagnostics.dart';

final class DkgProposalTile extends StatelessWidget {
  const DkgProposalTile({
    super.key,
    required this.proposal,
    required this.busy,
    required this.onAccept,
  });
  final WorkerDkgStatus proposal;
  final bool busy;
  final VoidCallback onAccept;
  @override
  Widget build(BuildContext context) => ListTile(
    title: Text('Accept DKG: ${proposal.name}'),
    subtitle: Text('${proposal.threshold} signers; ${proposal.description}'),
    trailing: FilledButton(
      onPressed: busy || proposal.expiry.isBefore(DateTime.now())
          ? null
          : onAccept,
      child: const Text('Accept DKG'),
    ),
  );
}

final class SigningProposalTile extends StatelessWidget {
  const SigningProposalTile({
    super.key,
    required this.proposal,
    required this.busy,
    required this.onAccept,
  });
  final WorkerSigningRequest proposal;
  final bool busy;
  final VoidCallback onAccept;
  @override
  Widget build(BuildContext context) {
    final details = proposal.decodeProposal();
    return ListTile(
      title: Text(
        'Signature request: ${hexBytes(details.requiredSigs.single.signDetails.message)}',
      ),
      subtitle: Text(proposal.status),
      trailing: proposal.status == 'waiting'
          ? FilledButton(
              onPressed: busy || proposal.expiry.isBefore(DateTime.now())
                  ? null
                  : onAccept,
              child: const Text('Accept signature'),
            )
          : null,
    );
  }
}
