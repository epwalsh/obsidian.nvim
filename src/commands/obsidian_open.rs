use nvim_oxi as oxi;

use crate::messages;
use crate::util;
use crate::Client;
use crate::{Error, Result};

pub(super) fn obsidian_open(client: &Client, bang: bool, paths: Vec<String>) -> Result<()> {
    let note_ref = if paths.is_empty() {
        util::get_ref_under_cursor()?.ok_or_else(|| Error::NoReference)?
    } else {
        let ref_id = &paths[0];
        util::NoteRef::new(ref_id, None)
    };

    messages::echoinfo!("opening {}", note_ref.id);
    oxi::api::command(&format!("e {}", note_ref.id))?;

    Ok(())
}
