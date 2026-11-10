# Behavioural evals

Every suite under `tests/` is static: it checks what the files say. These cases check what an agent does with the skills loaded. Each case sends one request a world creator might write and grades the reply. Run them before and after restructuring a skill, and when the active SDK target moves.

Requires Claude Code 2.1.269 or later (`claude --version`).

```bash
# From the repository root. Runs each case with and without the plugin and reports the difference.
claude plugin eval . --no-publish --model claude-sonnet-5-5 --judge-model claude-sonnet-5-5 --runs 1 --concurrency 6

# One case, or one tag
claude plugin eval . --no-publish --judge-model claude-sonnet-5-5 --case udon-synced-toggle
claude plugin eval . --no-publish --judge-model claude-sonnet-5-5 --tag world
```

- `--no-publish` keeps the report on disk in `evals/results/`, which git ignores. Without it the HTML report is also uploaded to claude.ai.
- `--judge-model claude-sonnet-5-5` matters. The default judge (Haiku) failed replies that plainly met the criterion, and its three votes disagreed with each other on the same reply.
- `--model` sets the agent under test. Without it the run uses your default model.
- Each run is a full agent session on your own account. One pass over the 16 cases with both arms and `--runs 1` cost about 3 USD on Sonnet. The default is 3 runs per case.

## Reading the result

- A case passes when every scored grader passes. `regex` graders are exact checks on the reply, for example that `List<` does not appear. `llm` graders are judged by a model against the sentence in the grader file.
- `skill-fired` graders report whether the expected skill was invoked. Under the with/without comparison they are an indicator, not part of the score. If a case fails and its skill did not fire, look at the skill `description` first.
- The delta between the two arms is what the skills added. A case that passes in both arms still guards against the skills making an answer worse, but it does not measure what they add.
- One run is noisy. The same case can fire the skill in one run and not in the next. Use `--runs 3` before drawing a conclusion from a single case.

## Adding a case

Copy a case directory. `prompt.md` holds the request. Each file in `graders/` is one check. Use a `regex` grader when a correct answer must contain a specific token. Use an `llm` grader, written as an explicit PASS condition, for behaviour that has no fixed spelling and for every "must not use" check: a good answer often names the blocked API to say it is unavailable, and a regex over the whole reply cannot tell that from a use. Ask for the answer in the reply rather than in a file: writing files needs `--allow-tools Write`, and the checks here read the final message.

The most useful cases cover facts a model does not already know: recent SDK additions, and behaviour that differs between the Unity editor and the VRChat client.
