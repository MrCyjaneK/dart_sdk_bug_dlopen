import 'package:monero/monero.dart' as monero;
import 'package:monero/wownero.dart' as wownero;

void main(List<String> arguments) {
  testWownero();
  testMonero();
}

void testMonero() {
  final xmrWmPtr = monero.WalletManagerFactory_getWalletManager();
  final xmrWPtr = monero.WalletManager_createWallet(
    xmrWmPtr,
    path: '/dev/shm/xmr-${DateTime.now()}',
    password: '',
  );
  final xmraddress = monero.Wallet_address(xmrWPtr);
  print("monero: $xmraddress (should start with 4 or 8)");
  if (!xmraddress.startsWith("4") && !xmraddress.startsWith("8")) {
    print("INVALID MONERO ADDRESS");
  }
}

void testWownero() {
  final wowWmPtr = wownero.WalletManagerFactory_getWalletManager();
  final wowWPtr = wownero.WalletManager_createWallet(
    wowWmPtr,
    path: '/dev/shm/wow-${DateTime.now()}',
    password: '',
  );
  final wowaddress = wownero.Wallet_address(wowWPtr);
  print("wownero: $wowaddress (should start with W)");
  if (!wowaddress.startsWith("W")) {
    print("INVALID WOWNERO ADDRESS");
  }
}
