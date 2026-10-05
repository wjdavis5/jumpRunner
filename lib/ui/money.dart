import '../game/models/courier_skin.dart';

/// What an outfit goal readout says: how far [careerTips] are from [outfit].
String outfitGoalText(CourierSkin outfit, int careerTips) {
  final short = outfit.price - careerTips;
  return short > 0 ? '${dollars(short)} to go' : 'READY IN LOCKER';
}

/// Formats a tip amount for display: `$950`, `$15,000`.
String dollars(int amount) => '${amount < 0 ? '-' : ''}\$${_grouped(amount.abs())}';

/// Formats a distance for display: `412 m`, `2,330 m`.
String meters(int distance) => '${_grouped(distance)} m';

/// [value] with a comma between each group of three digits.
String _grouped(int value) {
  final digits = value.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  return grouped.toString();
}
