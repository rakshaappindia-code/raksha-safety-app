# RAKSHA Audio Assets — Fake Call Feature

Place the following audio files in this directory (`assets/audios/`):

## Required Files

### 1. `fake_call_ringtone.mp3`
- A realistic Indian phone ringtone (default caller tune)
- Duration: 30 seconds (looped automatically)
- Should sound like a real incoming call
- **Free source suggestion**: https://zedge.net or record a real ringtone
- Will play via Android STREAM_ALARM (bypasses silent mode ✅)

### 2. `fake_call_voice.mp3`
- A pre-recorded conversation — one side of a call
- Suggested script (Police caller):
  > "Hello? Haan beta, main police station se bol raha hoon. Aap safe hain? 
  >  Koi dikkat ho toh bataiye, hum 2 minute mein pahunch jaate hain.
  >  Aap kahan hain abhi? Theek hai, main aata hoon. Aap wahan rukiye."
- Duration: 20-30 seconds
- Record in a calm, authoritative voice
- **Tools**: Use Audacity, GarageBand, or https://ttsmp3.com (text-to-speech)

## Quick Placeholder (for testing)
Until real audio is added, you can use any MP3 file renamed to these names.
A 5-second silence MP3 can be used for voice if you just want the UI to work.

## Notes
- Both files MUST be `.mp3` format
- Keep file sizes small (< 500KB each) for fast loading
- The ringtone loops automatically — it doesn't need to be long
