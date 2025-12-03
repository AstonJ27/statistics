// src/utils.rs
/// Regla de Sturges: k = ceil(log2(n)) + 1, y devolver impar redondeado
pub fn sturges_bins(n: usize) -> usize {
    if n == 0 {return 1;}
    // Convertir n a f64 para operaciones matemáticas
    let n_f64 = n as f64;

    // Fórmula de Sturges convencional: k = 1 + 3.322 * log10(n)
    let k_f64 = 1.0 + 3.322 * n_f64.log10();

    // Redondear k al entero impar más cercano
    // Usamos round() para el redondeo estándar, no ceil()
    let k = k_f64.round() as usize;

    if k % 2 == 0 { k + 1 } else { k }
}

/// Safe clamp index calculation
pub fn bin_index(value: f64, minv: f64, width: f64, nbins: usize) -> usize {
    if width <= 0.0 || nbins == 0 { return 0; }

    let raw = (value - minv) / width;

    let mut idx = if raw < 0.0 {
        0
    } else {
        raw.floor() as usize
    };

    //let max_index = nbins.saturating_sub(1);
    //-- correccion 
    if idx >= nbins {        //max index
        idx = nbins -1;     //max index
    }
    
    idx
}
