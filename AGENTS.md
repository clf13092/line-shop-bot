## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file.

### Available skills
- line-bot-lambda-deploy: Build/push/deploy Lambda container images for this repository, including digest-based updates and manifest compatibility handling. (file: /Users/sugimori/LINE_BOT/.kiro/skills/line-bot-lambda-deploy/SKILL.md)
- line-bot-agentcore-deploy: Deploy and troubleshoot AgentCore Runtime in local/CI environments for this repository. (file: /Users/sugimori/LINE_BOT/.kiro/skills/line-bot-agentcore-deploy/SKILL.md)
- line-bot-ci-triage: Investigate failed GitHub Actions runs and map failures to known patterns quickly. (file: /Users/sugimori/LINE_BOT/.kiro/skills/line-bot-ci-triage/SKILL.md)

### How to use skills
- Discovery: Use the list above to choose the minimum set of relevant skills.
- Trigger rules: Use a skill when the request explicitly names it (`$skill-name`) or clearly matches its description.
- Progressive disclosure: Read `SKILL.md` first, then load only the referenced files needed for the task.
- Resource usage: Prefer bundled `scripts/` for deterministic or repetitive operations.
- Context hygiene: Do not bulk-load all references; read only what is required.
