/// Moods and the lerpable expression vector for the animated Buddy.
library;

enum BuddyMood {
  happy,
  nervous,
  sad,
  inLove,
  zen,
  energetic,
  hungry,
  sleepy,

  /// Fast asleep: eyes shut, zzZ (e.g. the welcome intro before the tap).
  asleep,
  empathetic,
}

String buddyMoodLabel(BuddyMood m) => switch (m) {
  BuddyMood.happy => 'glücklich',
  BuddyMood.nervous => 'nervös',
  BuddyMood.sad => 'traurig',
  BuddyMood.inLove => 'verliebt',
  BuddyMood.zen => 'entspannt',
  BuddyMood.energetic => 'energiegeladen',
  BuddyMood.hungry => 'hungrig',
  BuddyMood.sleepy => 'verschlafen',
  BuddyMood.asleep => 'schläft',
  BuddyMood.empathetic => 'mitfühlend',
};

/// Every animatable "expression" parameter, lerpable as a vector.
/// Defaults describe the happy mood.
class FacePose {
  const FacePose({
    this.lidTop = 0,
    this.lidTilt = 0,
    this.lidBottom = 0,
    this.pupil = 1,
    this.heart = 0,
    this.smile = 1,
    this.open = 0,
    this.mouthWidth = 1,
    this.brow = 0,
    this.browTilt = 0,
    this.blush = 0.3,
    this.nervousFx = 0,
    this.sway = 12,
    this.breath = 0.018,
    this.breathRate = 0.35,
    this.shake = 0,
    this.hop = 0,
    this.hearts = 0,
    this.gazeY = -0.2,
    this.lean = 0,
    this.rumble = 0,
    this.zzz = 0,
  });

  final double lidTop, lidTilt, lidBottom, pupil, heart, smile, open;
  final double mouthWidth, brow, browTilt, blush, nervousFx, sway, breath;
  final double breathRate, shake, hop, hearts, gazeY, lean, rumble, zzz;

  static FacePose forMood(BuddyMood m) => switch (m) {
    BuddyMood.happy => const FacePose(),
    BuddyMood.nervous => const FacePose(
      lidTop: 0,
      pupil: 0.7,
      smile: 0,
      open: 0.45,
      mouthWidth: 0.4,
      brow: 1,
      browTilt: 1,
      blush: 0,
      nervousFx: 1,
      sway: 3,
      breath: 0.012,
      breathRate: 0.9,
      shake: 1,
      gazeY: 0,
    ),
    BuddyMood.sad => const FacePose(
      lidTop: 0.38,
      lidTilt: 0.35,
      pupil: 0.95,
      smile: -0.7,
      mouthWidth: 0.8,
      brow: 0.8,
      browTilt: 0.8,
      blush: 0,
      sway: 4,
      breath: 0.012,
      breathRate: 0.22,
      gazeY: 0.6,
    ),
    BuddyMood.inLove => const FacePose(
      lidTop: 0.1,
      pupil: 1.05,
      heart: 1,
      smile: 0.9,
      open: 0.2,
      mouthWidth: 0.9,
      blush: 1,
      sway: 14,
      breath: 0.022,
      breathRate: 0.4,
      hearts: 1,
    ),
    BuddyMood.zen => const FacePose(
      lidTop: 0.92,
      smile: 0.5,
      mouthWidth: 0.7,
      blush: 0.2,
      sway: 5,
      breath: 0.04,
      breathRate: 0.16,
      gazeY: 0,
    ),
    BuddyMood.energetic => const FacePose(
      lidTop: 0,
      pupil: 0.85,
      smile: 1,
      open: 0.55,
      mouthWidth: 1.1,
      blush: 0.5,
      sway: 18,
      breath: 0.02,
      breathRate: 0.7,
      hop: 1,
    ),
    BuddyMood.hungry => const FacePose(
      lidTop: 0,
      pupil: 1.15,
      smile: -0.1,
      open: 0.35,
      mouthWidth: 0.45,
      brow: 0.7,
      browTilt: 0.9,
      blush: 0,
      sway: 6,
      breath: 0.016,
      breathRate: 0.45,
      rumble: 1,
      gazeY: 0,
    ),
    BuddyMood.sleepy => const FacePose(
      lidTop: 0.6,
      smile: 0.3,
      mouthWidth: 0.7,
      blush: 0.15,
      sway: 4,
      breath: 0.03,
      breathRate: 0.18,
      zzz: 1,
      gazeY: 0.3,
    ),
    BuddyMood.asleep => const FacePose(
      lidTop: 1,
      smile: 0.3,
      mouthWidth: 0.6,
      blush: 0.15,
      sway: 3,
      breath: 0.035,
      breathRate: 0.15,
      zzz: 1,
      gazeY: 0.3,
    ),
    BuddyMood.empathetic => const FacePose(
      lidTop: 0.15,
      pupil: 1.1,
      smile: 0.35,
      mouthWidth: 0.8,
      brow: 0.8,
      browTilt: 0.6,
      blush: 0.6,
      sway: 5,
      breath: 0.02,
      breathRate: 0.3,
      lean: 0.04,
    ),
  };

  List<double> get _v => [
    lidTop, lidTilt, lidBottom, pupil, heart, smile, open, mouthWidth, //
    brow, browTilt, blush, nervousFx, sway, breath, breathRate, shake, //
    hop, hearts, gazeY, lean, rumble, zzz,
  ];

  static FacePose _from(List<double> v) => FacePose(
    lidTop: v[0],
    lidTilt: v[1],
    lidBottom: v[2],
    pupil: v[3],
    heart: v[4],
    smile: v[5],
    open: v[6],
    mouthWidth: v[7],
    brow: v[8],
    browTilt: v[9],
    blush: v[10],
    nervousFx: v[11],
    sway: v[12],
    breath: v[13],
    breathRate: v[14],
    shake: v[15],
    hop: v[16],
    hearts: v[17],
    gazeY: v[18],
    lean: v[19],
    rumble: v[20],
    zzz: v[21],
  );

  static FacePose lerp(FacePose a, FacePose b, double k) {
    final av = a._v, bv = b._v;
    return _from([
      for (var i = 0; i < av.length; i++) av[i] + (bv[i] - av[i]) * k,
    ]);
  }

  FacePose copyWith({
    double? lidTop,
    double? lidTilt,
    double? lidBottom,
    double? pupil,
    double? heart,
    double? smile,
    double? open,
    double? mouthWidth,
    double? brow,
    double? browTilt,
    double? blush,
    double? nervousFx,
    double? sway,
    double? breath,
    double? breathRate,
    double? shake,
    double? hop,
    double? hearts,
    double? gazeY,
    double? lean,
    double? rumble,
    double? zzz,
  }) => FacePose(
    lidTop: lidTop ?? this.lidTop,
    lidTilt: lidTilt ?? this.lidTilt,
    lidBottom: lidBottom ?? this.lidBottom,
    pupil: pupil ?? this.pupil,
    heart: heart ?? this.heart,
    smile: smile ?? this.smile,
    open: open ?? this.open,
    mouthWidth: mouthWidth ?? this.mouthWidth,
    brow: brow ?? this.brow,
    browTilt: browTilt ?? this.browTilt,
    blush: blush ?? this.blush,
    nervousFx: nervousFx ?? this.nervousFx,
    sway: sway ?? this.sway,
    breath: breath ?? this.breath,
    breathRate: breathRate ?? this.breathRate,
    shake: shake ?? this.shake,
    hop: hop ?? this.hop,
    hearts: hearts ?? this.hearts,
    gazeY: gazeY ?? this.gazeY,
    lean: lean ?? this.lean,
    rumble: rumble ?? this.rumble,
    zzz: zzz ?? this.zzz,
  );

  bool closeTo(FacePose other, {double eps = 1e-3}) {
    final a = _v, b = other._v;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > eps) return false;
    }
    return true;
  }
}
