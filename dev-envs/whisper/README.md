
### 1. Create a `shell.nix` file


### 2. Enter the environment

bash

```bash
cd ~/whisper
nix-shell
```

Activate your existing virtual environment:
```bash
source ~/whisper-env/bin/activate
```

### 3. Test the import

```bash
python -c "from faster_whisper import WhisperModel; print('Whisper OK!')"
```

```bash
python transcribe.py
```

### Optional: Configure a Hugging Face token (recommended)

1. Create a free account at [Hugging Face](<https://huggingface.co/join?utm_source=chatgpt.com>).
2. Generate a read-access token at [Hugging Face tokens](<https://huggingface.co/settings/tokens?utm_source=chatgpt.com>).
3. Export it in your NixOS shell:

```bash
export HF_TOKEN="hf_your_token_here"
```

### Known errors

#### metadata_errors

File "/home/cacu/whisper/transcribe.py", line 10, in <module>
    segments, info = model.transcribe(
                     ^^^^^^^^^^^^^^^^^
  File "/home/cacu/whisper-env/lib/python3.12/site-packages/faster_whisper/transcribe.py", line 876, in transcribe
    audio = decode_audio(audio, sampling_rate=sampling_rate)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/home/cacu/whisper-env/lib/python3.12/site-packages/faster_whisper/audio.py", line 46, in decode_audio
    with av.open(input_file, mode="r", metadata_errors="ignore") as container:
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "av/container/core.py", line 479, in av.container.core.open
TypeError: open() got an unexpected keyword argument 'metadata_errors'

```bash
python -m pip uninstall -y av
python -m pip install --no-cache-dir --force-reinstall "av==14.2.0"

# check
python -c "import av; print(av.__version__); c=av.open('input.webm', metadata_errors='ignore'); print(c.streams.audio); c.close()"
python -c "from faster_whisper import WhisperModel; print('Import successful')"
```