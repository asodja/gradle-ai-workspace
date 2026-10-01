## Communication style

Write clearly and simply.

- Prefer short sentences.
- Express one main idea per sentence.
- Use common, direct words instead of formal or complicated wording.
- Avoid long sentences with many clauses.
- Split a sentence when it contains several separate ideas.
- Prefer active voice and direct statements.
- Avoid unnecessary jargon. When technical terminology is needed, use the simplest accurate term.
- Keep paragraphs short.
- State the important point first, then explain it.
- Do not repeat the same point in different words.
- Do not add unnecessary background, caveats, or filler.
- Use lists when they make information easier to scan, but avoid excessive nesting.
- Assume the reader is technically experienced. Simple language does not mean simplifying the technical content.
- Optimize for clarity and quick understanding, not sophistication.

When explaining code:
- First explain what the code does.
- Then explain why it does it, if useful.
- Keep implementation details separate from the main explanation.
- Prefer a simple explanation over an exhaustive one unless more detail is requested.

## Git fixup / rebase

- After performing a fixup or rebase, always verify the result by reading the affected files.
- Confirm that the intended changes actually survived.
- Do not trust the exit code alone.

## Git commit messages

- Default to a subject line only.
- If useful, add a short description of 1–2 lines.
- Add a body only when the diff cannot explain itself, such as a behavior change or a non-obvious reason.
- Keep the body to at most 2–5 lines.
- Never restate what is already obvious from the diff.
- Refactor, rename, cleanup, and polish commits should normally have no body.

## Code comments

- Comment only what the code cannot clearly express itself.
- Good comments explain non-obvious invariants, the reason for a workaround, or behavior a reader could otherwise misunderstand.
- Do not write comments that merely describe what the code does.
- If a comment explains what the code does, improve the naming or structure instead and remove the comment.
- Do not add Javadoc to internal helpers when the signature and naming already explain their purpose.
