import torch
from transformers import AutoTokenizer, AutoModelForMaskedLM

# Load the pre-trained model and tokenizer
tokenizer = AutoTokenizer.from_pretrained("google-bert/bert-base-uncased")
model = AutoModelForMaskedLM.from_pretrained("google-bert/bert-base-uncased")

# Specify a path for saving the state_dict
PATH = "model_state_dict.pt"

# Save the state_dict
torch.save(model.state_dict(), PATH)
model.save_pretrained("/git")