/// The geometry of the chrome's folding bottom slot.
///
/// The week strip is the top of the journal, not a fixed rail over it, so it
/// folds away as the list scrolls and unfolds as the list comes home. It folds
/// over EXACTLY its own height: the chrome's bottom edge then rides up at the
/// same rate as the content under it, which is what makes the strip read as a
/// header scrolling away rather than a bar deciding to shrink. That 1:1 is also
/// what keeps the reading line honest - the label glued under the strip stays
/// glued to it the whole way down.
library;

/// How far folded the strip is at [pixels] of scroll, 0 open to 1 gone, for a
/// slot [depth] tall. Overscroll (a record pull) reads as fully open.
double stripFold(double pixels, double depth) => depth <= 0 ? 1 : (pixels / depth).clamp(0.0, 1.0);

/// Where the scroll must land for a half-folded strip to finish the nearer
/// way, or null when it is already open or already gone. Mid-fold is not a
/// resting state: a strip stopped with its numbers cut in half reads as the
/// screen having given up part way.
double? stripSettle(double pixels, double depth) {
  if (depth <= 0 || pixels <= 0 || pixels >= depth) return null;
  return pixels * 2 >= depth ? depth : 0;
}

/// The offset that parks a day's splitter label (at scroll-space [start]) on
/// the reading line, for a list whose resting top is [contentTop] and whose
/// strip folds over [depth].
///
/// The line moves with the fold and the fold moves with the offset, so this
/// solves the two against each other: past the fold the line has settled
/// [depth] higher, and the offset has to make that up. The first label is the
/// degenerate case - it rests ON the line at every offset through the fold, so
/// it goes home, where the strip is open.
double dayGlideOffset(double start, double contentTop, double depth) {
  final travel = start - contentTop;
  return travel < 0.5 ? 0 : travel + depth;
}
