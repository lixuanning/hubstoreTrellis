# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

### 注释规范

项目为中文团队协作，关键位置必须有中文注释：

- **文件头注释**：说明文件职责和核心逻辑
- **复杂业务逻辑**：非自解释的算法、状态机、条件分支必须注释说明意图
- **接口/函数**：对外暴露的 public 方法需描述参数含义和返回值
- **hooks / 中间件**：触发时机和副作用必须注释

<!-- Patterns that must always be used -->

(To be filled by the team)

---

## Testing Requirements

### Release Test Verification (Phase 3.1)

When QA delivers test cases for an upcoming release, place them at `.trellis/releases/<version>/test-cases.md`. The Phase 3.1 step will then:

1. Read every checkbox under Smoke Test — all must pass before release commit
2. Walk through every scenario under Functional Test — fix failures or document as known limitations
3. This is a version-level gate; daily task development does not touch it

### Code-Level Testing

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
