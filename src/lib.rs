use nvim_oxi::{self as oxi, Dictionary};

mod client;
mod commands;
mod config;
mod error;
mod hlgroups;
mod messages;
mod setup;
mod util;

pub use client::Client;
pub use error::{Error, Result};

#[oxi::module]
fn obsidian() -> oxi::Result<Dictionary> {
    let client = Client::new();

    Ok(client.build_api())
}
