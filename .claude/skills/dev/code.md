# Code Rules

## DDD
- one module per file, filename matches module name
- split following SRP into DDD-named modules
- use domain words, not technical jargon
- names should read like the business, not the framework
- short and clear, never abbreviated, never obfuscated
- abstractions model the domain, not the technology
- names reveal intent, not implementation

## COMPLEXITY
- Max cyclomatic complexity 1 per function
- No if/case/cond/try in function bodies
- Pattern match on function heads instead
- Extract helper functions with pattern-matched clauses

## DONT
- NO comments in code, ever. Code should be self-explanatory.
