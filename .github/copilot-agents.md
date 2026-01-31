# Copilot Agents Guide - FTMS Flutter App

This document provides guidance for autonomous agents working on the PowerTrain (FTMS) Flutter codebase. It complements `copilot-instructions.md` with agent-specific workflows, decision trees, and automation guidelines.

## Agent Responsibilities & Constraints

### What Agents Should Handle Autonomously
- **Bug fixes** within a single service or feature module
- **Test coverage improvements** (adding unit tests, ensuring 80%+ coverage)
- **Refactoring** within architectural bounds (e.g., extract methods, improve type safety)
- **Localization updates** (adding new translation keys to ARB files, regenerating)
- **Analytics events** (adding new tracking points following existing patterns)
- **Dependency updates** (pubspec.yaml version bumps with compatibility verification)

### What Requires Human Review
- **Architecture changes** (new service types, BLoC additions, state management shifts)
- **Device protocol changes** (FTMS/BLE communication modifications)
- **Play Store release decisions** (version bumping, certificate handling)

## Task Decision Tree

```
Is the task about...?
├─ Single service/feature → [PROCEED: Autonomous Fix]
├─ Multiple interconnected services → [PAUSE: Flag for human review]
├─ Analytics event → [PROCEED: Autonomous - use existing patterns]
├─ Device communication → [CAUTION: Verify against config files first]
├─ Localization → [PROCEED: Autonomous - regenerate after edits]
└─ Test coverage → [PROCEED: Autonomous - follow existing test patterns]
```

### Updating Localization
1. Add key to `lib/l10n/intl_en.arb` (template file)
2. Add translations to `lib/l10n/intl_fr.arb` and `lib/l10n/intl_de.arb`
3. Regenerate: `flutter gen-l10n`
4. Use in code: `AppLocalizations.of(context)!.myNewKey`
5. Test: Verify in all three languages (change system locale in device settings)
6. All messages displayed in UI must be localized

### Writing Service Unit Tests
Pattern for singleton services with testability:
```dart
test('SessionSelectorService initializes correctly', () async {
  final mockFtmsFacade = MockFtmsFacade();
  final mockBluePlusFacade = MockFlutterBluePlusFacade();
  
  final manager = SupportedBTDeviceManager.forTesting(
    flutterBluePlusFacade: mockBluePlusFacade,
    ftmsFacade: mockFtmsFacade,
  );
  
  expect(manager.isInitialized, true);
});
```
**Coverage Target**: 80%+ for all new code

### Fixing Device Communication Issues
1. Check `lib/config/` for device-specific settings (resistance ranges, etc.)
2. Verify `LiveDataFieldValue` mappings in `lib/core/models/live_data_field_value.dart`
3. Trace data flow: `Ftms` → `FtmsDataProcessor` → `LiveDataFieldValue`
4. **MUST test** against actual device type (test files in `test_fit_files/`)

## Testing Requirements

### Mandatory Test Coverage
- All new services: minimum 80% coverage
- Bug fixes: add regression test
- Feature additions: test happy path + error cases
- Analytics: no test required (best-effort)

### Running Tests
```bash
flutter test                    # Run all tests
flutter test --coverage         # Generate coverage report
flutter test test/core/         # Run specific directory
flutter pub run build_runner build --delete-conflicting-outputs # Regenerate mocks
```

### Coverage Check
```bash
lcov --list coverage/lcov.info  # View coverage by file
```
Target: 80% overall (enforce in CI if possible)

## Multi-Feature Coordination

### When Task Spans Multiple Services
Flag for human review if changes affect.

**Action**: Document the multi-service impact, create a summary, assign to human.

## Build & Release Automation

### Pre-Release Checklist (Agents)
- [ ] Run `flutter test` → 0 failures
- [ ] Check coverage: `flutter test --coverage`
- [ ] Verify no analysis warnings: `flutter analyze`
- [ ] Confirm `lib/l10n/` changes regenerated: `flutter gen-l10n`
- [ ] Test on Mac:  `flutter run -d macos`

### Build Commands
```bash
# Local testing (preferred)
flutter run -d macos

# Run on phone connected via USB
flutter run -d 39141JEHN15832 -PdevBuild

# Run on android emulator
flutter run -d emulator-5554 -PdevBuild --debug

# Play Store submission
flutter build appbundle --release

# Output locations
build/app/outputs/bundle/release/app-release.aab
```

## Code Quality Enforcement

### Linting & Analysis
```bash
flutter analyze                    # Check for issues
```

**Enforced Rules**:
- No `dynamic` types in new code
- Null safety: 100% coverage
- Enums: `UPPER_CASE` allowed (see `analysis_options.yaml`)
- Constants: follow existing naming

### Commit Message Format (for CI integration)
```
[FEATURE|FIX|REFACTOR|TEST]: Brief description

Detailed explanation (if needed)
- Key changes
- Testing approach
- Related files
```

## Resources

- **FTMS Protocol**: [Bluetooth Fitness Machine Service Spec](https://www.bluetooth.com/specifications/specs/fitness-machine-service-1-0/)
- **Flutter Best Practices**: See `copilot-instructions.md`
- **Test Examples**: `test/core/`, `test/features/`
- **Device Config**: `lib/config/`

## Success Metrics

An agent successfully completed a task if:
- ✅ All tests pass locally
- ✅ Coverage on modified/new code is at least 80%
- ✅ No new analysis warnings
- ✅ Changes align with architectural patterns
- ✅ Code follows SOLID principles
- ✅ Commits are atomic and well-documented
