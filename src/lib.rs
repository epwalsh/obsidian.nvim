use nvim_oxi::{self as oxi, Dictionary};

mod client;
mod commands;
mod config;
mod error;
mod hlgroups;
mod messages;
mod note;
mod note_ref;
mod setup;
mod util;

pub use client::Client;
pub use error::{Error, Result};
pub use note::Note;
pub use note_ref::NoteRef;

#[oxi::module]
fn obsidian() -> oxi::Result<Dictionary> {
    let client = Client::new();

    Ok(client.build_api())
}
