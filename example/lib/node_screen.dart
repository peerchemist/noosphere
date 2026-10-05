import 'package:flutter/material.dart';
import 'package:noosphere_flutter/noosphere_flutter.dart';

import 'demo_identity.dart';
import 'diagnostics.dart';
import 'proposal_widgets.dart';
import 'session_controller.dart';

final class NodeScreen extends StatefulWidget {
  const NodeScreen({super.key, this.controller});
  final DemoSessionController? controller;
  @override
  State<NodeScreen> createState() => _NodeScreenState();
}

final class _NodeScreenState extends State<NodeScreen> {
  late final DemoSessionController session;
  final _irohId = TextEditingController();
  final _dkgName = TextEditingController(text: 'first-2of2');
  final _messageHash = TextEditingController(
    text: '0000000000000000000000000000000000000000000000000000000000000001',
  );
  @override
  void initState() {
    super.initState();
    session = widget.controller ?? DemoSessionController();
    session.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_refresh);
    session.dispose();
    _irohId.dispose();
    _dkgName.dispose();
    _messageHash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = session.snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('Noosphere 2-of-2 test')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'TEST ONLY: public test mnemonic, deterministic keys, and '
            'in-memory state. Never send funds to these keys.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          const SelectableText('Mnemonic: $demoTestMnemonic'),
          SelectableText('Iroh path: ${session.irohDerivationPath}'),
          const SizedBox(height: 16),
          DropdownButtonFormField<TestMachine>(
            initialValue: session.machine,
            decoration: const InputDecoration(labelText: 'This instance'),
            items: [
              for (final machine in TestMachine.values)
                DropdownMenuItem(value: machine, child: Text(machine.label)),
            ],
            onChanged: session.running || session.busy
                ? null
                : (machine) => session.selectMachine(machine ?? TestMachine.a),
          ),
          const SizedBox(height: 8),
          if (session.machine.runsSigner)
            SelectableText(
              'ROAST participant ${session.machine.participant} public key: '
              '${session.participantPublicKey.hex}\n'
              'Peercoin path: ${session.participantDerivationPath}',
            ),
          if (!session.machine.hostsServer) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _irohId,
              enabled: !session.running,
              decoration: const InputDecoration(
                labelText: 'Computer A Iroh ID',
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: session.busy || session.running
                    ? null
                    : () => session.start(_irohId.text),
                child: const Text('Start'),
              ),
              OutlinedButton(
                onPressed: session.busy || !session.running
                    ? null
                    : session.stop,
                child: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('State: $session.status'),
          if (session.publishedIrohId case final id?)
            SelectableText('Iroh ID: $id'),
          if (snapshot != null && snapshot.signerRunning) ...[
            Text(
              'Participant ${session.machine.participant}; '
              'online peers: ${snapshot.onlineParticipants.length}',
            ),
            const Divider(height: 32),
            if (snapshot.dkgs.isEmpty && snapshot.keys.isEmpty) ...[
              TextField(
                controller: _dkgName,
                decoration: const InputDecoration(labelText: 'DKG name'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: session.busy
                    ? null
                    : () => session.createDkg(_dkgName.text),
                child: const Text('Create 2-of-2 key'),
              ),
            ],
            for (final dkg in snapshot.dkgs.where(
              (dkg) => dkg.stage == 'waiting',
            ))
              DkgProposalTile(
                proposal: dkg,
                busy: session.busy,
                onAccept: () => session.acceptDkg(dkg),
              ),
            for (final dkg in snapshot.dkgs.where(
              (dkg) => dkg.stage != 'waiting',
            ))
              Text(
                '${dkg.name}: ${dkg.stage}, '
                '${dkg.completedParticipants.length}/2. '
                'Waiting for the other signer; do not create another DKG.',
              ),
            for (final key in snapshot.keys) ...[
              SelectableText('Group key: ${key.groupKeyHex}'),
              SelectableText(
                'Peercoin testnet address: '
                '${taprootAddress(key, Network.testnet)}',
              ),
              SelectableText(
                'Peercoin mainnet address: '
                '${taprootAddress(key, Network.mainnet)}',
              ),
            ],
            const Divider(height: 32),
            TextField(
              controller: _messageHash,
              decoration: const InputDecoration(
                labelText: '32-byte hash (64 hex characters)',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: session.busy || snapshot.keys.isEmpty
                  ? null
                  : () => session.requestSignature(_messageHash.text),
              child: const Text('Request 2-of-2 signature'),
            ),
            for (final request in snapshot.signingRequests)
              SigningProposalTile(
                proposal: request,
                busy: session.busy,
                onAccept: () => session.acceptSignatures(request),
              ),
            if (session.signature case final signature?) ...[
              SelectableText('Signed hash: $session.signedHash'),
              SelectableText('Schnorr signature: $signature'),
              Text('Signature valid: $session.signatureValid'),
            ],
          ],
          if (session.error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }
}
