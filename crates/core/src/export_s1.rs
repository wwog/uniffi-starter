//! `ExportS1` — a struct that exercises **every** type UniFFI can carry across
//! the FFI boundary, plus the nested shapes it needs.
//!
//! Everything here is plain Rust: no `uniffi` dependency, no derives from it.
//! The adapter crate (`starter-uniffi`) mirrors these shapes with
//! `#[uniffi::remote]` and that is what actually reaches Kotlin/Swift/etc.

use std::collections::HashMap;
use std::time::{Duration, SystemTime};

/// A nested record. Also a plain Rust struct.
#[derive(Debug, Clone, PartialEq)]
pub struct Child {
    pub id: u32,
    pub label: String,
}

impl Child {
    pub fn new(id: u32, label: impl Into<String>) -> Self {
        Self {
            id,
            label: label.into(),
        }
    }
}

/// An enum with data-carrying variants. UniFFI supports both fieldless and
/// associated-data variants; both map cleanly onto Kotlin sealed classes,
/// Swift enums-with-payload, and Python enums.
#[derive(Debug, Clone, PartialEq)]
pub enum Color {
    Red,
    Green,
    Blue { shade: u8 },
}

/// Every UniFFI-supported builtin type, in one struct.
///
/// Grouped to make the coverage obvious:
///
/// | Group | Field(s) |
/// |-------|----------|
/// | `bool` | `flag` |
/// | signed ints | `i8_v`, `i16_v`, `i32_v`, `i64_v` |
/// | unsigned ints | `u8_v`, `u16_v`, `u32_v`, `u64_v` |
/// | floats | `f32_v`, `f64_v` |
/// | string | `text` |
/// | bytes | `data` (`Vec<u8>` is UniFFI's byte buffer) |
/// | optional | `maybe` |
/// | sequence | `tags` |
/// | map | `scores` |
/// | timestamp | `created_at` (`SystemTime`) |
/// | duration | `ttl` |
/// | nested record / enum | `child`, `color` |
/// | collections of records | `children`, `by_name`, `maybe_child` |
#[derive(Debug, Clone, PartialEq)]
pub struct ExportS1 {
    // bool
    pub flag: bool,

    // signed integers
    pub i8_v: i8,
    pub i16_v: i16,
    pub i32_v: i32,
    pub i64_v: i64,

    // unsigned integers
    pub u8_v: u8,
    pub u16_v: u16,
    pub u32_v: u32,
    pub u64_v: u64,

    // floats
    pub f32_v: f32,
    pub f64_v: f64,

    // string and bytes
    pub text: String,
    pub data: Vec<u8>,

    // optional / sequence / map
    pub maybe: Option<String>,
    pub tags: Vec<String>,
    pub scores: HashMap<String, i64>,

    // time
    pub created_at: SystemTime,
    pub ttl: Duration,

    // nested record + enum
    pub child: Child,
    pub color: Color,

    // collections of nested records
    pub children: Vec<Child>,
    pub by_name: HashMap<String, Child>,
    pub maybe_child: Option<Child>,
}

impl ExportS1 {
    /// A populated instance, used by tests and the demo apps.
    pub fn sample() -> Self {
        let mut scores = HashMap::new();
        scores.insert("alice".to_string(), 10);
        scores.insert("bob".to_string(), -3);

        let mut by_name = HashMap::new();
        by_name.insert("first".to_string(), Child::new(1, "one"));
        by_name.insert("second".to_string(), Child::new(2, "two"));

        Self {
            flag: true,
            i8_v: -8,
            i16_v: -16,
            i32_v: -32,
            i64_v: -64,
            u8_v: 8,
            u16_v: 16,
            u32_v: 32,
            u64_v: 64,
            f32_v: 3.5,
            f64_v: 7.25,
            text: "hello from Rust".to_string(),
            data: vec![0xde, 0xad, 0xbe, 0xef],
            maybe: Some("present".to_string()),
            tags: vec!["a".to_string(), "b".to_string(), "c".to_string()],
            scores,
            created_at: SystemTime::UNIX_EPOCH + Duration::from_secs(1_700_000_000),
            ttl: Duration::from_secs(90),
            child: Child::new(42, "child"),
            color: Color::Blue { shade: 7 },
            children: vec![Child::new(1, "one"), Child::new(2, "two")],
            by_name,
            maybe_child: Some(Child::new(99, "maybe")),
        }
    }

    /// Round-trip a value through the core logic. Used to prove the FFI layer
    /// carries every field intact.
    pub fn touch(self) -> Self {
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sample_is_fully_populated() {
        let s = ExportS1::sample();
        assert!(s.flag);
        assert_eq!(s.i64_v, -64);
        assert_eq!(s.u64_v, 64);
        assert_eq!(s.data, vec![0xde, 0xad, 0xbe, 0xef]);
        assert_eq!(s.tags.len(), 3);
        assert_eq!(s.scores["alice"], 10);
        assert_eq!(s.child.id, 42);
        assert_eq!(s.color, Color::Blue { shade: 7 });
        assert_eq!(s.by_name["second"].label, "two");
        assert!(s.maybe_child.is_some());
    }

    #[test]
    fn round_trips_through_touch() {
        let s = ExportS1::sample();
        assert_eq!(s.clone().touch(), s);
    }
}
