//! Tiny dense MLP (ReLU hidden, linear logits) with masked softmax
//! cross-entropy and Adam. Gradients are summed over a fixed number of chunks
//! in a fixed order, so results do not depend on thread scheduling.
use crate::sim::N_ACTIONS;

pub struct Mlp {
    pub sizes: Vec<usize>,
    pub params: Vec<f64>,
}

fn layer_offsets(sizes: &[usize]) -> Vec<usize> {
    let mut off = vec![0];
    for l in 0..sizes.len() - 1 {
        let last = *off.last().unwrap();
        off.push(last + sizes[l] * sizes[l + 1] + sizes[l + 1]);
    }
    off
}

impl Mlp {
    pub fn new(sizes: Vec<usize>, rng: &mut crate::rng::Rng) -> Mlp {
        let off = layer_offsets(&sizes);
        let mut params = vec![0.0; *off.last().unwrap()];
        for l in 0..sizes.len() - 1 {
            let (i, o) = (sizes[l], sizes[l + 1]);
            let scale = (2.0 / i as f64).sqrt();
            for k in 0..i * o {
                // Irwin-Hall approximation of a normal draw: deterministic, simple.
                let g = (0..4).map(|_| rng.unit()).sum::<f64>() - 2.0;
                params[off[l] + k] = g * scale * 0.866;
            }
        }
        Mlp { sizes, params }
    }

    pub fn param_count(&self) -> usize {
        self.params.len()
    }

    /// Forward pass storing activations (acts[0] = input).
    fn forward_into(&self, x: &[f32], acts: &mut [Vec<f64>]) {
        let off = layer_offsets(&self.sizes);
        for (k, v) in x.iter().enumerate() {
            acts[0][k] = *v as f64;
        }
        let layers = self.sizes.len() - 1;
        for l in 0..layers {
            let (i, o) = (self.sizes[l], self.sizes[l + 1]);
            let w = &self.params[off[l]..off[l] + i * o];
            let b = &self.params[off[l] + i * o..off[l + 1]];
            let (prev, next) = acts.split_at_mut(l + 1);
            let input = &prev[l];
            for r in 0..o {
                let mut s = b[r];
                for c in 0..i {
                    s += w[r * i + c] * input[c];
                }
                next[0][r] = if l + 1 < layers && s <= 0.0 { 0.0 } else { s };
            }
        }
    }

    /// Accumulates gradients of masked cross-entropy; returns (loss, correct).
    pub fn grad(
        &self,
        xs: &[f32],
        ys: &[u8],
        masks: &[u8],
        class_weight: &[f64; N_ACTIONS],
        idx: &[usize],
        g: &mut [f64],
    ) -> (f64, usize) {
        let off = layer_offsets(&self.sizes);
        let n_in = self.sizes[0];
        let layers = self.sizes.len() - 1;
        let mut acts: Vec<Vec<f64>> = self.sizes.iter().map(|&s| vec![0.0; s]).collect();
        let mut delta: Vec<Vec<f64>> = self.sizes.iter().map(|&s| vec![0.0; s]).collect();
        let (mut loss, mut correct) = (0.0, 0);
        for &k in idx {
            self.forward_into(&xs[k * n_in..(k + 1) * n_in], &mut acts);
            let z = &acts[layers];
            let m = masks[k];
            let y = ys[k] as usize;
            let mut mx = f64::NEG_INFINITY;
            let mut arg = 0;
            for a in 0..N_ACTIONS {
                if m & (1 << a) != 0 && z[a] > mx {
                    mx = z[a];
                    arg = a;
                }
            }
            correct += (arg == y) as usize;
            let mut sum = 0.0;
            for a in 0..N_ACTIONS {
                if m & (1 << a) != 0 {
                    sum += (z[a] - mx).exp();
                }
            }
            let cw = class_weight[y];
            loss += -(z[y] - mx - sum.ln()) * cw;
            for a in 0..N_ACTIONS {
                delta[layers][a] = if m & (1 << a) != 0 {
                    cw * ((z[a] - mx).exp() / sum - if a == y { 1.0 } else { 0.0 })
                } else {
                    0.0
                };
            }
            for l in (0..layers).rev() {
                let (i, o) = (self.sizes[l], self.sizes[l + 1]);
                for r in 0..o {
                    let d = delta[l + 1][r];
                    if d == 0.0 {
                        continue;
                    }
                    for c in 0..i {
                        g[off[l] + r * i + c] += d * acts[l][c];
                    }
                    g[off[l] + i * o + r] += d;
                }
                if l > 0 {
                    for c in 0..i {
                        let mut s = 0.0;
                        for r in 0..o {
                            s += self.params[off[l] + r * i + c] * delta[l + 1][r];
                        }
                        delta[l][c] = if acts[l][c] > 0.0 { s } else { 0.0 };
                    }
                }
            }
        }
        (loss, correct)
    }
}

pub struct Adam {
    m: Vec<f64>,
    v: Vec<f64>,
    t: i32,
    pub lr: f64,
}

impl Adam {
    pub fn new(n: usize, lr: f64) -> Adam {
        Adam {
            m: vec![0.0; n],
            v: vec![0.0; n],
            t: 0,
            lr,
        }
    }
    pub fn step(&mut self, p: &mut [f64], g: &[f64], scale: f64) {
        self.t += 1;
        let (b1, b2) = (0.9f64, 0.999f64);
        let c1 = 1.0 - b1.powi(self.t);
        let c2 = 1.0 - b2.powi(self.t);
        for k in 0..p.len() {
            let gk = g[k] * scale;
            self.m[k] = b1 * self.m[k] + (1.0 - b1) * gk;
            self.v[k] = b2 * self.v[k] + (1.0 - b2) * gk * gk;
            p[k] -= self.lr * (self.m[k] / c1) / ((self.v[k] / c2).sqrt() + 1e-8);
        }
    }
}

/// Reference inference over exported float32 weights, accumulating in f64 in
/// the exact order the Dart evaluator uses (bias, then inputs left to right).
pub fn reference_forward(sizes: &[usize], w: &[f32], x: &[f64]) -> Vec<f64> {
    let mut values: Vec<f64> = x.to_vec();
    let mut off = 0;
    let layers = sizes.len() - 1;
    for l in 0..layers {
        let (i, o) = (sizes[l], sizes[l + 1]);
        let mut next = vec![0.0; o];
        for r in 0..o {
            let mut s = w[off + i * o + r] as f64;
            for c in 0..i {
                s += w[off + r * i + c] as f64 * values[c];
            }
            next[r] = if l + 1 < layers && !(s > 0.0) { 0.0 } else { s };
        }
        off += i * o + o;
        values = next;
    }
    values
}

pub fn masked_argmax(logits: &[f64], m: &[bool]) -> usize {
    let mut best = usize::MAX;
    for a in 0..logits.len() {
        if m[a] && (best == usize::MAX || logits[a] > logits[best]) {
            best = a;
        }
    }
    if best == usize::MAX {
        0
    } else {
        best
    }
}
