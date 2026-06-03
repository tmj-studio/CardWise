# Contributing to CardWise

Thank you for your interest in contributing to CardWise! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you agree to uphold this code. Please:

- Be respectful and constructive in discussions
- Welcome newcomers and help them get started
- Focus on what is best for the community
- Show empathy towards other community members

Please report unacceptable behavior by opening an issue with the `conduct` label.

---

## Getting Started

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- iOS 17.0+ simulator or device
- Git

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/CardWise.git
   cd CardWise
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/Rich627/CardWise.git
   ```

---

## How to Contribute

### Types of Contributions

| Type | Description |
|------|-------------|
| **Bug Fixes** | Fix issues and improve stability |
| **Features** | Add new functionality |
| **Documentation** | Improve README, comments, guides |
| **Localization** | Add/improve translations |
| **Tests** | Add or improve test coverage |
| **UI/UX** | Improve design and user experience |
| **Card Data** | Add new credit card definitions |

### Good First Issues

Look for issues labeled `good first issue` - these are great for newcomers!

---

## Development Setup

1. **Open the project**
   ```bash
   open CardWise.xcodeproj
   ```

2. **Select a simulator**
   - Choose iPhone 15 or newer simulator
   - Or connect a physical device

3. **Build and run**
   - Press `⌘ + R` to build and run
   - Press `⌘ + U` to run tests

### Project Structure

```
CardWise/
├── App/           # App entry point
├── Models/        # Data models (Card, Spending, etc.)
├── Views/         # SwiftUI views
├── ViewModels/    # State management
├── Services/      # Business logic
└── Utils/         # Helper extensions
```

---

## Coding Standards

### Swift Style Guide

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions small and focused
- Add comments for complex logic

### SwiftUI Best Practices

```swift
// Good: Small, focused views
struct CardRowView: View {
    let card: CreditCard

    var body: some View {
        HStack {
            CardIconView(card: card)
            CardInfoView(card: card)
        }
    }
}

// Avoid: Large, monolithic views
struct CardRowView: View {
    var body: some View {
        // 200+ lines of code...
    }
}
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types | UpperCamelCase | `CreditCard`, `SpendingCategory` |
| Functions | lowerCamelCase | `calculateReward()`, `fetchCards()` |
| Variables | lowerCamelCase | `selectedCard`, `totalSpending` |
| Constants | lowerCamelCase | `maxCards`, `defaultReward` |

### File Organization

```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Body (for Views)
// MARK: - Private Methods
// MARK: - Static Methods
```

---

## Pull Request Process

### Before Submitting

- [ ] Code compiles without warnings
- [ ] All tests pass (`⌘ + U`)
- [ ] New code has appropriate tests
- [ ] Code follows project style guidelines
- [ ] Documentation updated if needed

### PR Checklist

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Write clean, documented code
   - Add tests for new functionality
   - Update documentation if needed

3. **Commit with clear messages**
   ```bash
   git commit -m "Add: credit card sorting by reward rate"
   git commit -m "Fix: rotating category activation bug"
   git commit -m "Update: README installation instructions"
   ```

4. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   Then open a Pull Request on GitHub.

### PR Title Format

```
[Type] Brief description

Types:
- Add: New feature
- Fix: Bug fix
- Update: Enhancement to existing feature
- Remove: Removing code/feature
- Refactor: Code restructuring
- Docs: Documentation only
- Test: Adding tests
```

### Review Process

1. A maintainer will be automatically assigned via [CODEOWNERS](.github/CODEOWNERS)
2. At least **1 maintainer review** is required before merging
3. All **CI checks must pass** (build, tests, SwiftLint)
4. Address any requested changes and re-request review
5. Once approved and CI is green, your PR will be merged

---

## Reporting Bugs

### Before Reporting

- Check existing issues to avoid duplicates
- Try to reproduce with the latest version

### Bug Report Template

```markdown
**Description**
A clear description of the bug.

**Steps to Reproduce**
1. Go to '...'
2. Tap on '...'
3. See error

**Expected Behavior**
What should happen.

**Actual Behavior**
What actually happens.

**Screenshots**
If applicable.

**Environment**
- iOS Version:
- Device:
- App Version:
```

---

## Suggesting Features

### Feature Request Template

```markdown
**Problem**
What problem does this solve?

**Proposed Solution**
How should it work?

**Alternatives Considered**
Other solutions you've thought about.

**Additional Context**
Mockups, examples, etc.
```

---

## Adding Credit Card Data

The reward database ships bundled with the app as `CardWise/Resources/cards.json` (loaded by
`CardCatalog`). To add or update a card, edit that file directly.

1. Open `CardWise/Resources/cards.json` and add an entry:

```json
{
  "name": "Card Name",
  "annualFee": 0,
  "rewardType": "cashback",
  "network": "visa",
  "baseReward": 1,
  "categories": [
    { "category": "dining", "multiplier": 3, "cap": 1500, "capPeriod": "quarterly" }
  ],
  "imageColor": "#1A1A1A"
}
```

2. Match the shape of the existing entries and the `CreditCard` model in
   `CardWise/Models/CreditCard.swift`.

### Verification

- Verify card data accuracy from official issuer websites.
- Build and run the app — `CardCatalog` decodes `cards.json` on launch and falls back to
  `MockData` if the JSON is malformed, so confirm your card actually appears.
- The CI build/test workflow will fail if `cards.json` can't be decoded by the tests.

---

## Questions?

Feel free to open an issue with the `question` label or reach out to the maintainers.

Thank you for contributing!
