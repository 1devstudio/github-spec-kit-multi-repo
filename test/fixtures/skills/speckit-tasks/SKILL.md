---
description: Generate an actionable, dependency-ordered tasks.md.
---

# Spec Kit: Tasks (stock-shaped fixture)

## Outline

3. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
   - If data-model.md exists: Extract entities and map to user stories

4. **Generate tasks.md**: Read the tasks template and fill with:
   - Correct feature name from plan.md
   - Phase 2: Foundational tasks (blocking prerequisites for all user stories)

## Task Generation Rules

### Checklist Format (REQUIRED)

**Format Components**:

4. **[Story] label**: REQUIRED for user story phase tasks only
   - Format: [US1], [US2], [US3], etc. (maps to user stories from spec.md)
   - Polish phase: NO story label
5. **Description**: Clear action with exact file path

**Examples**:

- ✅ CORRECT: `- [ ] T012 [P] [US1] Create User model in src/models/user.py`
- ✅ CORRECT: `- [ ] T014 [US1] Implement UserService in src/services/user_service.py`
- ❌ WRONG: `- [ ] Create User model` (missing ID and Story label)
