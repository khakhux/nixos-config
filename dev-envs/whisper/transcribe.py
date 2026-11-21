from faster_whisper import WhisperModel

model = WhisperModel(
    "medium",
    device="cpu",
    compute_type="int8",
    cpu_threads=8,
)

segments, info = model.transcribe(
    "input.webm",
    language="es",
    beam_size=5,
    vad_filter=True,
)

with open("transcript.txt", "w", encoding="utf-8") as f:
    for segment in segments:
        print(segment.text)
        f.write(segment.text + "\n")

print("Transcription complete!")