#!/usr/bin/env python
# coding: utf-8

# # Google Gemini SDK Introduction
# 
# This notebook demonstrates how to use the Google Gemini AI SDK to interact with the Gemini model in both text and audio modes.
# 
# ## Setup
# First, we'll install the required package and initialize the client with our API key.

# In[3]:


get_ipython().system('pip install -U -q google-genai')


# ### NB: Output audio transcription for Vertex requires `google-genai=1.11.0` !!
# 
# See also: https://github.com/googleapis/python-genai/releases/tag/v1.11.0

# In[4]:


get_ipython().system('pip show google-genai')


# In[5]:


from google import genai


# ## Text Interaction Example
# 
# Below we'll demonstrate how to have a text conversation with Gemini. The code:
# 1. Sets up a configuration for text responses
# 2. Opens an async connection to the model
# 3. Sends a message and receives the response in chunks
# 4. Prints each chunk of the response as it arrives

# In[10]:


PROJECT_ID = "amitai-454317"
LOCATION = "us-central1"


# In[11]:


model_id = "gemini-2.0-flash-live-preview-04-09"

client = genai.Client(vertexai=True, location=LOCATION, project=PROJECT_ID)
config = {"response_modalities": ["TEXT"]}

async with client.aio.live.connect(model=model_id, config=config) as session:
    message = "Hello? Gemini, are you there?"
    print("> ", message, "\n")
    await session.send_client_content(turns={"role": "user", "parts": [{"text": message}]}, turn_complete=True)

    async for response in session.receive():
        print(response.text)


# ## Audio Generation Example
# 
# Now we'll see how to generate audio responses from Gemini. This section:
# 1. Creates a wave file handler to save the audio
# 2. Configures the model for audio output
# 3. Sends a text prompt and receives audio data
# 4. Saves the audio chunks and plays them in the notebook
# 
# Note: Make sure your browser's audio is enabled to hear the responses.

# In[22]:


import contextlib
import wave


@contextlib.contextmanager
def wave_file(filename, channels=1, rate=24000, sample_width=2):
    with wave.open(filename, "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(sample_width)
        wf.setframerate(rate)
        yield wf


# In[23]:


from IPython.display import display, Audio

config = {"response_modalities": ["AUDIO"]}


async with client.aio.live.connect(model=model_id, config=config) as session:
  file_name = 'audio.wav'
  with wave_file(file_name) as wav:
    message = "Hello? Gemini are you there?"
    print("> ", message, "\n")
    await session.send_client_content(turns={"role": "user", "parts": [{"text": message}]}, turn_complete=True)

    first = True
    async for response in session.receive():
      if response.data is not None:
        model_turn = response.server_content.model_turn
        if first:
          print(model_turn.parts[0].inline_data.mime_type)
          first = False
        print('.', end='.')
        wav.writeframes(response.data)


display(Audio(file_name, autoplay=True))


# # Text and Audio Interaction Example
# 
# This section demonstrates how to receive both text and audio responses from Gemini. The code:
# 1. Sets up a configuration for text and audio responses
# 2. Opens an async connection to the model
# 3. Sends a message and receives the responses in chunks
# 4. Prints each text chunk of the response as it arrives
# 5. Collects the audio chunks and plays them in the notebook
# 
# 
# 

# In[16]:


from IPython.display import display, Audio

config = {
    "response_modalities": ["AUDIO"],
    "output_audio_transcription": {}, # Enable output transcription
}

async with client.aio.live.connect(model=model_id, config=config) as session:
  file_name = 'audio.wav'
  with wave_file(file_name) as wav:
    transcription_chunk_count = 0
    transcription_complete = ""

    message = "Hello? Gemini are you there?"
    print("> ", message, "\n")
    await session.send_client_content(
        turns={"role": "user", "parts": [{"text": message}]}, turn_complete=True
    )
    first = True
    async for response in session.receive():
        if (response.server_content is not None and
            response.server_content.output_transcription is not None and
            response.server_content.output_transcription.text is not None):
            transcription_chunk_count += 1
            # Access the text attribute of the Transcription object
            transcription_text = response.server_content.output_transcription.text
            print(f"Transcription Chunk {transcription_chunk_count}: {transcription_text}")
            transcription_complete += transcription_text
        if response.data is not None:
            model_turn = response.server_content.model_turn
            if first:
                print(model_turn.parts[0].inline_data.mime_type)
                first = False
            print('.', end='.')
            wav.writeframes(response.data)



display(Audio(file_name, autoplay=True))
print(f"Full Transcription:\n{transcription_complete.strip()}")


# In[ ]:





# In[17]:


hi


# In[ ]:





# In[15]:


what is your name ?> 


# In[ ]:





# In[ ]:




