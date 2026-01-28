#!/usr/bin/env python3
import argparse
from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForCausalLM, Trainer, TrainingArguments, DataCollatorForLanguageModeling


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--train-file", required=True, help="Path to JSONL training file (one JSON object per line with a 'text' field).")
    p.add_argument("--model-name", default="distilgpt2")
    p.add_argument("--output-dir", default="ml_models/out")
    p.add_argument("--epochs", type=int, default=1)
    p.add_argument("--batch-size", type=int, default=2)
    p.add_argument("--max-length", type=int, default=128)
    return p.parse_args()


def main():
    args = parse_args()

    dataset = load_dataset("json", data_files={"train": args.train_file})

    tokenizer = AutoTokenizer.from_pretrained(args.model_name)
    model = AutoModelForCausalLM.from_pretrained(args.model_name)

    def tokenize_fn(examples):
        return tokenizer(examples["text"], truncation=True, max_length=args.max_length, padding="max_length")

    tokenized = dataset.map(tokenize_fn, batched=True)
    tokenized.set_format(type="torch", columns=["input_ids", "attention_mask"])

    data_collator = DataCollatorForLanguageModeling(tokenizer=tokenizer, mlm=False)

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        logging_steps=10,
        save_total_limit=2,
        fp16=False,
    )

    trainer = Trainer(model=model, args=training_args, train_dataset=tokenized["train"], data_collator=data_collator)
    trainer.train()
    trainer.save_model(args.output_dir)


if __name__ == "__main__":
    main()
