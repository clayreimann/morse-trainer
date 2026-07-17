# Pause-Driven Keying Design

## Goal

Grade a keyed Morse letter only after the learner pauses, and keep successfully keyed letters visibly green.

## Behavior

- Every dot or dash entered before the existing settle pause belongs to one letter attempt.
- An exact match does not complete early. For example, when `E` (`·`) is expected, entering `·` remains pending so the learner can continue with `··` or `·−`.
- An overlong sequence does not fail early. Correct, incorrect, incomplete, and overlong attempts all remain pending until the same settle pause.
- When the settle pause expires, the complete buffered sequence is compared with the expected Morse code and timing gate. A match advances; any mismatch reports an error without advancing.
- A pause with an empty buffer remains a no-op.
- Completed letters render green through the shared `LetterRow` component. The current letter continues to use the selected accent, and remaining letters remain gray.

## Implementation

`SenderEngine.consumeTimed` will only append elements and their optional press timings. `SenderEngine.flushLetter` remains the single grading boundary and calls the existing evaluation logic. The Learn/Send coordinator will continue resetting its settle debounce on every key event, so uninterrupted input remains one attempt regardless of length.

`LetterRow.color(for:)` will return green for indices before `completedCount`. Because keying progress is centralized in this shared component, the color behavior applies wherever `LetterRow` is used.

## Tests

Update the sender tests to prove that:

- an exact match remains pending until `flushLetter()`;
- a multi-element exact match remains pending until `flushLetter()`;
- an overlong attempt remains pending until `flushLetter()`, then fails;
- an incorrect attempt still fails on `flushLetter()`;
- an empty flush remains a no-op;
- full-word progression still succeeds when each letter is flushed.

Run the complete Swift package test suite after the focused sender tests.
