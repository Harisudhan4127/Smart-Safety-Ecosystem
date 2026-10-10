/// Semantic severity shared by the domain layer and the design system.
///
/// A severity is never communicated by colour alone: every surface that renders
/// one pairs it with an icon and a text label.
enum Severity { safe, info, caution, critical }

extension SeverityX on Severity {
  /// Sort order used when picking the most serious item in a collection.
  int get rank => switch (this) {
        Severity.safe => 0,
        Severity.info => 1,
        Severity.caution => 2,
        Severity.critical => 3,
      };

  String get label => switch (this) {
        Severity.safe => 'Normal',
        Severity.info => 'Info',
        Severity.caution => 'Warning',
        Severity.critical => 'Critical',
      };
}

/// Returns the more serious of [a] and [b].
Severity mostSevere(Severity a, Severity b) =>
    a.rank >= b.rank ? a : b;