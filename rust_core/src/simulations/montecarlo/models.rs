use serde::{Deserialize, Serialize};

#[derive(Deserialize, Clone)]
pub enum DistType {
    Normal { mean: f64, std: f64 },
    Exponential { beta: f64 }, // Beta = Media = 1/Lambda
    Uniform { min: f64, max: f64 },
}

#[derive(Deserialize, Clone)]
pub struct VariableConfig {
    pub name: String,
    pub distribution: DistType,
    pub multiplier: f64, // 1.0 para sumar, -1.0 para restar
}

#[derive(Deserialize)]
#[serde(tag = "mode_type", content = "params")]
pub enum AnalysisMode {
    Aggregation, // Solo sumar (Problema 1)
    Probability { // Evaluar condición (Problema 2)
        threshold: f64,
        operator: String, // "<", "<=", ">", ">="
        cost_per_event: f64,
        population_size: f64,
    }
}

#[derive(Deserialize)]
pub struct MonteCarloConfig {
    pub n_simulations: usize,
    pub variables: Vec<VariableConfig>,
    pub analysis: AnalysisMode,
}

#[derive(Serialize)]
pub struct MonteCarloResponse {
    pub iterations: usize,
    pub mean: f64,
    pub std_dev: f64,
    pub min: f64,
    pub max: f64,
    pub samples_preview: Vec<f64>,
    pub success_count: Option<usize>,
    pub probability: Option<f64>,
    pub expected_cost: Option<f64>,
}