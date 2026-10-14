use crate::error::Error;
use crate::model::{Operation, Summary};

/// A stateful counter with a bounded history.
///
/// This is the "object" that the UniFFI adapter exposes as an interface with
/// methods. All arithmetic is checked so callers get a typed [`Error`] instead
/// of a panic.
#[derive(Debug, Default)]
pub struct Counter {
    value: i64,
    operations: u64,
    label: String,
}

impl Counter {
    /// Create a counter starting at `start`.
    pub fn new(start: i64) -> Self {
        Self {
            value: start,
            operations: 0,
            label: String::new(),
        }
    }

    /// Current value.
    pub fn value(&self) -> i64 {
        self.value
    }

    /// Apply an [`Operation`], returning the new value.
    pub fn apply(&mut self, op: Operation) -> Result<i64, Error> {
        match op {
            Operation::Add(delta) => {
                self.value = self
                    .value
                    .checked_add(delta)
                    .ok_or(Error::Overflow {
                        lhs: self.value,
                        rhs: delta,
                    })?;
            }
            Operation::Sub(delta) => {
                let rhs = -delta;
                self.value = self
                    .value
                    .checked_sub(delta)
                    .ok_or(Error::Overflow {
                        lhs: self.value,
                        rhs,
                    })?;
            }
            Operation::Reset => self.value = 0,
        }
        self.operations += 1;
        Ok(self.value)
    }

    /// Divide the current value, erroring on a zero divisor.
    pub fn divide(&mut self, divisor: i64) -> Result<i64, Error> {
        if divisor == 0 {
            return Err(Error::DivisionByZero);
        }
        self.value /= divisor;
        self.operations += 1;
        Ok(self.value)
    }

    /// Attach a human-readable label.
    pub fn set_label(&mut self, label: String) {
        self.label = label;
    }

    /// Produce a snapshot of the current state.
    pub fn summary(&self) -> Summary {
        Summary {
            value: self.value,
            operations: self.operations,
            label: self.label.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn add_and_reset() {
        let mut c = Counter::new(10);
        assert_eq!(c.apply(Operation::Add(5)).unwrap(), 15);
        assert_eq!(c.apply(Operation::Reset).unwrap(), 0);
        assert_eq!(c.summary().operations, 2);
    }

    #[test]
    fn overflow_is_an_error() {
        let mut c = Counter::new(i64::MAX);
        assert_eq!(
            c.apply(Operation::Add(1)),
            Err(Error::Overflow {
                lhs: i64::MAX,
                rhs: 1
            })
        );
    }

    #[test]
    fn divide_by_zero_is_an_error() {
        let mut c = Counter::new(4);
        assert_eq!(c.divide(0), Err(Error::DivisionByZero));
    }
}
