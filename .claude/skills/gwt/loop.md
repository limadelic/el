# The Loop

## Setup

- `/sup` the team with the cast below
- Confirm lisa replies

## The Cast

| Name | subagent_type | Model  |
|------|---------------|--------|
| lisa | lisa          | sonnet |

- Lisa is the ONLY team member
- Eric is a subagent

## Write Feature

- Read the existing DSL first
- Feed lisa the DSL and input scenarios
- Lisa writes ALL scenarios into one `.feature` file
- Maximize DSL reuse
- Step definitions are Ruby, one file: features/step_definitions/el_steps.rb
- No new step definition files unless necessary

## Review Loop

- Use subagent eric to review the feature file
- Use team agent lisa to adjust what you consider valid
- Repeat while valid concerns arise

## Human Review

- Present `.feature` to user
- User approves or back to review loop
