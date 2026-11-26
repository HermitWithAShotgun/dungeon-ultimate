import { DEFAULT_LOCAL_TEXT_MODEL } from "@/lib/text-models";
import type { Language, StorySettings } from "@/lib/types";

export const DEFAULT_CHAT_TITLE = "Безымянная история";

export const DEFAULT_STORY_SETTINGS: StorySettings = {
  world:
    "Сцена интерактивной прозы с острым диалогом, высокими ставками и пространством для управления сюжетом игроком.",
  style:
    "Классическая текстовая авантюрная нарратология: прямое второе лицо, яркая, но сдержанная проза, естественный диалог и без витиеватого описания.",
  narratorPrompt: "",
  imagePrompt: "",
  imageStylePrefix: "",
  antiRepetition: true,
  causeAwareEnding: true,
  multiVoice: false,
  companion: false,
  // Custom (OpenAI-compatible) is the primary text path; the bundled local
  // OpenAI-compatible Gemma server makes Ollama unnecessary. The env-driven
  // configuredDefaultStorySettings() still overrides these at boot, but this
  // static fallback keeps the app on the custom path even with no .env files.
  textProvider: "custom",
  localTextModel: DEFAULT_LOCAL_TEXT_MODEL,
  customBaseUrl: "http://127.0.0.1:8080/v1",
  customModel: "gemma-4-12b-uncensored",
  customApiKey: "",
  imageMode: "fast",
  imageBackend: "krea2-turbo",
  aspect: "square",
  imageGenerationEnabled: true,
  autoImages: true,
  rpgEnabled: true,
  randomEvents: true,
  diceEnabled: true,
  diceSound: true,
  diceVolume: 75,
  proseSize: "medium",
  responseLength: "medium",
  language: "ru",
  voice: "RU_Male_Gabidullin_ruslan",
  autoplay: false,
  ttsVolume: 1,
  ttsSpeed: 1,
};

/// Заготовки мира и стиля на языке игры. Раньше они были русскими при любом выборе языка —
/// англоязычный игрок видел кириллицу в своих же настройках ещё до первого хода.
const LOCALIZED_SEEDS: Record<Language, { world: string; style: string }> = {
  ru: {
    world: DEFAULT_STORY_SETTINGS.world,
    style: DEFAULT_STORY_SETTINGS.style,
  },
  en: {
    world: "An interactive prose scene with sharp dialogue, high stakes, and room for the player to steer the story.",
    style: "Classic text-adventure narration: direct second person, vivid but restrained prose, natural dialogue, and no ornate description.",
  },
  es: {
    world: "Una escena de prosa interactiva con diálogos incisivos, mucho en juego y espacio para que el jugador dirija la historia.",
    style: "Narración clásica de aventura por texto: segunda persona directa, prosa viva pero contenida, diálogo natural y sin descripciones recargadas.",
  },
  fr: {
    world: "Une scène de prose interactive avec des dialogues vifs, des enjeux forts et une place pour le joueur dans l'intrigue.",
    style: "Narration classique d'aventure textuelle : deuxième personne directe, prose vive mais sobre, dialogue naturel et aucune description amphigourique.",
  },
  de: {
    world: "Eine interaktive Proszene mit scharfen Dialogen, hohen Einsätzen und Spielraum für die Entscheidungen des Spielers.",
    style: "Klassische Text-Adventure-Erzählung: direkte zweite Person, lebendige aber zurückhaltende Prosa, natürliche Dialoge und keine geschraubten Beschreibungen.",
  },
  zh: {
    world: "一段互动小说场景：对话锐利、风险明确，玩家可以主导故事走向。",
    style: "经典文字冒险叙事：直接第二人称，生动但克制的散文，自然对白，不做华丽堆砌。",
  },
  ja: {
    world: "鋭い会話と高い緊張感、そしてプレイヤーが物語を導ける余地のあるインタラクティブな散文の場面。",
    style: "古典的なテキストアドベンチャーの語り：直接的な二人称、生き生きとしつつ抑制の効いた散文、自然な会話、過剰な描写なし。",
  },
};

export function localizedStorySettings(language: Language): StorySettings {
  const seed = LOCALIZED_SEEDS[language] ?? LOCALIZED_SEEDS.ru;
  return { ...DEFAULT_STORY_SETTINGS, language, world: seed.world, style: seed.style };
}

export function titleFromInput(input: string, untitled = DEFAULT_CHAT_TITLE) {
  const compact = input.replace(/\s+/g, " ").trim();
  if (!compact) {
    return untitled;
  }

  return compact.length > 58 ? `${compact.slice(0, 55).trim()}...` : compact;
}
