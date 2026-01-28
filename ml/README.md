Training pipeline (minimal)

This folder contains a minimal, reproducible training pipeline to fine-tune a small causal language model using Hugging Face Transformers.

Quick start (CPU or GPU):

1. Create and activate a virtualenv:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

2. Install dependencies:

```bash
pip install -r ml/requirements.txt
```

3. Train on the included sample data:

```bash
python ml/train.py --train-file ml/data/sample_train.jsonl --model-name distilgpt2 --output-dir ml/models/distilgpt2-finetuned --epochs 1 --batch-size 2
```

Notes:
- For meaningful results, supply a larger dataset and train on GPU/TPU.
- This pipeline is intentionally small and reproducible; modify `train.py` to adapt tokenization, model, and objective (classification, embedding, RLHF, etc.).
