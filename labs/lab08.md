# 8 - AI Inference with GitHub Actions
In this lab you will use AI inference capabilities within GitHub Actions workflows.
> Duration: 15-20 minutes

References:
- [GitHub Actions AI Inference Action](https://github.com/actions/ai-inference)
- [GitHub Models Documentation](https://docs.github.com/en/github-models)
- [Using GitHub Models in GitHub Actions](https://docs.github.com/en/github-models/use-github-models-in-github-actions)

## 8.1 Add AI Inference to a Workflow

In this section, you'll update a workflow to use AI inference and generate responses using GitHub Models.

### Understanding the `models: read` Permission

GitHub Actions requires explicit permission to access GitHub Models. The `models: read` permission grants your workflow read-only access to AI models, enabling it to send prompts and receive responses. Without this permission, the workflow will fail with a permissions error.

### Understanding the Starter Workflow

1. Open the workflow file [ai-inference.yml](/.github/workflows/ai-inference.yml)
2. Review the existing structure:
```YAML
name: 08-1. AI Inference

on:
  push:
    branches:
      - 'feature/**'
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  models: read

jobs:
  inference:
    name: AI Inference
    runs-on: ubuntu-latest
    steps:
      # Add AI inference steps here
```

> **Note:** The workflow has the `models: read` permission configured, a `push` trigger for feature branches, a `pull_request` trigger to run on PRs to main, and a `workflow_dispatch` trigger for manual execution. You'll add the AI inference steps.

### Add the AI Inference Step

3. Edit the file and replace the comment `# Add AI inference steps here` with the following YAML content:
```YAML
      - name: Run AI Inference
        id: ai
        uses: actions/ai-inference@v1
        with:
          prompt: "Explain what GitHub Actions is in 2 sentences."
          max-tokens: 150

      - name: Display Response
        run: echo "${{ steps.ai.outputs.response }}"
```

> **Note:** The `actions/ai-inference@v1` action accepts these key inputs:
> - `prompt`: The text prompt to send to the AI model
> - `model`: The model to use (defaults to `openai/gpt-4o`)
> - `max-tokens`: Maximum tokens in the response (controls response length)
>
> The AI response is available in `steps.ai.outputs.response` where `ai` is the `id` we assigned to the inference step.

### Test the Workflow

4. Commit the changes into a new `feature/lab08` branch and push to the remote repository
5. Go to `Actions` and see the details of your running workflow (the workflow triggers automatically on push to feature branches)
6. Click into the workflow run and expand the `Display Response` step to see the AI-generated explanation of GitHub Actions
7. Open a new pull request from `Pull requests`
> Make sure it is your repository pull request to not propose changes to the upstream repository. From the drop-down list choose the base repository to be yours.
8. Once all checks have passed, click on the button `Merge pull request` to complete the PR
9. Go to `Actions` and see the details of your running workflow

## 8.2 Final

> **Note:** Section 8.2 will be completed in a future story with the full solution.

<details>
  <summary>ai-inference.yml</summary>

```YAML
name: 08-1. AI Inference

on:
  push:
    branches:
      - 'feature/**'
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  models: read

jobs:
  inference:
    name: AI Inference
    runs-on: ubuntu-latest
    steps:
      - name: Run AI Inference
        id: ai
        uses: actions/ai-inference@v1
        with:
          prompt: "Explain what GitHub Actions is in 2 sentences."
          max-tokens: 150

      - name: Display Response
        run: echo "${{ steps.ai.outputs.response }}"
```
</details>
