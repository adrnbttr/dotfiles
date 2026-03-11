# Code Review Prompt

Please review this code thoroughly and provide constructive feedback.

## Review Checklist

### 1. **Architecture & Design**
- [ ] Are design patterns used appropriately?
- [ ] Is the code modular and loosely coupled?
- [ ] Are SOLID principles followed?
- [ ] Is there appropriate separation of concerns?

### 2. **Code Quality**
- [ ] Is the code readable and maintainable?
- [ ] Are functions/methods small and focused?
- [ ] Is there appropriate naming (variables, functions, classes)?
- [ ] Is there code duplication that could be refactored?

### 3. **Error Handling**
- [ ] Are edge cases handled properly?
- [ ] Is there appropriate input validation?
- [ ] Are errors logged meaningfully?
- [ ] Is there graceful degradation?

### 4. **Performance**
- [ ] Are there obvious performance bottlenecks?
- [ ] Is memory usage optimized?
- [ ] Are database queries efficient?
- [ ] Is caching used appropriately?

### 5. **Security**
- [ ] Are there security vulnerabilities?
- [ ] Is sensitive data handled properly?
- [ ] Are authentication/authorization checks in place?
- [ ] Is input sanitized/escaped?

### 6. **Testing**
- [ ] Is the code testable?
- [ ] Are there appropriate unit tests?
- [ ] Are integration tests needed?
- [ ] Is test coverage adequate?

## Response Format

Please provide your review in this format:

**Summary:**
- Brief overview of the code quality

**Strengths:**
- What's done well

**Areas for Improvement:**
- Specific issues found

**Critical Issues (if any):**
- Security vulnerabilities
- Major performance problems
- Architectural flaws

**Recommendations:**
- Specific refactoring suggestions
- Additional tests needed
- Documentation improvements

**Code Examples (optional):**
- Show refactored code snippets

**Complexity Assessment:**
- Time complexity analysis
- Space complexity analysis