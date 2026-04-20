# Contributing to Evolution

Thank you for your interest in contributing to Evolution! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/evolution.git
   cd evolution
   ```
3. **Set up the development environment**:
   ```bash
   bundle install
   pnpm install
   bundle exec rails db:setup
   ```

## Development Workflow

### Branch Naming

- Use descriptive branch names: `feat/feature-name`, `fix/bug-description`, `docs/update-readme`
- Follow conventional commit format

### Making Changes

1. Create a new branch from `develop`:

   ```bash
   git checkout -b feat/my-feature develop
   ```

2. Make your changes following

3. Test your changes:

   ```bash
   pnpm test
   pnpm lint
   ```

4. Commit your changes using [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat: add new feature"
   git commit -m "fix: resolve bug in authentication"
   ```

### Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```
feat(api): add endpoint for message templates
fix(auth): resolve token expiration issue
docs(readme): update installation instructions
```

## Pull Request Process

1. **Update your fork** with the latest changes:

   ```bash
   git fetch upstream
   git rebase upstream/develop
   ```

2. **Push your changes**:

   ```bash
   git push origin feat/my-feature
   ```

3. **Create a Pull Request** on GitHub:
   - Target the `develop` branch
   - Provide a clear description of your changes
   - Reference any related issues
   - Include screenshots if applicable

4. **Wait for review**:
   - Address any feedback from reviewers
   - Make sure all CI checks pass
   - Keep your PR up to date with `develop`

## Coding Standards

### Ruby

- Follow RuboCop style guide (150 character max line length)
- Use Service Objects for business logic
- Write clear, descriptive method names
- Add comments for complex logic

### Testing

- Write tests for new features
- Ensure all tests pass before submitting PR
- Aim for meaningful test coverage

### API Changes

- Document API changes in Swagger
- Maintain backward compatibility when possible
- Update API version if breaking changes are necessary

## Project Structure

- `app/` - Application code (models, controllers, services, etc.)
- `lib/` - Library code and utilities
- `config/` - Configuration files
- `db/` - Database migrations and seeds
- `swagger/` - API documentation
- `docs/` - Additional documentation

## Questions?

- Check our [documentation](./README.md)
- Open an issue on GitHub for questions
- Join our community discussions

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.

Thank you for contributing to Evolution! 🚀
