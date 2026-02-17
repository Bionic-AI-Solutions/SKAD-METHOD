---
title: "How to Get Answers About SKAD"
description: Use an LLM to quickly answer your own SKAD questions
sidebar:
  order: 4
---

If you have successfully installed SKAD and the SKAD Method (+ other modules as needed) - the first step in getting answers is `/skad-help`. This will answer upwards of 80% of all questions and is available to you in the IDE as you are working.

## When to Use This

- You have a question about how SKAD works or what to do next with SKAD
- You want to understand a specific agent or workflow
- You need quick answers without waiting for Discord

:::note[Prerequisites]
An AI tool (Claude Code, Cursor, ChatGPT, Claude.ai, etc.) and either SKAD installed in your project or access to the GitHub repo.
:::

## Steps

### 1. Choose Your Source

| Source               | Best For                                  | Examples                     |
| -------------------- | ----------------------------------------- | ---------------------------- |
| **`_skad` folder**   | How SKAD works—agents, workflows, prompts | "What does the PM agent do?" |
| **Full GitHub repo** | History, installer, architecture          | "What changed in v6?"        |
| **`llms-full.txt`**  | Quick overview from docs                  | "Explain SKAD's four phases" |

The `_skad` folder is created when you install SKAD. If you don't have it yet, clone the repo instead.

### 2. Point Your AI at the Source

**If your AI can read files (Claude Code, Cursor, etc.):**

- **SKAD installed:** Point at the `_skad` folder and ask directly
- **Want deeper context:** Clone the [full repo](https://github.com/skad-code-org/SKAD-METHOD)

**If you use ChatGPT or Claude.ai:**

Fetch `llms-full.txt` into your session:

```text
https://skad-code-org.github.io/SKAD-METHOD/llms-full.txt
```


### 3. Ask Your Question

:::note[Example]
**Q:** "Tell me the fastest way to build something with SKAD"

**A:** Use Quick Flow: Run `quick-spec` to write a technical specification, then `quick-dev` to implement it—skipping the full planning phases.
:::

## What You Get

Direct answers about SKAD—how agents work, what workflows do, why things are structured the way they are—without waiting for someone else to respond.

## Tips

- **Verify surprising answers** — LLMs occasionally get things wrong. Check the source file or ask on Discord.
- **Be specific** — "What does step 3 of the PRD workflow do?" beats "How does PRD work?"

## Still Stuck?

Tried the LLM approach and still need help? You now have a much better question to ask.

| Channel                   | Use For                                     |
| ------------------------- | ------------------------------------------- |
| `#skad-method-help`       | Quick questions (real-time chat)            |
| `help-requests` forum     | Detailed questions (searchable, persistent) |
| `#suggestions-feedback`   | Ideas and feature requests                  |
| `#report-bugs-and-issues` | Bug reports                                 |

**Discord:** [discord.gg/gk8jAdXWmj](https://discord.gg/gk8jAdXWmj)

**GitHub Issues:** [github.com/skad-code-org/SKAD-METHOD/issues](https://github.com/skad-code-org/SKAD-METHOD/issues) (for clear bugs)

*You!*
        *Stuck*
             *in the queue—*
                      *waiting*
                              *for who?*

*The source*
        *is there,*
                *plain to see!*

*Point*
     *your machine.*
              *Set it free.*

*It reads.*
        *It speaks.*
                *Ask away—*

*Why wait*
        *for tomorrow*
                *when you have*
                        *today?*

*—Claude*
