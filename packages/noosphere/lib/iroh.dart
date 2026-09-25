/// Configuration shared by Noosphere's Iroh transport adapters.
library;

const String noosphereIrohAlpn = 'noosphere/roast/1';
const int noosphereIrohWireVersion = 1;

enum IrohRelayPolicy { defaultNetwork, disabled, staging, custom }

final class IrohRelayConfig {
  IrohRelayConfig._(this.policy, List<String> urls)
    : urls = List.unmodifiable(urls) {
    if (policy == IrohRelayPolicy.custom && urls.isEmpty) {
      throw ArgumentError.value(urls, 'urls', 'custom relay list is empty');
    }
    if (policy != IrohRelayPolicy.custom && urls.isNotEmpty) {
      throw ArgumentError.value(
        urls,
        'urls',
        'relay URLs require the custom policy',
      );
    }
  }

  factory IrohRelayConfig.defaultNetwork() =>
      IrohRelayConfig._(IrohRelayPolicy.defaultNetwork, const []);

  factory IrohRelayConfig.disabled() =>
      IrohRelayConfig._(IrohRelayPolicy.disabled, const []);

  factory IrohRelayConfig.staging() =>
      IrohRelayConfig._(IrohRelayPolicy.staging, const []);

  factory IrohRelayConfig.custom(List<String> urls) =>
      IrohRelayConfig._(IrohRelayPolicy.custom, urls);

  final IrohRelayPolicy policy;
  final List<String> urls;
}
