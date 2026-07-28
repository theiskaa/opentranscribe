/// The geometry of calendar navigation: where the list must glide for a
/// tapped day to arrive on the reading line, the chrome's fixed bottom edge.
library;

/// The offset that parks a day's splitter label (at scroll-space [start]) on
/// the reading line, for a list whose resting top is [contentTop]. The first
/// day's label rests ON the line at rest, so it goes home.
double dayGlideOffset(double start, double contentTop) {
  final travel = start - contentTop;
  return travel < 0.5 ? 0 : travel;
}
