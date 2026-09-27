import 'package:noosphere/domain.dart';

import '../data.dart';

List<ParticipantKeyInfo> generateNewKey(int threshold) {
  final part1s = List.generate(
    10,
    (i) => DkgPart1(identifier: ids[i], threshold: threshold, n: 10),
  );

  final commitmentSet = DkgCommitmentSet(
    List.generate(10, (i) => (ids[i], part1s[i].public)),
  );

  final part2s = List.generate(
    10,
    (i) => DkgPart2(
      identifier: ids[i],
      round1Secret: part1s[i].secret,
      commitments: commitmentSet,
    ),
  );

  final shares = List.generate(
    10,
    (i) => {
      for (int j = 0; j < 10; j++)
        if (j != i) ids[j]: part2s[j].sharesToGive[ids[i]]!,
    },
  );

  return List.generate(
    10,
    (i) => DkgPart3(
      identifier: ids[i],
      round2Secret: part2s[i].secret,
      commitments: commitmentSet,
      receivedShares: shares[i],
    ).participantInfo,
  );
}
