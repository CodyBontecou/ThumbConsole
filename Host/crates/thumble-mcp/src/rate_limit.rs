use std::time::Instant;

const TOKENS_PER_SECOND: f64 = 10.0;
const BURST_CAPACITY: f64 = 3.0;

#[derive(Debug)]
pub(crate) struct PressRateLimiter {
    tokens: f64,
    last_refill: Instant,
}

impl PressRateLimiter {
    pub(crate) fn new() -> Self {
        Self::new_at(Instant::now())
    }

    fn new_at(now: Instant) -> Self {
        Self {
            tokens: BURST_CAPACITY,
            last_refill: now,
        }
    }

    pub(crate) fn allow(&mut self) -> Result<(), String> {
        self.allow_at(Instant::now())
    }

    fn allow_at(&mut self, now: Instant) -> Result<(), String> {
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + elapsed * TOKENS_PER_SECOND).min(BURST_CAPACITY);
        self.last_refill = now;
        if self.tokens < 1.0 {
            return Err("MCP control press rate limit exceeded; retry shortly".to_owned());
        }
        self.tokens -= 1.0;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn limiter_allows_small_burst_then_refills_at_ten_per_second() {
        let start = Instant::now();
        let mut limiter = PressRateLimiter::new_at(start);
        for _ in 0..3 {
            limiter.allow_at(start).unwrap();
        }
        assert!(limiter.allow_at(start).is_err());
        limiter
            .allow_at(start + Duration::from_millis(100))
            .unwrap();
        assert!(limiter
            .allow_at(start + Duration::from_millis(100))
            .is_err());
        for _ in 0..3 {
            limiter.allow_at(start + Duration::from_secs(1)).unwrap();
        }
        assert!(limiter.allow_at(start + Duration::from_secs(1)).is_err());
    }
}
