# 5 - Custom actions
In this lab you will create and use custom actions.
> Duration: 15-20 minutes

References:
- [Creating actions](https://docs.github.com/en/actions/creating-actions)
- [Creating a composite action](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Creating a JavaScript action](https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)
- [GitHub Actions Toolkit](https://github.com/actions/toolkit)
- [actions/github-script](https://github.com/actions/github-script)

## 5.1 Use the github-script action to apply a label to an issue

1. Open the workflow file [github-script.yml](/.github/workflows/github-script.yml)
2. Edit the file and copy the following YAML content at the end of the file:
```YAML
  apply-label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.addLabels({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: ['Training']
            })
```
3. Commit the changes into the `main` branch
4. Open a new issue or edit an exiting one to trigger the workflow. If the `Issues` tab is not visible, open your repository settings and enable it.
5. Go to `Actions` and see the details of your running workflow
6. After the workflow completes, a new label should be applied to your issue

## 5.2 Use a composite action

1. Open the composite action file [/.github/actions/hello-world-composite-action/action.yml](/.github/actions/hello-world-composite-action/action.yml)
2. Edit the file and copy the following YAML content at the end of the file:
```YAML
    - name: Hello world
      uses: actions/hello-world-javascript-action@main
      with:
        who-to-greet: "${{ inputs.who-to-greet }}"
      id: hello
    - name: Echo the greeting's time
      run: echo 'The time was ${{ steps.hello.outputs.time }}.'
      shell: bash
```
3. Commit the changes into a new `feature/lab05` branch
4. Open the workflow file [hello-world-composite.yml](/.github/workflows/hello-world-composite.yml)
5. Edit the file and copy the following YAML content at the end of the file:
```YAML
  hello_world_job2:
    runs-on: ubuntu-latest
    name: A job2 to say hello
    steps:
      - uses: actions/checkout@v4
      - id: hello-world
        uses: ./.github/actions/hello-world-composite-action
        with:
          who-to-greet: 'Mona the Octocat from composite action'
      - run: echo random-number from composite action ${{ steps.hello-world.outputs.random-number }}
        shell: bash
```
6. Update the workflow to run on pull_request events
```YAML
on:
  pull_request:
     branches: [main]
  workflow_dispatch:    
```
7. Commit the changes into the same `feature/lab05` branch
8. Open a new pull request
9. Go to `Actions` and see the details of your running workflow
10. Complete the pull request and delete the source branch

## 5.3 Custom JS and Docker actions - Troubleshooting Exercise

In this exercise, you'll encounter a **real-world debugging scenario**: an external API that the workflow depends on has become unreliable or broken. Your task is to diagnose the failure and implement a fix.

### Part 1: Trigger the Workflow and Observe the Failure

1. Open the workflow file [use-custom-actions.yml](/.github/workflows/use-custom-actions.yml)
2. Edit the file and copy the following YAML content to update the issue title:
```YAML
         issue-title: "A joke for you from custom actions workflow"
```
3. Commit the changes into the `main` branch
4. Go to `Actions` and manually trigger the workflow by clicking on `Run Workflow` button
5. **Observe the failure** - the `docker-custom-actions` job will likely fail at the `meow` step

### Part 2: Diagnose the Problem

Now practice your debugging skills:

1. Click on the failed workflow run to see the details
2. Expand the failed step to see the error message
3. Look at the action being called: [/.github/actions/cat-facts/](/.github/actions/cat-facts/)
4. Examine the source code in `src/main.py` - what API endpoint is it calling?
5. Try accessing that API directly in your browser - does it respond?

<details>
<summary>Hint: What to look for</summary>

The `cat-facts` action calls an external API. External APIs can:
- Go offline permanently
- Change their response format
- Become rate-limited or require authentication
- Have intermittent availability

Check the API URL in `src/main.py` and test it directly.
</details>

### Part 3: Research and Fix

Once you've identified that the API is the problem:

1. Search for "cat facts API" to find a working alternative
2. A reliable option is `https://catfact.ninja/fact` which returns:
```json
{
  "fact": "A cat fact here...",
  "length": 42
}
```
3. Update the `src/main.py` file to use the new API:
   - Change the API URL
   - Update the JSON parsing to match the new response format (single fact object instead of array)
4. Update the `action.yml` to reflect the new API in its description
5. Commit your changes and re-run the workflow

<details>
<summary>Hint: Key differences in the new API</summary>

The original API returned an array of facts requiring random selection.
The new API (`catfact.ninja/fact`) returns a **single random fact** directly.

You'll need to:
- Update the URL to `https://catfact.ninja/fact`
- Parse `response.json()["fact"]` directly instead of iterating an array
</details>

### Part 4: Verify the Fix

1. Go to `Actions` and manually trigger the workflow again
2. Verify that both jobs (`js-custom-actions` and `docker-custom-actions`) pass
3. Check that a new issue was created with a cat fact

## 5.4 (Optional) Create a JavaScript action
1. Follow the guide to create a JavaScript action
    - [Creating a JavaScript action](https://docs.github.com/en/actions/creating-actions/creating-a-javascript-action)
2. Use your action in a workflow
```YAML
      - name: Hello world action step
        id: hello
        uses: <YOUR-USER-ACCOUNT>/hello-world-javascript-action@v1.1
        with:
            who-to-greet: 'Mona the Octocat'
```

## 5.5 Final
<details>
  <summary>github-script.yml</summary>

```YAML
name: 05-1. GitHub Script - Thank you
on:
  issues:
    types: [opened, edited, reopened, labeled]

# Limit the permissions of the GITHUB_TOKEN
permissions:
  contents: read
  issues: write

jobs:
  comment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{secrets.GITHUB_TOKEN}}
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '👋 Thank you! We appreciate your contribution to this project.'
            })
  apply-label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.addLabels({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              labels: ['Training']
            })
```
</details>

<details>
  <summary>hello-world-composite-action/action.yml</summary>

```YAML
name: 'Hello World Composite Action'
description: 'Greet someone'
inputs:
  who-to-greet:  # id of input
    description: 'Who to greet'
    required: true
    default: 'World'
outputs:
  random-number:
    description: "Random number"
    value: ${{ steps.random-number-generator.outputs.random-id }}
runs:
  using: "composite"
  steps:
    - run: echo Hello from composite action ${{ inputs.who-to-greet }}.
      shell: bash
    - id: random-number-generator
      run: echo "random-id=$(echo $RANDOM)" >> $GITHUB_OUTPUT
      shell: bash
    - run: echo "${{ github.action_path }}" >> $GITHUB_PATH
      shell: bash
    - name: Hello world
      uses: actions/hello-world-javascript-action@main
      with:
        who-to-greet: "${{ inputs.who-to-greet }}"
      id: hello
    - name: Echo the greeting's time
      run: echo 'The time was ${{ steps.hello.outputs.time }}.'
      shell: bash

```
</details>

<details>
  <summary>hello-world-composite.yml</summary>

```YAML
name: 05-2. Hello World Composite

on:
  pull_request:
     branches: [main]
  workflow_dispatch:

jobs:
  hello_world_job1:
    runs-on: ubuntu-latest
    name: A job1 to say hello
    steps:
      - id: hello-world
        uses: githubabcs/hello-world-composite-action@main
        with:
          who-to-greet: 'Hello from GH ABCs'
      - run: echo random-number ${{ steps.hello-world.outputs.random-number }}
        shell: bash
  hello_world_job2:
    runs-on: ubuntu-latest
    name: A job2 to say hello
    steps:
      - uses: actions/checkout@v4
      - id: hello-world
        uses: ./.github/actions/hello-world-composite-action
        with:
          who-to-greet: 'Mona the Octocat from composite action'
      - run: echo random-number from composite action ${{ steps.hello-world.outputs.random-number }}
        shell: bash
```
</details>

<details>
  <summary>use-custom-actions.yml</summary>

```YAML
name: 05-3. Use Custom Actions (JS & Doker)

on:
  pull_request:
    types: [labeled]
  workflow_dispatch:

# Limit the permissions of the GITHUB_TOKEN
permissions:
  contents: read
  issues: write

jobs:

  js-custom-actions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - run: echo "🎉 Running the JS actions"

      - name: hello-action
        uses: ./.github/actions/hello-world-js
        if: ${{ success() }}

      - name: ha-ha
        uses: ./.github/actions/joke-action
        id: jokes

      - name: create-issue
        uses: ./.github/actions/issue-maker-js
        with:
          repo-token: ${{secrets.GITHUB_TOKEN}}
          joke: ${{steps.jokes.outputs.joke-output}}
          issue-title: "A joke for you from custom actions workflow"

  docker-custom-actions:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - run: echo "🎉 Running the Docker actions"

      - name: hello-action
        uses: ./.github/actions/hello-world-docker

      - name: meow
        uses: ./.github/actions/cat-facts
        id: cat

      - name: create-issue
        uses: ./.github/actions/issue-maker-docker
        with:
          repoToken: ${{secrets.GITHUB_TOKEN}}
          catFact: ${{steps.cat.outputs.fact}}
          issueTitle: "A cat fact for you from ${{ github.repository_owner }}"

```
</details>

<details>
  <summary>cat-facts/action.yml (Fixed)</summary>

```YAML
name: "my cat fact action"

description: "Get external data with GitHub Actions"

outputs:
  fact:
    description: Resulting cat fact from the https://catfact.ninja/fact API

runs:
  using: "docker"
  image: "Dockerfile"
```
</details>

<details>
  <summary>cat-facts/src/main.py (Fixed)</summary>

```python
import requests
import os

# Make an HTTP GET request to the cat-fact API
cat_url = "https://catfact.ninja/fact"
r = requests.get(cat_url)
r_obj = r.json()

# Get the fact directly from the response
random_fact = r_obj["fact"]

# Print the cat fact
print(random_fact)

# Set the fact output of the action using GITHUB_OUTPUT
with open(os.environ['GITHUB_OUTPUT'], 'a') as f:
    f.write(f"fact={random_fact}\n")
```
</details>