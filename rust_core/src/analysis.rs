use crate::json_helpers::to_cstring;
use crate::utils; // Usaremos esto para el índice seguro
use crate::errors::Error;
use std::slice;
use serde_json::json;
use std::f64::consts::PI;
use std::collections::{HashMap, BTreeMap};

pub fn analyze_distribution_json(ptr: *const f64, len: usize, h_round: bool) -> Result<*mut libc::c_char, Error> {
    if crate::ffi::check_ptr_len(ptr, len) == false { return Err(Error::NullOrEmptyInput); }
    
    unsafe {
        // 1. Preparar datos (Clonar y Ordenar es necesario para mediana y cuantiles)
        let mut data_slice = slice::from_raw_parts(ptr, len).to_vec();
        data_slice.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
        
        let n = data_slice.len();
        if n == 0 { return Err(Error::NullOrEmptyInput); }
        let n_f64 = n as f64;

        // --- ESTADÍSTICAS BÁSICAS ---
        let mut sum = 0.0f64;
        let mut minv = f64::MAX;
        let mut maxv = f64::MIN;
        
        for &x in data_slice.iter() {
            sum += x;
            if x < minv { minv = x; }
            if x > maxv { maxv = x; }
        }
        let mean = sum / n_f64;

        // --- MOMENTOS (Varianza, Skewness, Kurtosis) ---
        let mut m2 = 0.0;
        let mut m3 = 0.0;
        let mut m4 = 0.0;

        for &x in data_slice.iter() {
            let d = x - mean;
            let d2 = d * d;
            m2 += d2;
            m3 += d2 * d;
            m4 += d2 * d2;
        }

        let variance_pop = m2 / n_f64;
        let variance_sample = if n > 1 { m2 / (n_f64 - 1.0) } else { 0.0 };
        let std_sample = variance_sample.sqrt();

        // Skewness
        let skewness = if m2 == 0.0 { 0.0 } else { (n_f64 * m3) / m2.powf(1.5) };
        // Kurtosis Excess
        let kurtosis_excess = if m2 == 0.0 { -3.0 } else { (n_f64 * m4) / (m2 * m2) - 3.0 };

        // --- MEDIANA ---
        let median = percentile(&data_slice, 0.5);

        // --- MODA (Múltiple) ---
        let mut counts_map: HashMap<i64, usize> = HashMap::new();
        let precision = 10000.0; // Agrupar 4 decimales
        for &x in data_slice.iter() {
            let key = (x * precision).round() as i64;
            *counts_map.entry(key).or_insert(0) += 1;
        }
        let maxc = counts_map.values().cloned().max().unwrap_or(0);
        let mut modes = Vec::new();
        if maxc > 1 { // Solo si hay repetición
            for (&k, &v) in counts_map.iter() {
                if v == maxc {
                    modes.push((k as f64) / precision);
                }
            }
        }
        modes.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));

        // --- BOXPLOT ---
        let q1 = percentile(&data_slice, 0.25);
        let q3 = percentile(&data_slice, 0.75);
        let iqr = q3 - q1;
        let lower_fence = q1 - 1.5 * iqr;
        let upper_fence = q3 + 1.5 * iqr;
        let outliers: Vec<f64> = data_slice.iter().cloned().filter(|&x| x < lower_fence || x > upper_fence).collect();

        // --- STEM & LEAF ---
        let scale = 100.0;  //Escala que indica cuantos digitos guarda una hoja
        let mut stem_map: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
        for &x in data_slice.iter() {
            let scaled = (x * scale).round() as i64;
            let stem = scaled / (scale as i64);
            let leaf = (scaled % (scale as i64)).abs();
            stem_map.entry(stem).or_default().push(leaf);
        }
        let mut stemleaf_out = Vec::with_capacity(stem_map.len());
        for (stem, mut leaves) in stem_map {
            leaves.sort_unstable();
            stemleaf_out.push(json!({"stem": stem, "leaves": leaves}));
        }

        // --- HISTOGRAMA Y TABLA DE FRECUENCIA (Corrección Clave) ---
        // 1. Usar Sturges centralizado
        let mut k = utils::sturges_bins(n);
        if h_round && k % 2 == 0 { k += 1; }

        // 2. Calcular Amplitud
        let range = maxv - minv;
        // Evitar div por cero si range es 0
        let w = if range.abs() < 1e-9 { 1.0 } else { range / (k as f64) };

        // 3. Generar Bordes
        let mut edges: Vec<f64> = Vec::with_capacity(k + 1);
        for i in 0..=k {
            if i == k { edges.push(maxv); } else { edges.push(minv + (i as f64) * w); }
        }
        
        // 4. Centros
        let mut centers: Vec<f64> = Vec::with_capacity(k);
        for i in 0..k {
            centers.push(0.5 * (edges[i] + edges[i+1]));
        }

        // 5. Conteos (Usando utils::bin_index para arreglar el bug del último valor)
        let mut counts: Vec<u32> = vec![0u32; k];
        for &x in data_slice.iter() {
            // AQUÍ ESTÁ EL FIX: Usamos la función segura que maneja x == maxv
            let idx = utils::bin_index(x, minv, w, k);
            counts[idx] += 1;
        }

        // 6. Densidades
        let mut densities: Vec<f64> = Vec::with_capacity(k);
        for &c in counts.iter() { 
            densities.push((c as f64) / (n_f64 * w)); 
        }

        // 7. Filas de la Tabla
        let mut classes = Vec::with_capacity(k);
        let mut cum_abs = 0u32;
        let mut cum_rel = 0.0f64;
        
        for i in 0..k {
            let lower = edges[i];
            let upper = edges[i+1];
            let midpoint = centers[i];
            let abs_f = counts[i];
            cum_abs += abs_f;
            let rel = (abs_f as f64) / n_f64;
            cum_rel += rel;

            classes.push(json!({
                "lower": lower,
                "upper": upper,
                "midpoint": midpoint,
                "abs_freq": abs_f,
                "rel_freq": rel,
                "cum_abs": cum_abs,
                "cum_rel": cum_rel
            }));
        }

        // --- BEST FIT (AIC) ---
        // Parámetros MLE
        let sigma_mle = (variance_pop).sqrt();
        let beta = if minv >= 0.0 { mean } else { f64::NAN };
        
        // LogNormal params
        let positive_data: Vec<f64> = data_slice.iter().cloned().filter(|&x| x > 0.0).collect();
        let (ln_mu, ln_sigma) = if !positive_data.is_empty() {
            let ln_mean = positive_data.iter().map(|v| v.ln()).sum::<f64>() / (positive_data.len() as f64);
            let mut s = 0.0;
            for &x in positive_data.iter() {
                let d = x.ln() - ln_mean;
                s += d*d;
            }
            let ln_std = (s / (positive_data.len() as f64)).sqrt();
            (ln_mean, ln_std)
        } else { (f64::NAN, f64::NAN) };

        // Log Likelihoods
        let ll_norm = ll_normal(&data_slice, mean, sigma_mle);
        let ll_exp = if beta.is_nan() { f64::NEG_INFINITY } else { ll_exponential(&data_slice, beta) };
        let ll_logn = if ln_mu.is_nan() { f64::NEG_INFINITY } else { ll_lognormal(&data_slice, ln_mu, ln_sigma) };
        let ll_unif = ll_uniform(&data_slice, minv, maxv);

        // AIC = 2k - 2ln(L)
        let aic_norm = 4.0 - 2.0 * ll_norm;      // k=2
        let aic_exp = 2.0 - 2.0 * ll_exp;        // k=1
        let aic_logn = 4.0 - 2.0 * ll_logn;      // k=2
        let aic_unif = 4.0 - 2.0 * ll_unif;      // k=2 (a, b)

        let mut fits = vec![
            ("normal", aic_norm, ll_norm, json!({"params":[mean, sigma_mle]})),
            ("exponential", aic_exp, ll_exp, json!({"params":[beta]})),
            ("lognormal", aic_logn, ll_logn, json!({"params":[ln_mu, ln_sigma]})),
            ("uniform", aic_unif, ll_unif, json!({"params":[minv, maxv]})),
        ];
        fits.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));
        
        let best = &fits[0];
        let best_name = best.0;
        let best_aic = best.1;
        let best_ll = best.2;
        let best_params = best.3.clone();

        // Curvas esperadas para el Best Fit
        let mut expected_counts: Vec<f64> = vec![0.0; k];
        // Calcular CDF en bordes para frequencia esperada
        let mut cdf_vals: Vec<f64> = Vec::with_capacity(k+1);
        for &edge in edges.iter() {
            let v = match best_name {
                "normal" => normal_cdf(edge, mean, sigma_mle),
                "exponential" => exponential_cdf(edge, beta),
                "lognormal" => lognormal_cdf(edge, ln_mu, ln_sigma),
                "uniform" => uniform_cdf(edge, minv, maxv),
                _ => 0.0,
            };
            cdf_vals.push(v);
        }
        for i in 0..k {
            let p = (cdf_vals[i+1] - cdf_vals[i]).max(0.0);
            expected_counts[i] = p * n_f64;
        }

        // Curvas para graficar (Plotting)
        let mpoints = 100usize;
        let mut x_plot: Vec<f64> = Vec::with_capacity(mpoints);
        let mut best_freq: Vec<f64> = Vec::with_capacity(mpoints);
        
        for i in 0..mpoints {
            let t = (i as f64) / ((mpoints - 1) as f64);
            let x = minv + t * (maxv - minv);
            x_plot.push(x);
            
            let pdf = match best_name {
                "normal" => normal_pdf(x, mean, sigma_mle),
                "exponential" => exponential_pdf(x, beta),
                "lognormal" => lognormal_pdf(x, ln_mu, ln_sigma),
                "uniform" => uniform_pdf(x, minv, maxv),
                _ => 0.0
            };
            best_freq.push(pdf * n_f64 * w);
        }

        // --- CONSTRUIR JSON FINAL ---
        let out = json!({
            "summary": {
                "n": n,
                "mean": mean,
                "variance_pop": variance_pop,
                "variance_sample": variance_sample,
                "std_sample": std_sample,
                "median": median,
                "mode": modes,
                "skewness": skewness,
                "kurtosis_excess": kurtosis_excess,
                "min": minv,
                "max": maxv,
                "range": range,
                "k": k,
                "amplitude": w
            },
            "histogram": {
                "k": k,
                "amplitude": w,
                "edges": edges,
                "centers": centers,
                "counts": counts,
                "densities": densities
            },
            "freq_table": {
                "classes": classes,
                "amplitude": w
            },
            "boxplot": {
                "min": minv,
                "q1": q1,
                "median": median,
                "q3": q3,
                "max": maxv,
                "iqr": iqr,
                "lower_fence": lower_fence,
                "upper_fence": upper_fence,
                "outliers": outliers
            },
            "stem_leaf": stemleaf_out,
            "best_fit": {
                "name": best_name,
                "aic": best_aic,
                "ll": best_ll,
                "params": best_params,
                "expected_counts": expected_counts
            },
            "curves": {
                "x": x_plot,
                "best_freq": best_freq
            }
        });

        Ok(to_cstring(&out))
    }
}


// Helper para convertir NaN/Infinity a 0.0 o un valor seguro para JSON
fn sanitize(v: f64) -> f64 {
    if v.is_nan() || v.is_infinite() { 0.0 } else { v }
}

// --- FUNCIONES AUXILIARES PRIVADAS ---

fn percentile(sorted: &Vec<f64>, p: f64) -> f64 {
    let n = sorted.len();
    if n == 0 { return 0.0; }
    let r = p * (n as f64 - 1.0);
    let i = r.floor() as usize;
    let f = r - (i as f64);
    if i + 1 < n { sorted[i] * (1.0 - f) + sorted[i+1] * f } else { sorted[i] }
}

// Log-Likelihood functions
fn ll_normal(data: &Vec<f64>, mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    let log_sigma = sigma.ln();
    let term1 = -0.5 * n * (2.0 * PI).ln();
    let term2 = -n * log_sigma;
    let mut sum_sq = 0.0;
    for &x in data { sum_sq += (x - mu).powi(2); }
    term1 + term2 - sum_sq / (2.0 * sigma * sigma)
}

fn ll_exponential(data: &Vec<f64>, beta: f64) -> f64 {
    if beta <= 0.0 { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    let mut sum = 0.0;
    for &x in data { sum += x; }
    -n * beta.ln() - sum / beta
}

fn ll_lognormal(data: &Vec<f64>, mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    let term1 = -0.5 * n * (2.0 * PI).ln();
    let term2 = -n * sigma.ln();
    let mut sum_log_x = 0.0;
    let mut sum_sq = 0.0;
    for &x in data {
        if x <= 0.0 { return f64::NEG_INFINITY; }
        sum_log_x += x.ln();
        sum_sq += (x.ln() - mu).powi(2);
    }
    term1 + term2 - sum_log_x - sum_sq / (2.0 * sigma * sigma)
}

fn ll_uniform(data: &Vec<f64>, a: f64, b: f64) -> f64 {
    if a >= b { return f64::NEG_INFINITY; }
    let n = data.len() as f64;
    for &x in data { if x < a || x > b { return f64::NEG_INFINITY; } }
    -n * (b - a).ln()
}

// PDF Functions
fn normal_pdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return 0.0; }
    let z = (x - mu) / sigma;
    (1.0 / (sigma * (2.0 * PI).sqrt())) * (-0.5 * z * z).exp()
}
fn exponential_pdf(x: f64, beta: f64) -> f64 {
    if x < 0.0 || beta <= 0.0 { 0.0 } else { (1.0 / beta) * (-x / beta).exp() }
}
fn lognormal_pdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if x <= 0.0 || sigma <= 0.0 { 0.0 } else {
        (1.0 / (x * sigma * (2.0 * PI).sqrt())) * (-0.5 * ((x.ln() - mu) / sigma).powi(2)).exp()
    }
}
fn uniform_pdf(x: f64, a: f64, b: f64) -> f64 {
    if x >= a && x <= b && b > a { 1.0 / (b - a) } else { 0.0 }
}

// CDF Functions (Approximations)
fn normal_cdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if sigma <= 0.0 { return if x >= mu { 1.0 } else { 0.0 }; }
    let z = (x - mu) / (sigma * 2.0_f64.sqrt());
    0.5 * (1.0 + erf_approx(z))
}
fn erf_approx(x: f64) -> f64 {
    // Abramowitz & Stegun 7.1.26
    let a1 =  0.254829592;
    let a2 = -0.284496736;
    let a3 =  1.421413741;
    let a4 = -1.453152027;
    let a5 =  1.061405429;
    let p  =  0.3275911;
    let sign = if x < 0.0 { -1.0 } else { 1.0 };
    let x_abs = x.abs();
    let t = 1.0 / (1.0 + p * x_abs);
    let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * (-x_abs * x_abs).exp();
    sign * y
}
fn exponential_cdf(x: f64, beta: f64) -> f64 {
    if x < 0.0 { 0.0 } else { 1.0 - (-x / beta).exp() }
}
fn lognormal_cdf(x: f64, mu: f64, sigma: f64) -> f64 {
    if x <= 0.0 { 0.0 } else { normal_cdf(x.ln(), mu, sigma) }
}
fn uniform_cdf(x: f64, a: f64, b: f64) -> f64 {
    if x < a { 0.0 } else if x >= b { 1.0 } else { (x - a) / (b - a) }
}