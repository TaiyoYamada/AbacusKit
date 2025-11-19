# Contributing to AbacusKit

We welcome contributions to AbacusKit! This guide explains how to contribute to the project.

## Development Environment Setup

### Requirements

- macOS 14.0 or later
- Xcode 16.0 or later
- Swift 6.0 or later

### Setup Steps

```bash
# Clone the repository
git clone https://github.com/yourusername/AbacusKit.git
cd AbacusKit

# Resolve dependencies
make setup

# Generate mocks
make mocks

# Build
make build

# Run tests
make test
```

## Development Workflow

### 1. Creating a Branch

```bash
# For new features
git checkout -b feature/your-feature-name

# For bug fixes
git checkout -b fix/bug-description
```

### 2. Coding Conventions

#### Swift Style Guide

- Follow Swift API Design Guidelines
- Comply with SwiftLint configuration
- Naming conventions:
  - Classes/Structs: PascalCase
  - Methods/Variables: camelCase
  - Protocols: Nouns or adjectives
  - Constants: camelCase

#### Architecture Principles

- Adhere to **SOLID principles**
- Maintain **Clean Architecture** layer separation
- All dependencies through **protocols**
- Use **Dependency Injection**

#### Documentation

Write **SwiftDocC** format documentation for all public APIs:

```swift
/// Method summary
///
/// Detailed description goes here.
///
/// - Parameters:
///   - param1: Parameter description
///   - param2: Parameter description
/// - Returns: Return value description
/// - Throws: Description of errors thrown
public func myMethod(param1: String, param2: Int) throws -> Result {
    // Implementation
}
```

Implementation details can use comments in any language:

```swift
// Load model from cache here
let cachedModel = await cache.getCurrentModelURL()
```

### 3. Writing Tests

#### Test Requirements

- All new features require tests
- Maintain test coverage above 80%
- BDD style using Quick/Nimble
- Generate mocks with Cuckoo

#### How to Write Tests

```swift
import Quick
import Nimble
import Cuckoo
@testable import AbacusKit

final class MyFeatureSpec: QuickSpec {
    override class func spec() {
        describe("MyFeature") {
            var sut: MyFeature!
            var mockDependency: MockDependency!
            
            beforeEach {
                mockDependency = MockDependency()
                sut = MyFeature(dependency: mockDependency)
            }
            
            context("when condition X") {
                it("should do Y") {
                    // Given
                    stub(mockDependency) { stub in
                        when(stub.someMethod()).thenReturn(expectedValue)
                    }
                    
                    // When
                    let result = sut.performAction()
                    
                    // Then
                    expect(result).to(equal(expectedValue))
                    verify(mockDependency).someMethod()
                }
            }
        }
    }
}
```

#### Generating Mocks

When adding new protocols:

```bash
# Regenerate mocks
make mocks

# Run tests to verify
make test
```

### 4. Committing

#### Commit Message Conventions

Follow Conventional Commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Type:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only changes
- `style`: Changes that don't affect code meaning (formatting, etc.)
- `refactor`: Code changes without bug fixes or feature additions
- `test`: Adding or modifying tests
- `chore`: Changes to build process or tools

**Examples:**

```bash
git commit -m "feat(ml): add model preloading support"
git commit -m "fix(networking): handle timeout errors correctly"
git commit -m "docs(readme): update installation instructions"
```

### 5. Pull Requests

#### Pre-PR Checklist

- [ ] All tests pass (`make test`)
- [ ] Build succeeds (`make build`)
- [ ] SwiftDocC documentation added
- [ ] Changes documented in CHANGELOG.md
- [ ] Ready for code review

#### PR Template

```markdown
## Changes

<!-- Describe the changes made -->

## Motivation and Context

<!-- Why is this change needed? -->

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing

<!-- How was this change tested? -->

## Checklist

- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] All tests pass
```

## Code Review Process

1. CI runs automatically when PR is created
2. At least one maintainer review required
3. Address all comments
4. Maintainer will merge after approval

## Release Process

1. Update version number (Semantic Versioning)
2. Update CHANGELOG.md
3. Create tag: `git tag v1.0.0`
4. Push tag: `git push origin v1.0.0`

## Questions and Support

- Issues: Bug reports and feature requests
- Discussions: General questions and discussions
- Email: Direct contact with maintainers

## Code of Conduct

All contributors must follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Contributed code will be released under the MIT License.

---

Thank you for your contributions! 🎉
