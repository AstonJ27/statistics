// src/sampling/distributions.rs
use rand::Rng;
use rand_distr::{Normal, Poisson, Binomial, Exp, Distribution};

pub fn uniform_sample<R: Rng + ?Sized>(rng: &mut R) -> f64 {
    rng.gen::<f64>()
}

//pub fn exponential_inverse_sample<R: Rng + ?Sized>(rng: &mut R, beta: f64) -> f64 {
//    // Using inverse transform
//    let u: f64 = rng.gen::<f64>();
//    -beta * (1.0 - u).ln()
//}

// Exponential distribution sample using rand_distr's Exp (for optional use)
pub fn exponential_inverse_sample<R: Rng + ?Sized>(rng: &mut R, lambda: f64) -> f64 {
    // Uses the library's optimized version of the Exponential distribution
    let d = Exp::new(lambda).unwrap();
    d.sample(rng)
}

/// PDF and CDF helpers can go here if needed for theoretical curve plotting.
/// For now implement thin wrappers used by generator when necessary.
pub fn normal_sample<R: Rng + ?Sized>(rng: &mut R, mean: f64, std: f64) -> f64 {
    let d = Normal::new(mean, std).unwrap();
    d.sample(rng)
}



// Poisson / Binomial wrappers (for discrete)
pub fn poisson_sample<R: Rng + ?Sized>(rng: &mut R, lambda: f64) -> u64 {
    let d = Poisson::new(lambda).unwrap();
    d.sample(rng) as u64
}

// Binomial wrapper (for discrete)
pub fn binomial_sample<R: Rng + ?Sized>(rng: &mut R, n: u64, p: f64) -> u64 {
    // Uses the library's Binomial implementation
    let d = Binomial::new(n, p).unwrap();
    d.sample(rng)
}