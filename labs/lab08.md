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
---
name: 08-1. AI Inference

on:
  push:
    branches:
      - "feature/**"
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
      - name: Placeholder
        run: echo "Add AI inference steps"

      - name: Display Response
        run: |
          cat <<'EOF'
          ${{ steps.ai.outputs.response }}
          EOF
```

> **Note:** The workflow has the `models: read` permission configured, a `push` trigger for feature branches, a `pull_request` trigger to run on PRs to main, and a `workflow_dispatch` trigger for manual execution. The `Display Response` step is already configured to output the AI response. You'll replace the placeholder step with the AI inference step.

### Add the AI Inference Step

3. Edit the file and replace the `Placeholder` step with the following YAML content (keep the `Display Response` step that follows):

```YAML
      - name: Run AI Inference
        id: ai
        uses: actions/ai-inference@v1
        with:
          prompt: "Explain what GitHub Actions is in 2 sentences."
          max-tokens: 150
```

> **Note:** The `actions/ai-inference@v1` action accepts these key inputs:
>
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

## 8.2 Prompt Files and Templating

In this section, you'll learn how to externalize prompts to files and use template variables for reusable, parameterized AI workflows.

### Why Use Prompt Files?

Externalizing prompts to files offers several advantages:

- **Reusability**: Share prompts across multiple workflows
- **Version Control**: Track prompt changes in Git history
- **Separation of Concerns**: Keep prompts separate from workflow logic
- **Maintainability**: Update prompts without modifying workflows

### Update the Prompt File

1. Open the prompt file [code-review.prompt.yml](/.github/prompts/code-review.prompt.yml)
2. Review the existing placeholder structure, then replace the contents with:

````YAML
messages:
  - role: system
    content: |
      You are a senior code reviewer. Analyze the provided code snippet and give
      brief, actionable feedback focusing on:
      - Code quality and readability
      - Potential bugs or issues
      - Suggested improvements
      Keep your response concise (3-5 bullet points).
  - role: user
    content: |
      Please review this code:

      ```
      {{code_snippet}}
      ```
model: openai/gpt-4o
````

> **Note:** The `{{code_snippet}}` syntax is a template variable. The double braces indicate a placeholder that will be replaced with actual values at runtime.

### Understanding the Prompt File Structure

The `.prompt.yml` file uses a structured format:

- **messages**: An array of message objects defining the conversation
  - **role**: Either `system` (sets AI behavior) or `user` (the actual prompt)
  - **content**: The message text (supports multi-line with `|`)
- **model**: The AI model to use (defaults to `openai/gpt-4o`)

### Update the Workflow

3. Open the workflow file [ai-inference.yml](/.github/workflows/ai-inference.yml) and make the following changes:

**First**, add input parameters to the `workflow_dispatch` trigger by replacing:

```YAML
  workflow_dispatch:
```

with:

```YAML
  workflow_dispatch:
    inputs:
      code_to_review:
        description: "Code snippet to review"
        required: false
        default: "function add(a, b) { return a + b; }"
```

**Second**, replace the `Run AI Inference` step that we added in 8.1 with the following (keep the `Display Response` step):

```YAML
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run AI Code Review
        id: ai
        uses: actions/ai-inference@v1
        with:
          prompt-file: .github/prompts/code-review.prompt.yml
          input: |
            code_snippet: >-
              ${{ github.event.inputs.code_to_review ||
              'function add(a, b) { return a + b; }' }}
          max-tokens: 300
```

> **Key Changes from Section 8.1:**
>
> - Added `actions/checkout@v4` step - **required** when using `prompt-file` (the file must exist on the runner)
> - Added `workflow_dispatch.inputs.code_to_review` - allows custom input when manually triggering
> - Changed from `prompt` to `prompt-file` - references the external prompt file
> - Added `input` parameter - passes values to template variables (YAML format)

### Understanding Template Variables

The `input` parameter maps values to template variables:

```yaml
input: |
  code_snippet: ${{ github.event.inputs.code_to_review || 'default value' }}
```

This replaces `{{code_snippet}}` in the prompt file with the provided value. The `||` provides a fallback default when the input is not provided (e.g., on push/PR triggers).

### Test the Prompt File Workflow

4. Commit your changes to a feature branch and push
5. Go to **Actions** and select the **08-1. AI Inference** workflow
6. Click **Run workflow**
7. In the **code_to_review** input field, enter a code snippet to review (or use the default)
8. Click **Run workflow** and wait for completion
9. Expand the **Display Review** step to see the AI code review

> **Tip:** Try different code snippets to see how the AI reviewer responds. The template approach makes it easy to review any code by changing the input.

## 8.3 Structured Output (JSON Schema)

In this section, you'll configure the AI to return structured JSON responses that can be parsed and used in downstream workflow steps.

### Why Structured Output?

Free-form AI responses are useful for human reading, but difficult to use programmatically. Structured output solves this by:

- **Reliable Parsing**: JSON format enables consistent extraction of specific fields
- **Automation**: Use AI-generated values in conditional logic and subsequent steps
- **Validation**: JSON Schema ensures responses contain required fields with correct types
- **Integration**: Easily pass structured data to other tools and APIs

### Understanding JSON Schema

JSON Schema defines the structure your AI response must follow. Key concepts:

- **type**: Data type (`object`, `array`, `string`, `integer`, `boolean`)
- **properties**: Fields within an object
- **required**: Array of field names that must be present
- **enum**: Restricts string values to a specific set
- **items**: Defines the structure of array elements
- **additionalProperties**: When `false`, prevents extra fields

### Add JSON Schema to Prompt File

1. Open [code-review.prompt.yml](/.github/prompts/code-review.prompt.yml)
2. Replace the contents with the following to add JSON Schema support:

````yaml
messages:
  - role: system
    content: |
      You are a senior code reviewer. Analyze the provided code and return your
      review as structured JSON. Be concise and actionable.
  - role: user
    content: |
      Review this code and provide structured feedback:

      ```
      {{code_snippet}}
      ```
model: openai/gpt-4o
responseFormat: json_schema
jsonSchema: |
  {
    "name": "code_review",
    "strict": true,
    "schema": {
      "type": "object",
      "properties": {
        "summary": {
          "type": "string",
          "description": "One-sentence summary of the code quality"
        },
        "issues": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "severity": {
                "type": "string",
                "enum": ["low", "medium", "high"]
              },
              "description": {
                "type": "string"
              }
            },
            "required": ["severity", "description"],
            "additionalProperties": false
          },
          "description": "List of identified issues"
        },
        "score": {
          "type": "integer",
          "description": "Overall code quality score from 1-10"
        },
        "suggestion": {
          "type": "string",
          "description": "Top priority improvement suggestion"
        }
      },
      "required": ["summary", "issues", "score", "suggestion"],
      "additionalProperties": false
    }
  }
````

> **Key Additions:**
>
> - `responseFormat: json_schema` - Forces the AI to return valid JSON matching the schema
> - `jsonSchema` - Defines the exact structure with a `name`, `strict: true` for validation, and the `schema` object
> - The schema requires four fields: `summary` (string), `issues` (array), `score` (integer), and `suggestion` (string)

### Add Parsing Steps to Workflow

3. Open [ai-inference.yml](/.github/workflows/ai-inference.yml) and replace the entire contents with:

```yaml
---
name: 08-1. AI Inference

on:
  push:
    branches:
      - "feature/**"
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      code_to_review:
        description: "Code snippet to review"
        required: false
        default: "function add(a, b) { return a + b; }"

permissions:
  models: read

jobs:
  inference:
    name: AI Inference
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run AI Code Review
        id: ai
        uses: actions/ai-inference@v1
        with:
          prompt-file: .github/prompts/code-review.prompt.yml
          input: |
            code_snippet: >-
              ${{ github.event.inputs.code_to_review ||
              'function add(a, b) { return a + b; }' }}
          max-tokens: 500

      - name: Display Raw Response
        run: |
          echo "Raw JSON response:"
          echo '${{ steps.ai.outputs.response }}'

      - name: Parse and Display Review
        run: |
          echo "=== Parsed Code Review ==="
          echo ""
          echo "Summary: $(echo '${{ steps.ai.outputs.response }}' | jq -r '.summary')"
          echo "Score: $(echo '${{ steps.ai.outputs.response }}' | jq -r '.score')/10"
          echo ""
          echo "Issues found:"
          echo '${{ steps.ai.outputs.response }}' | jq -r '.issues[] | "  - [\(.severity)] \(.description)"'
          echo ""
          echo "Top suggestion: $(echo '${{ steps.ai.outputs.response }}' | jq -r '.suggestion')"

      - name: Use Score in Conditional
        run: |
          SCORE=$(echo '${{ steps.ai.outputs.response }}' | jq -r '.score')
          if [ "$SCORE" -ge 7 ]; then
            echo "✅ Code quality is good (score: $SCORE)"
          else
            echo "⚠️ Code needs improvement (score: $SCORE)"
          fi

```

> **New Steps Explained:**
>
> - **Display Raw Response**: Shows the complete JSON returned by the AI
> - **Parse and Display Review**: Uses `jq` to extract individual fields from the JSON
> - **Use Score in Conditional**: Demonstrates using a parsed value in shell logic
>
> **Important:** Use single quotes around `${{ steps.ai.outputs.response }}` when passing to `jq`. This prevents shell expansion issues with special characters in the JSON.

### Understanding `jq` for JSON Parsing

`jq` is a command-line JSON processor pre-installed on GitHub runners. Common patterns:

| Command                     | Description                                   |
| --------------------------- | --------------------------------------------- |
| `jq -r '.field'`            | Extract field value as raw string (no quotes) |
| `jq -r '.nested.field'`     | Extract nested field                          |
| `jq -r '.array[]'`          | Iterate over array elements                   |
| `jq -r '.array[0]'`         | Get first array element                       |
| `jq -r '.items[] \| .name'` | Extract field from each array element         |

The `-r` flag outputs raw strings without JSON quotes.

### Test Structured Output

4. Commit your changes to a feature branch and push
5. Go to **Actions** and select the **08-1. AI Inference** workflow
6. Click **Run workflow** and use the default code or enter your own
7. Expand each step to verify:
   - **Display Raw Response**: Shows valid JSON (starts with `{`, ends with `}`)
   - **Parse and Display Review**: Shows extracted fields (summary, score, issues, suggestion)
   - **Use Score in Conditional**: Shows ✅ or ⚠️ based on the score value

### Common JSON Schema Pitfalls

- **Missing `additionalProperties: false`**: AI may add extra fields not in your schema
- **Forgetting `strict: true`**: Without this, schema validation is lenient
- **Integer vs Number**: Use `integer` for whole numbers, `number` for decimals
- **Empty arrays**: If no issues found, `issues` will be `[]` - handle this in your parsing
- **Escaping in shell**: Always use single quotes around JSON in shell commands

## 8.4 Repository Context with MCP (Advanced - Optional)

> **This section is optional.** It requires creating a Personal Access Token (PAT) and storing it as a repository secret. If you're not comfortable with PAT management or want to skip advanced content, proceed directly to section 8.5 (Final).

In this section, you'll enable Model Context Protocol (MCP) integration, allowing the AI model to access your repository's context — issues, pull requests, files, and more.

### What is MCP?

Model Context Protocol (MCP) is a standard that allows AI models to interact with external data sources. When enabled for GitHub, the AI can:

- List and read repository issues
- Access pull request information
- Browse repository files and structure
- Query workflow run history

This transforms the AI from a general-purpose assistant into one that understands your specific repository.

### Why a Personal Access Token?

The built-in `GITHUB_TOKEN` cannot be used with MCP. You must provide either:

- A **Fine-grained Personal Access Token (PAT)** — recommended for this lab
- A GitHub App installation token

We'll use a Fine-grained PAT with minimal, short-lived permissions.

### Setup: Create a Personal Access Token

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
2. Click **Generate new token**
3. Configure the token:
   - **Token name:** `lab8-mcp-token`
   - **Expiration:** Custom 1 day (short-lived for lab purposes)
   - **Repository access:** Select **Only select repositories** → choose your fork
   - **Permissions** (under Repository permissions):
     - **Contents:** Read-only
     - **Issues:** Read-only
     - **Metadata:** Read-only (automatically selected)
     - **Pull requests:** Read-only
4. Click **Generate token**
5. **Copy the token immediately** — you won't be able to see it again

> **Security Note:** Treat this token like a password. Never commit it to your repository or share it publicly. Use short expiration times and delete tokens when no longer needed.

### Setup: Store the Token as a Secret

1. In your repository, go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Configure:
   - **Name:** `GH_MCP_TOKEN`
   - **Secret:** Paste your token
4. Click **Add secret**

### Setup: Create a Test Issue

To verify MCP is working correctly, create a distinctive test issue:

1. Go to your repository's **Issues** tab
2. Click **New issue**
3. Create an issue with:
   - **Title:** `TEST-MCP-VERIFY: Lab 8 MCP Test Issue`
   - **Body:** `This issue verifies MCP integration is working correctly.`
4. Click **Submit new issue**
5. Note the issue number (e.g., #1, #42)

This distinctive title will help verify the AI is actually querying your repository rather than hallucinating information.

### Setup: Enable the MCP Demo

The MCP demo job is controlled by a repository variable:

1. In your repository, go to **Settings** → **Secrets and variables** → **Actions**
2. Click on the **Variables** tab
3. Click **New repository variable**
4. Configure:
   - **Name:** `ENABLE_MCP_DEMO`
   - **Value:** `true`
5. Click **Add variable**

### Add the MCP Demo Job

Add the MCP demo job to your workflow. Open [ai-inference.yml](/.github/workflows/ai-inference.yml) and add the following job after the `inference` job (at the same indentation level as `inference:`):

```yaml
  # Optional: MCP Integration Demo (requires PAT)
  # This job only runs if ENABLE_MCP_DEMO variable is set to 'true'
  mcp-demo:
    name: MCP Demo (Optional)
    runs-on: ubuntu-latest
    if: ${{ vars.ENABLE_MCP_DEMO == 'true' }}
    steps:
      - name: Run AI with Repository Context
        id: mcp-ai
        uses: actions/ai-inference@v1
        with:
          prompt: |
            You have access to this repository's context via MCP.
            The repository is: ${{ github.repository }}
            Please list the open issues in this repository, including their
            numbers and titles. If there are no open issues, say so.
          max-tokens: 500
          enable-github-mcp: true
          github-mcp-token: ${{ secrets.GH_MCP_TOKEN }}
          github-mcp-toolsets: repos,issues,pull_requests

      - name: Display MCP Response
        run: |
          echo "=== AI Response with Repository Context ==="
          echo "${{ steps.mcp-ai.outputs.response }}"
```

> **Key Parameters:**
>
> - `if: ${{ vars.ENABLE_MCP_DEMO == 'true' }}` — Job only runs when the variable is set
> - `enable-github-mcp: true` — Activates MCP integration
> - `github-mcp-token: ${{ secrets.GH_MCP_TOKEN }}` — Provides authentication for MCP
> - `github-mcp-toolsets: repos,issues,pull_requests` — Specifies which MCP tools to enable

### Test MCP Integration

1. Commit your workflow changes and push to your feature branch
2. Go to **Actions** → select **08-1. AI Inference** workflow
3. Click **Run workflow**
4. Wait for completion and check the **mcp-demo** job:
   - Verify the job ran (not skipped)
   - Expand **Display MCP Response**
   - Look for your test issue: `TEST-MCP-VERIFY: Lab 8 MCP Test Issue`
   - Verify the correct issue number appears

If the AI returns your exact issue title and number, MCP is working correctly!

### Troubleshooting

| Problem | Cause | Solution |
| ------- | ----- | -------- |
| Job skipped | `ENABLE_MCP_DEMO` variable not set | Add the variable with value `true` |
| Job skipped | Variable value incorrect | Ensure value is exactly `true` (lowercase) |
| "MCP authentication failed" | Token missing or invalid | Verify `GH_MCP_TOKEN` secret exists and token hasn't expired |
| Empty/generic response | Token lacks permissions | Verify PAT has Issues Read-only permission |
| Wrong issue data | AI hallucination | Verify the distinctive title appears exactly as created |
| "Resource not accessible" | Token scoped to wrong repository | Regenerate PAT with correct repository selected |

### Cleanup (After Lab)

To maintain security:

1. **Delete the PAT:** GitHub Settings → Developer settings → Personal access tokens → Delete `lab8-mcp-token`
2. **Remove the secret:** Repository Settings → Secrets → Delete `GH_MCP_TOKEN`
3. **Set variable to false:** Repository Settings → Variables → Set `ENABLE_MCP_DEMO` to `false`
4. **Close the test issue:** Issues → Close `TEST-MCP-VERIFY` issue

> **Best Practice:** Always delete PATs when no longer needed. For production use, consider GitHub Apps with installation tokens instead of PATs.

## 8.5 Final

<details>
  <summary>code-review.prompt.yml</summary>

````yaml
messages:
  - role: system
    content: |
      You are a senior code reviewer. Analyze the provided code and return your
      review as structured JSON. Be concise and actionable.
  - role: user
    content: |
      Review this code and provide structured feedback:

      ```
      {{code_snippet}}
      ```
model: openai/gpt-4o
responseFormat: json_schema
jsonSchema: |
  {
    "name": "code_review",
    "strict": true,
    "schema": {
      "type": "object",
      "properties": {
        "summary": {
          "type": "string",
          "description": "One-sentence summary of the code quality"
        },
        "issues": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "severity": {
                "type": "string",
                "enum": ["low", "medium", "high"]
              },
              "description": {
                "type": "string"
              }
            },
            "required": ["severity", "description"],
            "additionalProperties": false
          },
          "description": "List of identified issues"
        },
        "score": {
          "type": "integer",
          "description": "Overall code quality score from 1-10"
        },
        "suggestion": {
          "type": "string",
          "description": "Top priority improvement suggestion"
        }
      },
      "required": ["summary", "issues", "score", "suggestion"],
      "additionalProperties": false
    }
  }
````

</details>

## 8.6 Auto-Analyze Failures (Hands-On)

In this section, you'll get hands-on exposure to an "auto-healing" pattern:

- A workflow run fails
- A separate workflow automatically triggers on that failure
- The failure is analyzed using `actions/ai-inference` + a prompt file
- The workflow creates a remediation issue with a recommended fix (and may optionally assign it to Copilot)

This helps you learn how to combine GitHub Actions, prompt files, and the AI Inference action to triage failures and propose fixes.

### How It Works (Files Involved)

- Workflow: [auto-analyze-failure.yml](/.github/workflows/auto-analyze-failure.yml)
- Prompt: [failed-run-analyze.prompt.yml](/.github/prompts/failed-run-analyze.prompt.yml)

The workflow runs on `workflow_run` events, meaning it triggers automatically when other workflows complete. It only runs its analysis job when the completed workflow concluded with `failure`.

### Prerequisites

This workflow expects a GitHub App token (for the AI inference step) and a token for GitHub MCP access.

1. If you completed Lab 03, you likely already created these:
   - Repository **variable**: `CI_BOT_APP_ID`
   - Repository **secret**: `CI_BOT_PRIVATE_KEY`

   If you deleted them during cleanup, recreate them before continuing.

2. Create a fine-grained Personal Access Token (PAT) for MCP and store it as a repository secret:
   - Repository **secret** name: `AUTO_REMEDIATION_PAT`
   - Suggested permissions (fine-grained token):
     - **Actions:** Read
     - **Contents:** Read
     - **Issues:** Read
     - **Pull requests:** Read
     - (Leave anything else unset unless your org policies require it)

> **Note:** This lab’s goal is to observe how the analysis workflow uses the AI Inference action and MCP to fetch the last portion of failed job logs and generate a remediation plan.

> **Important:** In [auto-analyze-failure.yml](/.github/workflows/auto-analyze-failure.yml), the `actions/create-github-app-token` step uses `owner: ${{ github.repository_owner }}` so it works in forks. If you customize that value, make sure it matches the account/org that owns the repository running the workflow.

### Step 1: Create a Workflow That Fails on Purpose

Create a new workflow file at `.github/workflows/lab08-intentional-failure.yml` with the following contents:

```yaml
name: 08-3. Intentional Failure (for Auto-Analyze)

on:
  workflow_dispatch:

jobs:
  fail-on-purpose:
    runs-on: ubuntu-latest
    steps:
      - name: Explain the purpose
        run: |
          echo "This job fails intentionally to trigger the auto-analyze workflow."
          echo "When you finish the lab, remove this workflow or fix it."

      - name: Fail intentionally
        run: |
          echo "::error::Intentional failure for Lab 8.6"
          exit 1
```

Commit and push this change to your feature branch.

### Step 2: Trigger the Failure

1. Go to **Actions**
2. Select **08-3. Intentional Failure (for Auto-Analyze)**
3. Click **Run workflow**
4. Wait for the run to fail (this is expected)

### Step 3: Watch the Auto-Analyze Workflow Trigger

After the failure completes, GitHub will automatically start a new workflow run for **08-2. Auto Analyze Build Failures**.

1. Go to **Actions** → select **08-2. Auto Analyze Build Failures**
2. Open the newest run (it should reference the failed workflow run in its event payload)
3. Expand these steps:
   - **Analyze build failure** (this calls `actions/ai-inference@v2` with the prompt file)
   - **Parse results** (this parses the JSON response)
   - **Create remediation issue** (this creates an issue with the summary and plan)

### Step 4: Review the AI-Generated Remediation Issue

1. Go to the **Issues** tab
2. Open the newly created issue titled similar to:
   - `🔧 Auto-Remediation: <workflow name> Build Failure`
3. Review:
   - **Summary**: a short explanation of what failed
   - **Remediation Plan**: recommended steps to fix the failure

If your repo supports Copilot assignment via `copilot-swe-agent` and the category is code-related, you may also see the issue assigned automatically.

### Step 5: Apply the Recommended Fix and Verify

For this lab, the "fix" should be straightforward:

1. Update `.github/workflows/lab08-intentional-failure.yml` to stop failing (remove the failing step or change `exit 1` to `exit 0`).
2. Commit and push.
3. Re-run **08-3. Intentional Failure (for Auto-Analyze)** and confirm it succeeds.

You should see that:

- The workflow run is now green
- The auto-analyze workflow does not create a new remediation issue for a successful run

### Cleanup (Recommended)

- Delete `.github/workflows/lab08-intentional-failure.yml` after the lab
- Consider rotating/deleting `AUTO_REMEDIATION_PAT` when done


<details>
  <summary>ai-inference.yml</summary>

```yaml
---
name: 08-1. AI Inference

on:
  push:
    branches:
      - "feature/**"
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      code_to_review:
        description: "Code snippet to review"
        required: false
        default: "function add(a, b) { return a + b; }"

permissions:
  models: read

jobs:
  inference:
    name: AI Inference
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Run AI Code Review
        id: ai
        uses: actions/ai-inference@v1
        with:
          prompt-file: .github/prompts/code-review.prompt.yml
          input: |
            code_snippet: >-
              ${{ github.event.inputs.code_to_review ||
              'function add(a, b) { return a + b; }' }}
          max-tokens: 500

      - name: Display Raw Response
        run: |
          echo "Raw JSON response:"
          echo '${{ steps.ai.outputs.response }}'

      - name: Parse and Display Review
        run: |
          echo "=== Parsed Code Review ==="
          echo ""
          echo "Summary: $(echo '${{ steps.ai.outputs.response }}' | jq -r '.summary')"
          echo "Score: $(echo '${{ steps.ai.outputs.response }}' | jq -r '.score')/10"
          echo ""
          echo "Issues found:"
          echo '${{ steps.ai.outputs.response }}' | jq -r '.issues[] | "  - [\(.severity)] \(.description)"'
          echo ""
          echo "Top suggestion: $(echo '${{ steps.ai.outputs.response }}' | jq -r '.suggestion')"

      - name: Use Score in Conditional
        run: |
          SCORE=$(echo '${{ steps.ai.outputs.response }}' | jq -r '.score')
          if [ "$SCORE" -ge 7 ]; then
            echo "✅ Code quality is good (score: $SCORE)"
          else
            echo "⚠️ Code needs improvement (score: $SCORE)"
          fi

  # Optional: MCP Integration Demo (requires PAT)
  # This job only runs if ENABLE_MCP_DEMO variable is set to 'true'
  mcp-demo:
    name: MCP Demo (Optional)
    runs-on: ubuntu-latest
    if: ${{ vars.ENABLE_MCP_DEMO == 'true' }}
    steps:
      - name: Run AI with Repository Context
        id: mcp-ai
        uses: actions/ai-inference@v1
        with:
          prompt: |
            You have access to this repository's context via MCP.
            The repository is: ${{ github.repository }}
            Please list the open issues in this repository, including their
            numbers and titles. If there are no open issues, say so.
          max-tokens: 500
          enable-github-mcp: true
          github-mcp-token: ${{ secrets.GH_MCP_TOKEN }}
          github-mcp-toolsets: repos,issues,pull_requests

      - name: Display MCP Response
        run: |
          echo "=== AI Response with Repository Context ==="
          echo "${{ steps.mcp-ai.outputs.response }}"
```

</details>
