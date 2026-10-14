/// A single mutation applied to a [`super::Counter`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Operation {
    Add(i64),
    Sub(i64),
    Reset,
}

/// A read-only snapshot describing a counter's current state.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Summary {
    pub value: i64,
    pub operations: u64,
    pub label: String,
}
