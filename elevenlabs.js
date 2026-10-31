import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import dotenv from "dotenv";

dotenv.config({ path: ".env.local" });

export const elevenlabs = new ElevenLabsClient();

/**
 * Synthesize speech using ElevenLabs Text-to-Speech.
 *
 * @param {string} text - The text to convert to speech.
 * @param {string} [voiceId="XB0fDUnXU5powFXDhCwa"] - Voice ID (default: Charlotte - sweet, expressive female voice).
 * @param {string} [modelId="eleven_multilingual_v2"] - Model ID (eleven_multilingual_v2 supports Bengali and English fluently).
 * @returns {Promise<any>}
 */
export async function textToSpeech(
  text,
  voiceId = "XB0fDUnXU5powFXDhCwa",
  modelId = "eleven_multilingual_v2"
) {
  return await elevenlabs.textToSpeech.convert(voiceId, {
    text,
    modelId,
  });
}
