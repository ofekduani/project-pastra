import google.generativeai as genai
import os

# Replace with your actual API key
API_KEY = "AIzaSyCNnMQfWOZLEIXza9ETljT_OApTWwlRQEM"

genai.configure(api_key=API_KEY)

try:
    # Attempt to list models as a simple authentication check
    print("Attempting to list models...")
    models = list(genai.list_models())
    if models:
        print(f"Successfully listed {len(models)} models. API Key appears to be valid.")
        # Optionally print a few model names
        # for i, model in enumerate(models[:5]):
        #     print(f"- {model.name}")
    else:
         print("Listed 0 models. API Key might be valid but has no access to models, or there's another configuration issue.")

except Exception as e:
    print(f"An error occurred: {e}")
    print("\nAPI Key may be invalid or unauthorized.")