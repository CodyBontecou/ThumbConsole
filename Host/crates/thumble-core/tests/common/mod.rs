#![allow(dead_code)]

use std::collections::VecDeque;
use thumble_core::{Effect, HostCore, PersistentState, TokenSource};
use thumble_protocol::{ControllerMessage, ControllerMessageType};

pub struct ScriptedTokens {
    codes: VecDeque<String>,
    tokens: VecDeque<String>,
}

impl ScriptedTokens {
    pub fn new(codes: &[&str], tokens: &[&str]) -> Self {
        Self {
            codes: codes.iter().map(|value| (*value).to_owned()).collect(),
            tokens: tokens.iter().map(|value| (*value).to_owned()).collect(),
        }
    }
}

impl TokenSource for ScriptedTokens {
    fn next_pairing_code(&mut self) -> String {
        self.codes.pop_front().expect("scripted pairing code")
    }

    fn next_auth_token(&mut self) -> String {
        self.tokens.pop_front().expect("scripted auth token")
    }
}

pub fn core() -> HostCore {
    HostCore::new(PersistentState::minimal("server-1").unwrap(), "111111").unwrap()
}

pub fn pair(core: &mut HostCore, connection_id: u64, token: &str) -> Vec<Effect> {
    let mut hello = ControllerMessage::new(ControllerMessageType::Hello, 0);
    hello.pairing_code = Some(core.pairing_code().to_owned());
    hello.client_name = Some("Test iPhone".to_owned());
    let mut tokens = ScriptedTokens::new(&[], &[token]);
    core.handle_message(connection_id, hello, 1_000, &mut tokens)
        .unwrap()
}

pub fn sent_message(effects: &[Effect], kind: ControllerMessageType) -> &ControllerMessage {
    effects
        .iter()
        .find_map(|effect| match effect {
            Effect::SendMessage { message, .. } if message.message_type == kind => Some(message),
            _ => None,
        })
        .expect("expected outbound message")
}

pub fn diagnostic_text(effects: &[Effect]) -> &str {
    effects
        .iter()
        .find_map(|effect| match effect {
            Effect::Diagnostic { message, .. } => Some(message.as_str()),
            _ => None,
        })
        .expect("expected diagnostic effect")
}

pub fn error_text(effects: &[Effect]) -> &str {
    sent_message(effects, ControllerMessageType::Error)
        .message
        .as_deref()
        .expect("error text")
}

pub fn no_tokens() -> ScriptedTokens {
    ScriptedTokens::new(&[], &[])
}
