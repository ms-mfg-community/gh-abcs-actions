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

## 8.4 Final

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
```

</details>
