#!/usr/bin/env python3
import asyncio
import websockets
import json
import base64
import logging
import asyncio, websockets, json, base64, logging
API_KEY = 'AIzaSyCNnMQfWOZLEIXza9ETljT_OApTWwlRQEM'


ENDPOINT    = (
    "wss://generativelanguage.googleapis.com/ws/"
    "google.ai.generativelanguage.v1beta.GenerativeService."
    f"BidiGenerateContent?key={API_KEY}"
)
# 4 KB of silent 16-bit PCM @ 16 kHz
CHUNK_BYTES = base64.b64encode(b"\x00"*4096).decode()

logging.basicConfig(level=logging.INFO)
async def run():
    logging.info(f"Connecting to {ENDPOINT}")
    async with websockets.connect(ENDPOINT) as ws:
        # 1) Setup
        await ws.send(json.dumps({
          "setup": {
            "model": "models/gemini-2.0-flash",
            "generation_config": {"response_modalities":["AUDIO"]}
          }
        }))
        # 2) Handshake
        while True:
            msg = json.loads(await ws.recv())
            if msg.get("setupComplete"):
                logging.info("← setupComplete")
                break

        # 3) Stream 3 audio chunks
        for i in range(3):
            await ws.send(json.dumps({
              "realtime_input": {
                "media_chunks":[{"audio":{"data":CHUNK_BYTES,
                  "audio_spec":{
                    "encoding":"AUDIO_ENCODING_LINEAR_PCM",
                    "sample_rate_hertz":16000,"audio_channel_count":1}}}]
              }
            }))
            logging.info(f"→ chunk {i+1}")
            await asyncio.sleep(0.128)

        # 4) End turn
        await ws.send(json.dumps({
          "client_content":{"turns":[{"role":"user","parts":[]}],"turn_complete":True}
        }))
        # 5) Read until turnComplete
        async for raw in ws:
            server = json.loads(raw).get("serverContent",{})
            done   = server.get("turnComplete",False)
            logging.info(f"← serverContent.turnComplete={done}")
            if done:
                break

asyncio.run(run())