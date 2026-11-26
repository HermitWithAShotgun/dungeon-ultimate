//! Наборы промптов на семи языках игры.
//!
//! Тексты выгружены из `src/lib/prompts/*.ts` механически и лежат в `assets/*.json`
//! дословно — их не переписывали руками, поэтому формулировки совпадают с прежней версией
//! до символа. Модели инструкции даются НА языке игры, а не по-русски с припиской «отвечай
//! на другом языке»; только указания по кадру остаются английскими, потому что промпт для
//! движка картинок всегда английский.

use std::collections::HashMap;
use std::sync::OnceLock;

use du_core::{Language, ResponseLength};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ResponseLengthHints {
    pub short: String,
    pub medium: String,
    pub long: String,
    pub epic: String,
}

impl ResponseLengthHints {
    pub fn get(&self, length: ResponseLength) -> &str {
        match length {
            ResponseLength::Short => &self.short,
            ResponseLength::Medium => &self.medium,
            ResponseLength::Long => &self.long,
            ResponseLength::Epic => &self.epic,
        }
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AntiRepetitionText {
    pub header: String,
    pub recent_openings: String,
    /// После него код дописывает список мотивов через запятую.
    pub motifs_prefix: String,
    pub vary_opening: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Labels {
    pub world: String,
    pub world_fallback: String,
    pub style: String,
    pub style_fallback: String,
    pub story_so_far: String,
    pub saved_characters: String,
    pub no_characters: String,
    pub char_id: String,
    pub char_name: String,
    pub char_details: String,
    pub char_inventory: String,
    pub char_skills: String,
    pub char_spells: String,
    pub portrait_available: String,
    pub portrait_unavailable: String,
    pub attachments: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RpgLabels {
    pub rules: String,
    pub inventory: String,
    pub foes: String,
    pub hp: String,
    pub ac: String,
    pub level: String,
    pub dead: String,
    pub equipped: String,
    pub damage: String,
    pub conditions: String,
    pub effects: String,
    /// Заголовок раздела взятых заданий и подпись их условий. С умолчанием: наборы
    /// подсказок обновляются отдельно, и старый набор не должен ронять запуск.
    #[serde(default = "default_quests_label")]
    pub quests: String,
    #[serde(default = "default_quest_conditions_label")]
    pub quest_conditions: String,
    #[serde(default = "default_no_actors")]
    pub no_actors: String,
    #[serde(default = "default_state_header")]
    pub state_header: String,
}

fn default_no_actors() -> String {
    "• (нет игровых персонажей)".to_string()
}

fn default_state_header() -> String {
    "СОСТОЯНИЕ ИГРЫ (authoritative — опирайся на него, НЕ выдумывай числа):".to_string()
}

fn default_quests_label() -> String {
    "ВЗЯТЫЕ ЗАДАНИЯ".to_string()
}

fn default_quest_conditions_label() -> String {
    "условия".to_string()
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SuggestFields {
    pub world: String,
    pub style: String,
    pub character: String,
    pub opening: String,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Suggest {
    pub system: String,
    pub fields: SuggestFields,
}

/// Подсказки для чипсов действий. Описания полей JSON-схемы и напоминание переводятся вместе
/// с системным промптом: раньше они были жёстко русскими, и англоязычный игрок получал
/// кнопки с русскими подписями даже при английском промпте нарратора.
#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Actions {
    pub system: String,
    #[serde(default = "default_emoji_hint")]
    pub emoji_hint: String,
    #[serde(default = "default_label_hint")]
    pub label_hint: String,
    #[serde(default = "default_action_reminder")]
    pub reminder: String,
}

fn default_emoji_hint() -> String {
    "ровно один значок".to_string()
}

fn default_label_hint() -> String {
    "действие СЛОВАМИ, повелительно, 3-6 слов, без значков".to_string()
}

fn default_action_reminder() -> String {
    "{passage}\n\nОтветь только JSON-объектом: emoji — один значок, label — действие словами.".to_string()
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PromptSet {
    /// Подписи журнала приключения на языке игры.
    pub journal: du_rpg::JournalLabels,
    /// Системный промпт нарратора по умолчанию.
    pub narrator: String,
    /// Подмешивается, только когда история должна по-настоящему закончиться.
    pub ending: String,
    /// Ехидный внутриигровой спутник.
    pub companion: String,
    /// Что сказать модели, когда иллюстрации выключены.
    pub image_disabled: String,
    pub response_length: ResponseLengthHints,
    pub anti_repetition: AntiRepetitionText,
    pub labels: Labels,
    pub rpg: RpgLabels,
    pub suggest: Suggest,
    pub actions: Actions,
    /// Директива первого хода.
    pub kickoff: String,
    /// Директива продолжения.
    #[serde(rename = "continue")]
    pub continue_turn: String,
}

macro_rules! embedded {
    ($($code:literal => $lang:expr),* $(,)?) => {
        fn load_all() -> HashMap<Language, PromptSet> {
            let mut all = HashMap::new();
            $(
                let raw = include_str!(concat!("../assets/", $code, ".json"));
                let set: PromptSet = serde_json::from_str(raw)
                    .unwrap_or_else(|e| panic!("набор промптов {} повреждён: {e}", $code));
                all.insert($lang, set);
            )*
            all
        }
    };
}

embedded! {
    "ru" => Language::Ru,
    "en" => Language::En,
    "es" => Language::Es,
    "fr" => Language::Fr,
    "de" => Language::De,
    "zh" => Language::Zh,
    "ja" => Language::Ja,
}

static SETS: OnceLock<HashMap<Language, PromptSet>> = OnceLock::new();

/// Набор промптов для языка игры.
pub fn prompts_for(language: Language) -> &'static PromptSet {
    let all = SETS.get_or_init(load_all);
    all.get(&language).unwrap_or_else(|| &all[&Language::Ru])
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_language_has_a_complete_set() {
        for language in Language::ALL {
            let set = prompts_for(language);
            assert!(!set.narrator.trim().is_empty(), "{language:?}: пустой промпт нарратора");
            assert!(!set.kickoff.trim().is_empty(), "{language:?}: пустая директива первого хода");
            assert!(!set.continue_turn.trim().is_empty(), "{language:?}: пустая директива продолжения");
            assert!(!set.rpg.rules.trim().is_empty(), "{language:?}: пустые правила игры");
            // Журнал приключения тоже на языке игры: раньше он был русским при любом языке.
            assert_eq!(set.journal.random_events.len(), 11, "{language:?}: не все случайные события");
            assert!(!set.journal.verdict.hit.trim().is_empty(), "{language:?}: пустой вердикт");
            if language != Language::Ru {
                assert_ne!(set.journal.verdict.crit_hit, "крит. попадание", "{language:?}: журнал остался русским");
            }
            assert!(!set.suggest.fields.world.trim().is_empty(), "{language:?}: нет подсказки по миру");
            assert!(!set.actions.system.trim().is_empty(), "{language:?}: нет промпта чипсов действий");
            for length in [
                ResponseLength::Short,
                ResponseLength::Medium,
                ResponseLength::Long,
                ResponseLength::Epic,
            ] {
                assert!(
                    !set.response_length.get(length).trim().is_empty(),
                    "{language:?}: нет подсказки длины {length:?}"
                );
            }
        }
    }

    #[test]
    fn the_sets_actually_differ_by_language() {
        // Защита от копипасты: русский и английский нарраторы обязаны различаться.
        assert_ne!(prompts_for(Language::Ru).narrator, prompts_for(Language::En).narrator);
        assert_ne!(prompts_for(Language::Zh).kickoff, prompts_for(Language::Ja).kickoff);
    }

    #[test]
    fn action_chips_and_journal_follow_the_game_language() {
        // Регистр чипсов и подписи журнала — самые заметные «русские artefacts» в
        // англоязычной игре. Проверяем и шаблоны, и то, что русский текст не просочился.
        for language in Language::ALL {
            let set = prompts_for(language);
            assert!(set.actions.reminder.contains("{passage}"), "{language:?}: нет пассажа");
            assert!(!set.actions.label_hint.trim().is_empty(), "{language:?}: пустая подсказка поля");
            assert!(set.journal.quest_offered.contains("{title}"), "{language:?}: нет заголовка");
            assert!(set.journal.xp_gained.contains("{amount}"), "{language:?}: нет опыта");
            assert!(set.journal.roll.contains("{verdict}"), "{language:?}: нет вердикта");
            assert!(set.journal.achievement.contains("{title}"), "{language:?}: нет достижения");
            if language == Language::En {
                assert!(set.rpg.state_header.contains("GAME STATE"));
            }
            if language != Language::Ru {
                assert!(!set.actions.reminder.contains("Ответь"), "{language:?}: русское напоминание");
                assert!(!set.actions.label_hint.contains("значк"), "{language:?}: русская подсказка поля");
                assert!(!set.journal.quest_offered.contains("задан"), "{language:?}: русский журнал");
                assert!(!set.rpg.quests.contains("ЗАДАНИЯ"), "{language:?}: русский заголовок");
            }
        }
    }

    #[test]
    fn the_russian_set_is_written_in_russian() {
        let narrator = &prompts_for(Language::Ru).narrator;
        assert!(narrator.chars().any(|c| ('а'..='я').contains(&c)));
    }
}
